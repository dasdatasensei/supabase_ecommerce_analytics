-- ====================================================
-- CUSTOMER ANALYTICS DASHBOARD QUERIES
-- ====================================================
-- These queries are designed to be used with Metabase for creating a
-- comprehensive Customer Analytics Dashboard.
-- ====================================================

-- 1. CUSTOMER ACQUISITION & GROWTH
-- ------------------------------------

-- 1.1 New customers acquired by month
SELECT
    date_trunc('month', first_order_date) as month,
    count(*) as new_customers
FROM olist_marts.mart_customer_analytics
GROUP BY 1
ORDER BY 1;

-- 1.2 Geographic distribution of customers
SELECT
    CASE co.state_normalized
        WHEN 'AC' THEN 'Acre'
        WHEN 'AL' THEN 'Alagoas'
        WHEN 'AP' THEN 'Amapá'
        WHEN 'AM' THEN 'Amazonas'
        WHEN 'BA' THEN 'Bahia'
        WHEN 'CE' THEN 'Ceará'
        WHEN 'DF' THEN 'Distrito Federal'
        WHEN 'ES' THEN 'Espírito Santo'
        WHEN 'GO' THEN 'Goiás'
        WHEN 'MA' THEN 'Maranhão'
        WHEN 'MT' THEN 'Mato Grosso'
        WHEN 'MS' THEN 'Mato Grosso do Sul'
        WHEN 'MG' THEN 'Minas Gerais'
        WHEN 'PA' THEN 'Pará'
        WHEN 'PB' THEN 'Paraíba'
        WHEN 'PR' THEN 'Paraná'
        WHEN 'PE' THEN 'Pernambuco'
        WHEN 'PI' THEN 'Piauí'
        WHEN 'RJ' THEN 'Rio de Janeiro'
        WHEN 'RN' THEN 'Rio Grande do Norte'
        WHEN 'RS' THEN 'Rio Grande do Sul'
        WHEN 'RO' THEN 'Rondônia'
        WHEN 'RR' THEN 'Roraima'
        WHEN 'SC' THEN 'Santa Catarina'
        WHEN 'SP' THEN 'São Paulo'
        WHEN 'SE' THEN 'Sergipe'
        WHEN 'TO' THEN 'Tocantins'
        ELSE co.state_normalized
    END as customer_state,
    count(*) as customer_count,
    round((count(*)::decimal / (SELECT count(*) FROM olist_marts.mart_customer_analytics)) * 100, 2) as percentage
FROM olist_marts.mart_customer_analytics ca
JOIN olist_intermediate.int_customer_orders co ON ca.customer_id = co.customer_id
GROUP BY 1
ORDER BY 2 DESC;

-- 1.3 Monthly active customers trend
SELECT
    date_trunc('month', last_order_date) as month,
    count(*) as customer_count
FROM olist_marts.mart_customer_analytics
GROUP BY 1
ORDER BY 1 desc;

-- 2. PURCHASE BEHAVIOR
-- ------------------------------------

-- 2.1 Average order value by customer segment
SELECT
    frequency_segment,
    value_segment,
    customer_tier,
    round(avg(avg_order_value), 2) as avg_order_value,
    count(*) as customer_count,
    sum(total_orders) as total_orders
FROM olist_marts.mart_customer_analytics
GROUP BY 1, 2, 3
ORDER BY 4 DESC;

-- 2.2 Customer lifetime value distribution
WITH customer_quintiles AS (
    SELECT
        customer_id,
        total_spent,
        ntile(5) OVER (ORDER BY total_spent) as ltv_quintile
    FROM olist_marts.mart_customer_analytics
)
SELECT
    ltv_quintile,
    min(total_spent) as min_ltv,
    round(avg(total_spent), 2) as avg_ltv,
    max(total_spent) as max_ltv,
    count(*) as customer_count,
    sum(total_spent) as total_revenue,
    round((sum(total_spent)::decimal / (SELECT sum(total_spent) FROM olist_marts.mart_customer_analytics)) * 100, 2) as revenue_percentage
FROM customer_quintiles
GROUP BY 1
ORDER BY 1;

-- 2.3 Order value distribution
SELECT
    CASE
        WHEN avg_order_value < 50 THEN 'Under $50'
        WHEN avg_order_value BETWEEN 50 AND 99.99 THEN '$50-$99'
        WHEN avg_order_value BETWEEN 100 AND 249.99 THEN '$100-$249'
        WHEN avg_order_value BETWEEN 250 AND 499.99 THEN '$250-$499'
        WHEN avg_order_value BETWEEN 500 AND 999.99 THEN '$500-$999'
        ELSE '$1000+'
    END as average_order_value_range,
    count(*) as customer_count,
    round((count(*)::decimal / (SELECT count(*) FROM olist_marts.mart_customer_analytics)) * 100, 2) as proportion_of_customers,
    sum(total_spent) as total_revenue,
    round((sum(total_spent)::decimal / (SELECT sum(total_spent) FROM olist_marts.mart_customer_analytics)) * 100, 2) as proportion_of_revenue
FROM olist_marts.mart_customer_analytics
GROUP BY 1
ORDER BY proportion_of_revenue DESC;

-- 3. CUSTOMER SEGMENTATION
-- ------------------------------------

-- 3.1 RFM segment performance comparison
SELECT
    customer_tier,
    count(*) as customer_count,
    round(avg(total_spent), 2) as avg_customer_ltv,
    round(avg(total_orders), 2) as avg_orders_per_customer,
    round(avg(avg_order_value), 2) as avg_order_value,
    sum(total_orders) as total_orders,
    sum(total_spent) as total_revenue,
    round((sum(total_spent)::decimal / sum(sum(total_spent)) OVER ()) * 100, 2) as revenue_percentage
FROM olist_marts.mart_customer_analytics
GROUP BY 1
ORDER BY 7 DESC;

-- 3.2 One-time vs repeat purchasers breakdown
SELECT
    CASE
        WHEN total_orders = 1 THEN 'One-time customer'
        WHEN total_orders BETWEEN 2 AND 3 THEN 'Occasional customer (2-3 orders)'
        WHEN total_orders BETWEEN 4 AND 6 THEN 'Regular customer (4-6 orders)'
        ELSE 'Loyal customer (7+ orders)'
    END as customer_type,
    count(*) as customer_count,
    round((count(*)::decimal / (SELECT count(*) FROM olist_marts.mart_customer_analytics)) * 100, 2) as percentage,
    round(avg(total_spent), 2) as avg_ltv,
    sum(total_spent) as total_revenue,
    round((sum(total_spent)::decimal / sum(sum(total_spent)) OVER ()) * 100, 2) as revenue_percentage
FROM olist_marts.mart_customer_analytics
GROUP BY 1
ORDER BY 4 DESC;

-- 3.3 Recency segment analysis
SELECT
    CASE
        WHEN is_active = 1 THEN 'Active (past 3 months)'
        WHEN date_part('day', current_date - last_order_date) <= 180 THEN 'Recent (3-6 months)'
        WHEN date_part('day', current_date - last_order_date) <= 365 THEN 'Lapsed (6-12 months)'
        ELSE 'Inactive (12+ months)'
    END as recency_segment,
    count(*) as customer_count,
    round((count(*)::decimal / (SELECT count(*) FROM olist_marts.mart_customer_analytics)) * 100, 2) as percentage,
    round(avg(total_spent), 2) as avg_ltv,
    round(avg(total_orders), 2) as avg_orders,
    sum(total_spent) as total_revenue
FROM olist_marts.mart_customer_analytics
GROUP BY 1
ORDER BY 6 DESC;

-- 4. CUSTOMER JOURNEY
-- ------------------------------------

-- 4.1 Customer satisfaction metrics
SELECT
    customer_tier,
    count(*) as customer_count,
    round(avg(avg_review_score), 2) as avg_review_score,
    round(avg(positive_review_rate), 2) as avg_positive_review_rate,
    count(CASE WHEN is_promoter = 1 THEN 1 END) as promoters,
    round((count(CASE WHEN is_promoter = 1 THEN 1 END)::decimal / count(*)) * 100, 2) as promoter_percentage
FROM olist_marts.mart_customer_analytics
GROUP BY 1
ORDER BY 3 DESC;

-- 5. MONETARY IMPACT
-- ------------------------------------

-- 5.1 Revenue by customer segment
SELECT
    customer_tier,
    sum(total_spent) as total_revenue,
    round((sum(total_spent)::decimal / sum(sum(total_spent)) OVER ()) * 100, 2) as revenue_percentage,
    count(*) as customer_count,
    round((count(*)::decimal / count(*) OVER ()) * 100, 2) as customer_percentage
FROM olist_marts.mart_customer_analytics
GROUP BY 1
ORDER BY 2 DESC;

-- 5.2 Revenue by customer state/region
SELECT
    CASE co.state_normalized
        WHEN 'AC' THEN 'Acre'
        WHEN 'AL' THEN 'Alagoas'
        WHEN 'AP' THEN 'Amapá'
        WHEN 'AM' THEN 'Amazonas'
        WHEN 'BA' THEN 'Bahia'
        WHEN 'CE' THEN 'Ceará'
        WHEN 'DF' THEN 'Distrito Federal'
        WHEN 'ES' THEN 'Espírito Santo'
        WHEN 'GO' THEN 'Goiás'
        WHEN 'MA' THEN 'Maranhão'
        WHEN 'MT' THEN 'Mato Grosso'
        WHEN 'MS' THEN 'Mato Grosso do Sul'
        WHEN 'MG' THEN 'Minas Gerais'
        WHEN 'PA' THEN 'Pará'
        WHEN 'PB' THEN 'Paraíba'
        WHEN 'PR' THEN 'Paraná'
        WHEN 'PE' THEN 'Pernambuco'
        WHEN 'PI' THEN 'Piauí'
        WHEN 'RJ' THEN 'Rio de Janeiro'
        WHEN 'RN' THEN 'Rio Grande do Norte'
        WHEN 'RS' THEN 'Rio Grande do Sul'
        WHEN 'RO' THEN 'Rondônia'
        WHEN 'RR' THEN 'Roraima'
        WHEN 'SC' THEN 'Santa Catarina'
        WHEN 'SP' THEN 'São Paulo'
        WHEN 'SE' THEN 'Sergipe'
        WHEN 'TO' THEN 'Tocantins'
        ELSE co.state_normalized
    END as customer_state,
    sum(ca.total_spent) as total_revenue,
    count(*) as customer_count,
    round(sum(ca.total_spent) / count(*), 2) as revenue_per_customer,
    round((sum(ca.total_spent)::decimal / sum(sum(ca.total_spent)) OVER ()) * 100, 2) as revenue_percentage
FROM olist_marts.mart_customer_analytics ca
JOIN olist_intermediate.int_customer_orders co ON ca.customer_id = co.customer_id
GROUP BY 1
ORDER BY 2 DESC;

-- 5.3 Average revenue per day since first purchase
SELECT
    customer_tier,
    count(*) as customer_count,
    sum(total_spent) as total_revenue,
    round(avg(customer_lifetime_days), 2) as avg_days_since_first_order,
    round(sum(daily_customer_value), 2) as avg_revenue_per_day_lifetime
FROM olist_marts.mart_customer_analytics
WHERE customer_lifetime_days > 0
GROUP BY 1
ORDER BY 5 DESC;