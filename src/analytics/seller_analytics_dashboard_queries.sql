-- ====================================================
-- SELLER ANALYTICS DASHBOARD QUERIES
-- ====================================================
-- These queries are designed to be used with Metabase for creating a
-- comprehensive Seller Analytics Dashboard.
-- ====================================================

-- 1. SELLER PERFORMANCE OVERVIEW
-- ------------------------------------

-- 1.1 Top sellers by revenue
SELECT
    seller_id,
    seller_city,
    seller_state,
    total_orders,
    total_items_sold,
    total_revenue,
    total_gmv,
    round(average_review_score, 2) as average_review_score,
    delivered_orders,
    canceled_orders
FROM olist_marts.mart_seller_analytics
ORDER BY total_revenue DESC
LIMIT 20;

-- 1.2 Seller growth over time
WITH monthly_sales AS (
    SELECT
        seller_id,
        date_trunc('month', order_date) as month,
        count(*) as order_count,
        sum(order_value) as revenue
    FROM olist_marts.mart_seller_analytics
    CROSS JOIN LATERAL unnest(order_dates) WITH ORDINALITY AS o(order_date, idx)
    CROSS JOIN LATERAL unnest(order_values) WITH ORDINALITY AS v(order_value, idx2)
    WHERE idx = idx2  -- Match corresponding dates and values
    GROUP BY 1, 2
)
SELECT
    month,
    count(distinct seller_id) as active_sellers,
    sum(order_count) as total_orders,
    sum(revenue) as total_revenue,
    round(sum(revenue) / count(distinct seller_id), 2) as revenue_per_seller
FROM monthly_sales
GROUP BY 1
ORDER BY 1;

-- 1.3 Seller performance by state
SELECT
    seller_state,
    count(*) as seller_count,
    sum(total_revenue) as total_revenue,
    sum(total_orders) as total_orders,
    round(avg(average_review_score), 2) as avg_review_score,
    round(sum(total_revenue) / count(*), 2) as revenue_per_seller,
    round(sum(total_orders) / count(*), 2) as orders_per_seller,
    round(sum(on_time_deliveries)::decimal / nullif(sum(delivered_orders), 0) * 100, 2) as on_time_delivery_rate
FROM olist_marts.mart_seller_analytics
GROUP BY 1
ORDER BY 3 DESC;

-- 1.4 Seller segment performance
SELECT
    value_segment,
    volume_segment,
    recency_segment,
    count(*) as seller_count,
    sum(total_revenue) as total_revenue,
    round(avg(average_review_score), 2) as avg_review_score,
    round(sum(total_revenue) / sum(total_orders), 2) as avg_order_value,
    round(sum(total_revenue) / count(*), 2) as revenue_per_seller
FROM olist_marts.mart_seller_analytics
GROUP BY 1, 2, 3
ORDER BY 5 DESC;

-- 2. SELLER PRODUCT METRICS
-- ------------------------------------

-- 2.1 Product diversity by seller segment
SELECT
    value_segment,
    count(*) as seller_count,
    sum(unique_products_sold) as total_unique_products,
    round(avg(unique_products_sold), 2) as avg_products_per_seller,
    max(unique_products_sold) as max_products,
    min(unique_products_sold) as min_products
FROM olist_marts.mart_seller_analytics
GROUP BY 1
ORDER BY 4 DESC;

-- 2.2 Top product categories by seller
WITH seller_categories AS (
    SELECT
        seller_id,
        category,
        count(*) as product_count,
        sum(category_revenue) as revenue
    FROM olist_marts.mart_seller_analytics
    CROSS JOIN LATERAL unnest(product_categories) WITH ORDINALITY AS c(category, idx)
    CROSS JOIN LATERAL unnest(category_revenues) WITH ORDINALITY AS r(category_revenue, idx2)
    WHERE idx = idx2  -- Match corresponding categories and revenues
    GROUP BY 1, 2
),
ranked_categories AS (
    SELECT
        seller_id,
        category,
        product_count,
        revenue,
        row_number() OVER (PARTITION BY seller_id ORDER BY revenue DESC) as category_rank
    FROM seller_categories
)
SELECT
    category,
    count(*) as seller_count,
    sum(product_count) as total_products,
    sum(revenue) as total_revenue
FROM ranked_categories
WHERE category_rank = 1 -- Only the top category per seller
GROUP BY 1
ORDER BY 4 DESC;

-- 2.3 Product diversity vs. revenue correlation
SELECT
    CASE
        WHEN unique_products_sold BETWEEN 1 AND 5 THEN '1-5 products'
        WHEN unique_products_sold BETWEEN 6 AND 20 THEN '6-20 products'
        WHEN unique_products_sold BETWEEN 21 AND 50 THEN '21-50 products'
        WHEN unique_products_sold BETWEEN 51 AND 100 THEN '51-100 products'
        ELSE '100+ products'
    END as product_diversity,
    count(*) as seller_count,
    round(avg(total_revenue), 2) as avg_revenue,
    round(avg(total_orders), 2) as avg_orders,
    round(avg(average_review_score), 2) as avg_review_score
FROM olist_marts.mart_seller_analytics
GROUP BY 1
ORDER BY 3 DESC;

-- 3. SELLER DELIVERY & FULFILLMENT
-- ------------------------------------

-- 3.1 On-time delivery performance
SELECT
    seller_id,
    seller_state,
    delivered_orders,
    on_time_deliveries,
    late_deliveries,
    on_time_delivery_rate,
    round(average_delivery_time_days, 1) as avg_delivery_days,
    round(average_delivery_variance_days, 1) as avg_variance_days,
    average_review_score
FROM olist_marts.mart_seller_analytics
WHERE delivered_orders > 10
ORDER BY on_time_delivery_rate DESC
LIMIT 20;

-- 3.2 Delivery performance by state
SELECT
    seller_state,
    sum(delivered_orders) as total_delivered_orders,
    sum(on_time_deliveries) as total_on_time,
    sum(late_deliveries) as total_late,
    round(sum(on_time_deliveries)::decimal / nullif(sum(delivered_orders), 0) * 100, 2) as state_on_time_rate,
    round(avg(average_delivery_time_days), 1) as avg_delivery_days,
    round(avg(average_delivery_variance_days), 1) as avg_variance_days
FROM olist_marts.mart_seller_analytics
GROUP BY 1
ORDER BY 5 DESC;

-- 3.3 Correlation between delivery performance and ratings
SELECT
    CASE
        WHEN on_time_delivery_rate >= 90 THEN '90-100% on-time'
        WHEN on_time_delivery_rate >= 80 THEN '80-89% on-time'
        WHEN on_time_delivery_rate >= 70 THEN '70-79% on-time'
        WHEN on_time_delivery_rate >= 60 THEN '60-69% on-time'
        ELSE 'Below 60% on-time'
    END as delivery_performance,
    count(*) as seller_count,
    round(avg(average_review_score), 2) as avg_review_score,
    count(CASE WHEN rating_segment = 'excellent' THEN 1 END) as excellent_rated_sellers,
    count(CASE WHEN rating_segment = 'poor' THEN 1 END) as poor_rated_sellers,
    round(count(CASE WHEN rating_segment = 'excellent' THEN 1 END)::decimal / count(*) * 100, 2) as pct_excellent_ratings
FROM olist_marts.mart_seller_analytics
WHERE delivered_orders > 5 -- Minimum threshold for meaningful data
GROUP BY 1
ORDER BY 1;

-- 4. SELLER CUSTOMER METRICS
-- ------------------------------------

-- 4.1 Customer acquisition by seller segment
SELECT
    value_segment,
    count(*) as seller_count,
    sum(unique_customers) as total_customers,
    round(avg(unique_customers), 2) as avg_customers_per_seller,
    round(sum(unique_customers)::decimal / sum(total_orders), 3) as customer_order_ratio
FROM olist_marts.mart_seller_analytics
GROUP BY 1
ORDER BY 4 DESC;

-- 4.2 Top sellers by customer retention
SELECT
    s.seller_id,
    s.seller_city,
    s.seller_state,
    s.total_orders,
    s.total_revenue,
    s.unique_customers as total_customers,
    s.returning_customers,
    round(s.returning_customers::decimal / nullif(s.unique_customers, 0) * 100, 2) as retention_rate,
    s.average_review_score
FROM olist_marts.mart_seller_analytics s
WHERE s.unique_customers > 10 -- Minimum threshold for meaningful data
ORDER BY 8 DESC
LIMIT 20;

-- 5. SELLER REVIEW & SATISFACTION
-- ------------------------------------

-- 5.1 Seller reviews distribution
SELECT
    rating_segment,
    count(*) as seller_count,
    round(min(average_review_score), 2) as min_review_score,
    round(avg(average_review_score), 2) as avg_review_score,
    round(max(average_review_score), 2) as max_review_score,
    sum(total_orders) as total_orders,
    sum(total_revenue) as total_revenue,
    round(sum(total_revenue) / sum(total_orders), 2) as avg_order_value
FROM olist_marts.mart_seller_analytics
WHERE total_orders > 5
GROUP BY 1
ORDER BY 3 DESC;

-- 5.2 Review score vs. revenue analysis
SELECT
    CASE
        WHEN average_review_score BETWEEN 1 AND 1.9 THEN '1.0-1.9'
        WHEN average_review_score BETWEEN 2 AND 2.9 THEN '2.0-2.9'
        WHEN average_review_score BETWEEN 3 AND 3.4 THEN '3.0-3.4'
        WHEN average_review_score BETWEEN 3.5 AND 3.9 THEN '3.5-3.9'
        WHEN average_review_score BETWEEN 4 AND 4.4 THEN '4.0-4.4'
        WHEN average_review_score BETWEEN 4.5 AND 5 THEN '4.5-5.0'
        ELSE 'No reviews'
    END as review_score_range,
    count(*) as seller_count,
    round(avg(total_orders), 2) as avg_orders,
    round(avg(total_revenue), 2) as avg_revenue,
    round(sum(total_revenue) / count(*), 2) as revenue_per_seller,
    round(sum(total_revenue) / sum(total_orders), 2) as avg_order_value
FROM olist_marts.mart_seller_analytics
WHERE total_orders > 5
GROUP BY 1
ORDER BY 1;

-- 5.3 Positive review rate correlation with other metrics
SELECT
    value_segment,
    count(*) as seller_count,
    round(avg(positive_review_rate), 2) as avg_positive_review_rate,
    round(avg(total_revenue), 2) as avg_revenue,
    round(avg(on_time_delivery_rate), 2) as avg_on_time_delivery_rate,
    round(avg(average_delivery_time_days), 1) as avg_delivery_days
FROM olist_marts.mart_seller_analytics
WHERE orders_with_reviews > 5
GROUP BY 1
ORDER BY 3 DESC;