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


CREATE MATERIALIZED VIEW segment_membership
ENGINE = MergeTree
ORDER BY (tenant_id, segment_id, entity_id)
POPULATE
AS SELECT
    e.tenant_id,
    c.segment_id,
    c.filters,
    e.entity_id,
    e.properties,
    now() AS last_updated
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
