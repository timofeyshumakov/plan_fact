WITH user_plans AS (
    -- Получаем все планы пользователей
    SELECT DISTINCT
        sp.assigned_by_id as user_id,
        CAST(sp.uf_crm_5_year as INTEGER) as plan_year,
        sp.uf_crm_5_quarter as plan_quarter
    FROM crm_dynamic_items_1040 sp
    WHERE sp.uf_crm_5_year IS NOT NULL 
        AND sp.uf_crm_5_quarter IS NOT NULL
        AND CAST(sp.uf_crm_5_year as INTEGER) >= 2025
),
existing_deals AS (
    -- Собираем существующие сделки
    SELECT 
        d.assigned_by_id,
        YEAR(d.date_create) as deal_year,
        CASE 
            WHEN MONTH(d.closedate) BETWEEN 1 AND 3 THEN '1'
            WHEN MONTH(d.closedate) BETWEEN 4 AND 6 THEN '2'
            WHEN MONTH(d.closedate) BETWEEN 7 AND 9 THEN '3'
            WHEN MONTH(d.closedate) BETWEEN 10 AND 12 THEN '4'
        END as deal_quarter
    FROM crm_deal d
    WHERE d.category_id IN ('5', '3')
        AND YEAR(d.date_create) >= 2025
    GROUP BY d.assigned_by_id, YEAR(d.date_create),
        CASE 
            WHEN MONTH(d.closedate) BETWEEN 1 AND 3 THEN '1'
            WHEN MONTH(d.closedate) BETWEEN 4 AND 6 THEN '2'
            WHEN MONTH(d.closedate) BETWEEN 7 AND 9 THEN '3'
            WHEN MONTH(d.closedate) BETWEEN 10 AND 12 THEN '4'
        END
),
missing_combinations AS (
    -- Находим комбинации пользователь-квартал-год, для которых есть план, но нет сделок
    SELECT 
        up.user_id,
        up.plan_year,
        up.plan_quarter
    FROM user_plans up
    LEFT JOIN existing_deals ed ON 
        ed.assigned_by_id = up.user_id
        AND ed.deal_year = up.plan_year
        AND ed.deal_quarter = up.plan_quarter
    WHERE ed.assigned_by_id IS NULL
)
SELECT 
    u.id as id,
    u.name as user_name,
    u.department_name as department_name,
    NULL as deal_id,  -- Сделки нет, поэтому NULL
    NULL as category,
    NULL as opportunity,
    NULL as company,
    NULL as stage_semantic_id,
    NULL as closedate,
    NULL as pdzs,
    NULL as contract_date,
    NULL as client_type,
    
    -- Используем квартал из плана
    mc.plan_quarter as deal_quarter,
    mc.plan_year as deal_year,
    
    -- Получаем план продаж на квартал
    COALESCE(
        CAST(NULLIF(TRIM(sp.uf_crm_5_sales), '') AS INTEGER),
        0
    ) as user_sales_plan_quarter,
    
    -- Получаем план по количеству договоров на квартал
    COALESCE(
        CAST(NULLIF(TRIM(sp.uf_crm_5_contracts), '') AS INTEGER),
        0
    ) as user_contracts_plan_quarter,
    
    COALESCE(
        CAST(NULLIF(TRIM(sp.uf_crm_5_bid), '') AS INTEGER),
        0
    ) as user_bids_plan_quarter
    
FROM missing_combinations mc
INNER JOIN user u ON u.id = mc.user_id
LEFT JOIN crm_dynamic_items_1040 sp ON 
    sp.assigned_by_id = mc.user_id
    AND sp.uf_crm_5_year = CAST(mc.plan_year AS VARCHAR)
    AND sp.uf_crm_5_quarter = mc.plan_quarter

UNION ALL

SELECT 
    u.id as id,
    u.name as user_name,
    u.department_name as department_name,
    d.id as deal_id,
    d.category_id as category,
    d.opportunity as opportunity,
    d.company_id as company,
    d.stage_semantic_id,
    d.closedate,
    du.UF_CRM_1758098403 as pdzs,
    du.UF_CRM_1764838007 as contract_date,
    du.UF_CRM_1765285428 as client_type,
    
    -- Определяем квартал для сделки
    CASE 
        WHEN MONTH(d.closedate) BETWEEN 1 AND 3 THEN '1'
        WHEN MONTH(d.closedate) BETWEEN 4 AND 6 THEN '2'
        WHEN MONTH(d.closedate) BETWEEN 7 AND 9 THEN '3'
        WHEN MONTH(d.closedate) BETWEEN 10 AND 12 THEN '4'
    END as deal_quarter,
    YEAR(d.date_create) as deal_year,
    
    -- Получаем план продаж на квартал из смарт-процесса, соответствующий кварталу сделки
    COALESCE(
        CAST(NULLIF(TRIM(sp.uf_crm_5_sales), '') AS INTEGER),
        0
    ) as user_sales_plan_quarter,
    
    -- Получаем план по количеству договоров на квартал, соответствующий кварталу сделки
    COALESCE(
        CAST(NULLIF(TRIM(sp.uf_crm_5_contracts), '') AS INTEGER),
        0
    ) as user_contracts_plan_quarter,
    
    COALESCE(
        CAST(NULLIF(TRIM(sp.uf_crm_5_bid), '') AS INTEGER),
        0
    ) as user_bids_plan_quarter
    
FROM user u
INNER JOIN crm_deal d ON 
    d.assigned_by_id = u.id
    AND d.category_id IN ('5', '3')
    AND YEAR(d.date_create) >= 2025

-- Присоединяем план продаж на КВАРТАЛ СДЕЛКИ
LEFT JOIN crm_dynamic_items_1040 sp ON 
    sp.assigned_by_id = u.id
    AND sp.uf_crm_5_year = CAST(YEAR(d.date_create) AS VARCHAR)
    AND sp.uf_crm_5_quarter = CASE 
        WHEN MONTH(d.closedate) BETWEEN 1 AND 3 THEN '1'
        WHEN MONTH(d.closedate) BETWEEN 4 AND 6 THEN '2'
        WHEN MONTH(d.closedate) BETWEEN 7 AND 9 THEN '3'
        WHEN MONTH(d.closedate) BETWEEN 10 AND 12 THEN '4'
    END

LEFT JOIN crm_deal_uf du ON du.deal_id = d.id

ORDER BY id, 
    deal_year DESC, 
    deal_id DESC;
