WITH months AS (
    SELECT 1 as month_num UNION ALL
    SELECT 2 UNION ALL
    SELECT 3 UNION ALL
    SELECT 4 UNION ALL
    SELECT 5 UNION ALL
    SELECT 6 UNION ALL
    SELECT 7 UNION ALL
    SELECT 8 UNION ALL
    SELECT 9 UNION ALL
    SELECT 10 UNION ALL
    SELECT 11 UNION ALL
    SELECT 12
),
sales_plan_data AS (
    SELECT 
        assigned_by_id as user_id,
        CAST(NULLIF(TRIM(uf_crm_5_calls), '') AS INTEGER) as calls_plan_per_month,
        CAST(NULLIF(TRIM(uf_crm_5_month), '') AS INTEGER) as plan_month
    FROM bitrix24.crm_dynamic_items_1040 
    WHERE uf_crm_5_year = '2026'
        AND CAST(NULLIF(TRIM(uf_crm_5_calls), '') AS INTEGER) > 0
),
users_with_plans AS (
    SELECT DISTINCT user_id
    FROM sales_plan_data
),
all_user_months AS (
    SELECT 
        u.user_id,
        m.month_num,
        sp.calls_plan_per_month
    FROM users_with_plans u
    CROSS JOIN months m
    LEFT JOIN sales_plan_data sp 
        ON u.user_id = sp.user_id 
        AND m.month_num = sp.plan_month
),
all_calls_2026 AS (
    SELECT 
        tc.portal_user_id,
        tc.call_id,
        tc.call_start_time,
        tc.call_type,
        tc.call_duration,
        EXTRACT(MONTH FROM tc.call_start_time) as call_month
    FROM bitrix24.telephony_call tc
    WHERE EXTRACT(YEAR FROM tc.call_start_time) = 2026
),
combined_data AS (
    -- Все звонки с их месяцами
    SELECT 
        ac.portal_user_id as user_id,
        ac.call_id,
        ac.call_start_time,
        ac.call_type,
        ac.call_duration,
        ac.call_month,
        sp.calls_plan_per_month
    FROM all_calls_2026 ac
    LEFT JOIN sales_plan_data sp 
        ON ac.portal_user_id = sp.user_id 
        AND ac.call_month = sp.plan_month
    
    UNION ALL
    
    -- Добавляем записи для месяцев без звонков
    SELECT 
        aum.user_id,
        '0' as call_id,
        CAST(CONCAT('2026-', LPAD(CAST(aum.month_num AS VARCHAR), 2, '0'), '-01') AS TIMESTAMP) as call_start_time,
        '1' as call_type,
        NULL as call_duration,
        aum.month_num as call_month,
        COALESCE(aum.calls_plan_per_month, 0) as calls_plan_per_month
    FROM all_user_months aum
    WHERE NOT EXISTS (
        SELECT 1 
        FROM all_calls_2026 ac 
        WHERE ac.portal_user_id = aum.user_id 
            AND ac.call_month = aum.month_num
    )
)
SELECT 
    cd.user_id as portal_user_id,
    CONCAT('[', CAST(u.id AS VARCHAR), '] ', u.name) as portal_user,
    cd.call_id,
    cd.calls_plan_per_month,
    cd.call_start_time,
    cd.call_type,
    cd.call_duration,
    cd.call_month,
    CASE 
        WHEN cd.call_id = '0' THEN 'Нет звонков'
        ELSE 'Есть звонки'
    END as calls_status
    --CASE 
        --WHEN cd.call_month IS NOT NULL THEN 'Месяц ' || CAST(cd.call_month AS VARCHAR)
        --ELSE NULL
    --END as month_name
FROM combined_data cd
LEFT JOIN bitrix24.user u
    ON cd.user_id = u.id
ORDER BY cd.user_id, cd.call_month NULLS LAST, cd.call_start_time NULLS LAST;
