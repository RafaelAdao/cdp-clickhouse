-- Inserting two criteria for tenant 1
INSERT INTO criteria (tenant_id, segment_id, filters) VALUES 
(1, 'high_fit', 
    [
        ('industry', 'eq', 'Marketing', 'string'),
        ('company_size', 'gte', '50', 'number'),
        ('job_title', 'contains', 'CEO', 'string'),
        ('budget', 'gte', '10000', 'number')
    ]
),
(1, 'high_interest', 
    [
        ('website_activity', 'gte', '70', 'number'),
        ('email_engagement', 'gte', '50', 'number'),
        ('trial_used', 'eq', 'true', 'boolean'),
        ('last_activity', 'gte', '2025-02-01', 'datetime')
    ]
);

-- Inserting three entities for tenant 1
INSERT INTO entities (tenant_id, entity_id, properties, event_time) VALUES 
(1, 'lead_001', '{"industry": "Marketing", "company_size": 100, "job_title": "CEO", "website_activity": 80, "email_engagement": 60, "trial_used": true, "budget": 15000, "last_activity": "2025-02-15"}', now()),
(1, 'lead_002', '{"industry": "Retail", "company_size": 30, "job_title": "Marketing Manager", "website_activity": 50, "email_engagement": 30, "trial_used": false, "budget": 5000, "last_activity": "2025-01-20"}', now()),
(1, 'lead_003', '{"industry": "Marketing", "company_size": 80, "job_title": "CTO", "website_activity": 90, "email_engagement": 80, "trial_used": true, "budget": 20000, "last_activity": "2025-02-10"}', now());

-- Querying the segment_membership table
SELECT * from segment_membership format vertical;
-- Row 1:
-- ──────
-- tenant_id:    1
-- segment_id:   high_fit
-- filters:      [('industry','eq','Marketing','string'),('company_size','gte','50','number'),('job_title','contains','CEO','string'),('budget','gte','10000','number')]
-- entity_id:    lead_001
-- properties:   {"budget":"15000","company_size":"100","email_engagement":"60","industry":"Marketing","job_title":"CEO","last_activity":"2025-02-15","location":"USA","purchased_before":false,"trial_used":true,"website_activity":"80"}
-- last_updated: 2025-02-20 20:16:37

-- Row 2:
-- ──────
-- tenant_id:    1
-- segment_id:   high_interest
-- filters:      [('website_activity','gte','70','number'),('email_engagement','gte','50','number'),('trial_used','eq','true','boolean'),('last_activity','gte','2025-02-01','datetime')]
-- entity_id:    lead_001
-- properties:   {"budget":"15000","company_size":"100","email_engagement":"60","industry":"Marketing","job_title":"CEO","last_activity":"2025-02-15","location":"USA","purchased_before":false,"trial_used":true,"website_activity":"80"}
-- last_updated: 2025-02-20 20:16:37

-- Row 3:
-- ──────
-- tenant_id:    1
-- segment_id:   high_interest
-- filters:      [('website_activity','gte','70','number'),('email_engagement','gte','50','number'),('trial_used','eq','true','boolean'),('last_activity','gte','2025-02-01','datetime')]
-- entity_id:    lead_003
-- properties:   {"budget":"20000","company_size":"80","email_engagement":"80","industry":"Marketing","job_title":"CTO","last_activity":"2025-02-10","location":"UK","purchased_before":true,"trial_used":true,"website_activity":"90"}
-- last_updated: 2025-02-20 20:16:37
