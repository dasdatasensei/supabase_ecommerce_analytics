-- ====================================================
-- PRODUCT ANALYTICS DASHBOARD QUERIES
-- ====================================================
-- These queries are designed to be used with Metabase for creating a
-- comprehensive Product Analytics Dashboard.
-- ====================================================

-- 1. PRODUCT PERFORMANCE OVERVIEW
-- ------------------------------------

-- 1.1 Top-selling products
SELECT
    p.category_name,
    p.total_orders,
    p.gmv as Gross Merchandise Value,
    p.avg_price,
    round(p.avg_review_score, 2) as avg_review_score,
    round(p.gmv / NULLIF(p.total_orders, 0), 2) as revenue_per_order,
    p.volume_ranking,
    p.rating_tier
FROM olist_marts.mart_product_analytics p
ORDER BY p.total_orders DESC
LIMIT 20;

-- 1.2 Product sales trends over time
SELECT
    date_trunc('month', p.first_ordered_at) as month,
    count(distinct p.product_id) as products_sold,
    sum(p.total_orders) as total_orders,
    sum(p.gmv) as total_revenue,
    round(sum(p.gmv) / NULLIF(sum(p.total_orders), 0), 2) as avg_order_value
FROM olist_marts.mart_product_analytics p
GROUP BY 1
ORDER BY 1;

-- 1.3 Category performance comparison
SELECT
    category_name,
    count(*) as product_count,
    sum(total_orders) as total_orders,
    sum(gmv) as total_gmv,
    round(avg(avg_review_score), 2) as avg_review_score,
    round(sum(gmv) / nullif(sum(total_orders), 0), 2) as avg_order_value,
    round(sum(gmv) / nullif(count(*), 0), 2) as revenue_per_product
FROM olist_marts.mart_product_analytics
GROUP BY 1
ORDER BY 4 DESC;

-- 1.4 Price point analysis
SELECT
    CASE
        WHEN avg_price < 50 THEN 'Under $50'
        WHEN avg_price BETWEEN 50 AND 99.99 THEN '$50-$99'
        WHEN avg_price BETWEEN 100 AND 249.99 THEN '$100-$249'
        WHEN avg_price BETWEEN 250 AND 499.99 THEN '$250-$499'
        WHEN avg_price BETWEEN 500 AND 999.99 THEN '$500-$999'
        ELSE '$1000+'
    END as price_range,
    count(*) as product_count,
    sum(total_orders) as total_orders,
    sum(gmv) as total_gmv,
    round(avg(avg_review_score), 2) as avg_review_score,
    round(sum(gmv) / nullif(sum(total_orders), 0), 2) as avg_order_value
FROM olist_marts.mart_product_analytics
WHERE total_orders > 0
GROUP BY 1
ORDER BY 4 DESC;

-- 2. PRODUCT CATEGORY INSIGHTS
-- ------------------------------------

-- 2.1 Category trends over time
WITH product_monthly AS (
    SELECT
        category_name,
        date_trunc('month', first_ordered_at) as month,
        sum(total_orders) as order_count,
        count(distinct product_id) as product_count,
        sum(gmv) as total_revenue
    FROM olist_marts.mart_product_analytics
    GROUP BY 1, 2
)
SELECT
    category_name,
    month,
    order_count,
    product_count,
    total_revenue,
    round(total_revenue / NULLIF(order_count, 0), 2) as avg_order_value
FROM product_monthly
ORDER BY 1, 2;

-- 2.2 Category seasonality by product introduction
WITH category_monthly_introductions AS (
    SELECT
        category_name,
        date_part('month', first_ordered_at) as month_number,
        to_char(first_ordered_at, 'Month') as month_name,
        count(*) as new_products,
        sum(gmv) as total_revenue
    FROM olist_marts.mart_product_analytics
    GROUP BY 1, 2, 3
)
SELECT
    category_name,
    month_number,
    month_name,
    new_products,
    total_revenue,
    round(total_revenue / sum(total_revenue) OVER (PARTITION BY category_name) * 100, 2) as pct_category_revenue
FROM category_monthly_introductions
ORDER BY 1, 2;

-- 2.3 Category ranking by review and value metrics
SELECT
    category_name,
    count(*) as product_count,
    round(avg(avg_review_score), 2) as avg_category_rating,
    sum(total_orders) as total_orders,
    sum(gmv) as total_revenue,
    round(sum(gmv) / nullif(sum(total_orders), 0), 2) as avg_order_value,
    round(avg(price_variance), 2) as avg_price_variance,
    count(CASE WHEN rating_tier = 'excellent' THEN 1 END) as excellent_rated_products,
    count(CASE WHEN rating_tier NOT IN ('excellent', 'poor') THEN 1 END) as average_rated_products,
    count(CASE WHEN rating_tier = 'poor' THEN 1 END) as poorly_rated_products
FROM olist_marts.mart_product_analytics
GROUP BY 1
ORDER BY 3 DESC;

-- 2.4 Category correlation analysis
WITH category_stats AS (
    SELECT
        category_name,
        avg(avg_price) as avg_category_price,
        sum(total_orders) as category_total_orders,
        avg(avg_review_score) as category_avg_review,
        count(distinct product_id) as product_count
    FROM olist_marts.mart_product_analytics
    GROUP BY 1
    HAVING count(distinct product_id) > 5
)
SELECT
    c1.category_name as category_1,
    c2.category_name as category_2,
    c1.product_count as products_in_category_1,
    c2.product_count as products_in_category_2,
    round(c1.category_avg_review, 2) as category_1_avg_rating,
    round(c2.category_avg_review, 2) as category_2_avg_rating,
    round(corr(p1.avg_price, p2.avg_price)::numeric, 2) as price_correlation,
    round(corr(p1.total_orders, p2.total_orders)::numeric, 2) as order_volume_correlation
FROM category_stats c1
JOIN category_stats c2 ON c1.category_name < c2.category_name
JOIN olist_marts.mart_product_analytics p1 ON p1.category_name = c1.category_name
JOIN olist_marts.mart_product_analytics p2 ON p2.category_name = c2.category_name
GROUP BY 1, 2, 3, 4, 5, 6
ORDER BY 8 DESC, 7 DESC
LIMIT 20;

-- 3. PRODUCT QUALITY & REVIEWS
-- ------------------------------------

-- 3.1 Product review distribution
SELECT
    CASE
        WHEN avg_review_score BETWEEN 1 AND 1.9 THEN '1.0-1.9'
        WHEN avg_review_score BETWEEN 2 AND 2.9 THEN '2.0-2.9'
        WHEN avg_review_score BETWEEN 3 AND 3.4 THEN '3.0-3.4'
        WHEN avg_review_score BETWEEN 3.5 AND 3.9 THEN '3.5-3.9'
        WHEN avg_review_score BETWEEN 4 AND 4.4 THEN '4.0-4.4'
        WHEN avg_review_score BETWEEN 4.5 AND 5 THEN '4.5-5.0'
        ELSE 'No reviews'
    END as review_range,
    count(*) as product_count,
    round(sum(gmv)::decimal / sum(sum(gmv)) OVER () * 100, 2) as pct_total_revenue,
    sum(total_orders) as total_orders,
    sum(gmv) as total_revenue,
    round(sum(gmv) / nullif(sum(total_orders), 0), 2) as avg_order_value
FROM olist_marts.mart_product_analytics
GROUP BY 1
ORDER BY 1;

-- 3.2 Reviews vs. revenue correlation
SELECT
    rating_tier,
    count(*) as product_count,
    round(avg(avg_review_score), 2) as avg_review_score,
    sum(total_orders) as total_orders,
    sum(gmv) as total_revenue,
    round(sum(gmv) / nullif(sum(total_orders), 0), 2) as avg_order_value,
    round(sum(gmv)::decimal / sum(sum(gmv)) OVER () * 100, 2) as pct_total_revenue
FROM olist_marts.mart_product_analytics
WHERE review_count > 0
GROUP BY 1
ORDER BY 3 DESC;

-- 3.3 Category review performance
SELECT
    category_name,
    count(*) as product_count,
    round(avg(avg_review_score), 2) as avg_review_score,
    count(CASE WHEN avg_review_score >= 4.5 THEN 1 END) as excellent_products,
    count(CASE WHEN avg_review_score <= 2.5 THEN 1 END) as poor_products,
    round(count(CASE WHEN avg_review_score >= 4.5 THEN 1 END)::decimal / nullif(count(*), 0) * 100, 2) as pct_excellent,
    round(count(CASE WHEN avg_review_score <= 2.5 THEN 1 END)::decimal / nullif(count(*), 0) * 100, 2) as pct_poor
FROM olist_marts.mart_product_analytics
WHERE review_count > 0
GROUP BY 1
ORDER BY 3 DESC;

-- 4. PRODUCT DELIVERY & LOGISTICS
-- ------------------------------------

-- 4.1 Product weight and price analysis
SELECT
    CASE
        WHEN weight_g < 500 THEN 'Lightweight (<500g)'
        WHEN weight_g BETWEEN 500 AND 1999 THEN 'Medium (500g-2kg)'
        WHEN weight_g BETWEEN 2000 AND 4999 THEN 'Heavy (2-5kg)'
        WHEN weight_g BETWEEN 5000 AND 9999 THEN 'Very Heavy (5-10kg)'
        WHEN weight_g >= 10000 THEN 'Bulky (10kg+)'
        ELSE 'Unknown'
    END as weight_category,
    count(*) as product_count,
    round(avg(avg_price), 2) as avg_price,
    sum(total_orders) as total_orders,
    sum(gmv) as total_revenue,
    round(sum(gmv) / nullif(sum(total_orders), 0), 2) as avg_order_value
FROM olist_marts.mart_product_analytics
WHERE weight_g IS NOT NULL
GROUP BY 1
ORDER BY 3 DESC;

-- 4.2 Physical dimensions impact on sales
SELECT
    CASE
        WHEN volume_cm3 < 1000 THEN 'Very Small (<1,000 cm³)'
        WHEN volume_cm3 BETWEEN 1000 AND 4999 THEN 'Small (1,000-5,000 cm³)'
        WHEN volume_cm3 BETWEEN 5000 AND 19999 THEN 'Medium (5,000-20,000 cm³)'
        WHEN volume_cm3 BETWEEN 20000 AND 49999 THEN 'Large (20,000-50,000 cm³)'
        WHEN volume_cm3 >= 50000 THEN 'Very Large (50,000+ cm³)'
        ELSE 'Dimensions Missing'
    END as size_category,
    count(*) as product_count,
    round(avg(avg_price), 2) as avg_price,
    sum(total_orders) as total_orders,
    sum(gmv) as total_revenue,
    round(avg(avg_review_score), 2) as avg_review_score
FROM olist_marts.mart_product_analytics
GROUP BY 1
ORDER BY 4 DESC;

-- 5. PRODUCT INVENTORY & PERFORMANCE
-- ------------------------------------

-- 5.1 Top product categories by revenue
SELECT
    category_name,
    count(*) as product_count,
    sum(total_orders) as total_orders,
    sum(gmv) as total_revenue,
    round(sum(gmv) / nullif(count(*), 0), 2) as revenue_per_product,
    round(avg(avg_review_score), 2) as avg_review_score
FROM olist_marts.mart_product_analytics
GROUP BY 1
ORDER BY 4 DESC
LIMIT 20;

-- 5.2 Product ranking by volume tier
SELECT
    volume_ranking,
    count(*) as product_count,
    sum(total_orders) as total_orders,
    sum(gmv) as total_revenue,
    round(sum(gmv) / nullif(sum(total_orders), 0), 2) as avg_order_value,
    round(avg(avg_review_score), 2) as avg_review_score,
    round(sum(gmv)::decimal / sum(sum(gmv)) OVER () * 100, 2) as pct_total_revenue
FROM olist_marts.mart_product_analytics
GROUP BY 1
ORDER BY 3 DESC;

-- 5.3 Product lifecycle analysis
SELECT
    category_name,
    round(avg(active_months)::numeric, 1) as avg_active_months,
    round(avg(days_since_first_order)::numeric, 1) as avg_days_since_first_order,
    round(avg(days_since_last_order)::numeric, 1) as avg_days_since_last_order,
    count(*) as product_count,
    count(CASE WHEN days_since_last_order <= 90 THEN 1 END) as recently_sold_products,
    round(count(CASE WHEN days_since_last_order <= 90 THEN 1 END)::decimal / nullif(count(*), 0) * 100, 2) as pct_recently_sold
FROM olist_marts.mart_product_analytics
GROUP BY 1
ORDER BY 7 DESC;