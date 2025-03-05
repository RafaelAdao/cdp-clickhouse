CREATE FUNCTION compareStrings AS (op, value, target) -> 
    multiIf(
        op = 'eq', value == target,
        op = 'neq', value != target,
        op = 'contains', position(value, target) > 0,
        op = 'starts_with', startsWith(value, target),
        false
    );

CREATE FUNCTION compareNumbers AS (op, value, target) -> 
    multiIf(
        op = 'eq', value == target,
        op = 'neq', value != target,
        op = 'gt', value > target,
        op = 'gte', value >= target,
        op = 'lt', value < target,
        op = 'lte', value <= target,
        false
    );

CREATE FUNCTION compareBooleans AS (op, value, target) -> 
    multiIf(
        op = 'eq', value == target,
        op = 'neq', value != target,
        false
    );

CREATE FUNCTION filterMatches as (type, value, op, target) -> multiIf(
  type == 'string',
    compareStrings(op, value, target),
  type == 'number',
    compareNumbers(op, accurateCastOrNull(value, 'Float64'), accurateCastOrNull(target, 'Float64')),
  type == 'boolean',
    compareBooleans(op, accurateCastOrNull(value, 'Bool'), accurateCastOrNull(target, 'Bool')),
  type == 'datetime',
    compareNumbers(op, toUnixTimestamp64Nano(accurateCastOrNull(value, 'DateTime64')), toUnixTimestamp64Nano(accurateCastOrNull(target, 'DateTime64'))),
  NULL
);

CREATE TABLE entities
(
    tenant_id UInt32,
    entity_id String,
    properties JSON,
    event_time DateTime64(6),
    version UInt64 MATERIALIZED toUnixTimestamp64Nano(event_time)
)
ENGINE = ReplacingMergeTree(version)
ORDER BY (tenant_id, entity_id);

CREATE TABLE criteria
(
    tenant_id UInt32,
    segment_id String,
    filters Array(
        Tuple(
            property_path String,
            operator String,
            value String,
            data_type String
        )
    ),
    version UInt32 DEFAULT 1
)
ENGINE = ReplacingMergeTree(version)
ORDER BY (tenant_id, segment_id);

--- version 1 ---

CREATE TABLE segment_membership
(
    tenant_id UInt32,
    segment_id String,
    filters Array(
        Tuple(
            property_path String,
            operator String,
            value String,
            data_type String
        )
    ),
    entity_id String,
    properties JSON,
)
ENGINE = MergeTree
ORDER BY (tenant_id, segment_id, entity_id);

CREATE MATERIALIZED VIEW segment_membership_mv
TO segment_membership
AS SELECT
    e.tenant_id,
    c.segment_id,
    c.filters,
    e.entity_id,
    e.properties
FROM entities AS e
INNER JOIN criteria AS c ON e.tenant_id = c.tenant_id
WHERE arrayAll(
    filter -> filterMatches(
      filter.data_type,
      JSONExtractString(e.properties::String, filter.property_path),
      filter.operator,
      filter.value) = 1,
    c.filters
);

--- version 2 ---

CREATE TABLE entity_segment_membership_log
(
    tenant_id UInt32,
    segment_id String,
    entity_id String,
    event_time DateTime64(6),
    is_member UInt8,       -- 1 if the entity qualifies, 0 otherwise
    sign Int8,             -- +1 if is_member is true, -1 otherwise
    version UInt64         -- derived from event_time
)
ENGINE = CollapsingMergeTree(sign)
ORDER BY (tenant_id, segment_id, entity_id, version);

CREATE MATERIALIZED VIEW entity_membership_changes_mv
TO entity_segment_membership_log
AS
SELECT
    tenant_id,
    segment_id,
    entity_id,
    version AS event_time,
    arrayAll(
        x -> filterMatches(
                x.4,                                -- data_type
                JSONExtractString(properties::String, x.1), -- extract property value
                x.2,                                -- operator
                x.3                                 -- target value
            ),
        filters
    ) AS is_member,
    if(
        arrayAll(
            x -> filterMatches(
                    x.4,
                    JSONExtractString(properties::String, x.1),
                    x.2,
                    x.3
                ),
            filters
        ),
        1, -1
    ) AS sign,
    version
FROM entities
JOIN criteria USING (tenant_id);

CREATE TABLE notifications
(
    tenant_id UInt32,
    segment_id String,
    entity_id String,
    event_time DateTime64(6),
    change_type String    -- 'entered' or 'exited'
)
ENGINE = Kafka('kafka:9092', 'notifications_topic', 'default', 'JSONEachRow');

CREATE TABLE membership_snapshot
(
    tenant_id UInt32,
    segment_id String,
    entity_id String,
    is_member UInt8
)
ENGINE = ReplacingMergeTree()
ORDER BY (tenant_id, segment_id, entity_id);

--docker exec kafka ./bin/kafka-topics.sh --bootstrap-server kafka:9092 --list
--docker exec kafka ./bin/kafka-console-consumer.sh --bootstrap-server kafka:9092 --topic notifications_topic --from-beginning

INSERT INTO notifications (tenant_id, segment_id, entity_id, event_time, change_type)
SELECT
    tenant_id,
    segment_id,
    entity_id,
    now64() AS event_time,
    if(current_membership = 1, 'entered', 'exited') AS change_type
FROM
(
    WITH current_state AS (
        SELECT
            tenant_id,
            segment_id,
            entity_id,
            max(version) AS last_version,
            argMax(is_member, version) AS current_membership
        FROM entity_segment_membership_log FINAL
        GROUP BY tenant_id, segment_id, entity_id
    ),
    changes_new AS (
        SELECT
            c.tenant_id,
            c.segment_id,
            c.entity_id,
            c.current_membership,
            s.is_member AS previous_membership
        FROM current_state c
        LEFT JOIN membership_snapshot s
          ON c.tenant_id = s.tenant_id
         AND c.segment_id = s.segment_id
         AND c.entity_id = s.entity_id
        WHERE s.is_member IS NULL OR s.is_member != c.current_membership
    ),
    changes_missing AS (
        SELECT
            s.tenant_id,
            s.segment_id,
            s.entity_id,
            0 AS current_membership,
            s.is_member AS previous_membership
        FROM membership_snapshot s
        LEFT JOIN current_state c
          ON s.tenant_id = c.tenant_id
         AND s.segment_id = c.segment_id
         AND s.entity_id = c.entity_id
        WHERE c.entity_id IS NULL AND s.is_member = 1
    )
    SELECT * FROM changes_new
    UNION ALL
    SELECT * FROM changes_missing
);


INSERT INTO membership_snapshot
SELECT
    tenant_id,
    segment_id,
    entity_id,
    current_membership AS is_member
FROM
(
    SELECT
        tenant_id,
        segment_id,
        entity_id,
        max(version) AS last_version,
        argMax(is_member, version) AS current_membership
    FROM entity_segment_membership_log FINAL
    GROUP BY tenant_id, segment_id, entity_id
);
