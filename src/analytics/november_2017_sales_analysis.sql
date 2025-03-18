-- November 2017 Top Contributing Products
WITH nov_2017_products AS (
    SELECT
        product_id,
        category_name,
        first_ordered_at,
        total_orders,
        gmv,
        avg_price,
        avg_review_score
    FROM olist_marts.mart_product_analytics
    WHERE date_trunc('month', first_ordered_at) = '2017-11-01'::date
    AND total_orders > 0
)
SELECT
    product_id,
    category_name,
    to_char(first_ordered_at, 'YYYY-MM-DD') as first_order_date,
    total_orders,
    gmv as total_revenue,
    avg_price,
    round(avg_review_score::numeric, 2) as avg_review_score,
    round(gmv / (SELECT sum(gmv) FROM nov_2017_products) * 100, 2) as pct_of_month_revenue
FROM nov_2017_products
ORDER BY gmv DESC
LIMIT 20;

-- November 2017 Category Performance
SELECT
    category_name,
    count(*) as product_count,
    min(to_char(first_ordered_at, 'YYYY-MM-DD')) as earliest_order_date,
    max(to_char(first_ordered_at, 'YYYY-MM-DD')) as latest_order_date,
    sum(total_orders) as total_orders,
    sum(gmv) as total_revenue,
    round(avg(avg_review_score)::numeric, 2) as avg_review_score,
    round(sum(gmv) / (SELECT sum(gmv)
                      FROM olist_marts.mart_product_analytics
                      WHERE date_trunc('month', first_ordered_at) = '2017-11-01'::date) * 100, 2) as pct_of_month_revenue
FROM olist_marts.mart_product_analytics
WHERE date_trunc('month', first_ordered_at) = '2017-11-01'::date
GROUP BY 1
ORDER BY 6 DESC
LIMIT 10;