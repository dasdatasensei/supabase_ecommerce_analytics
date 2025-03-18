with product_performance as (
    select * from {{ ref('int_product_performance') }}
),

product_categories as (
    select * from {{ ref('stg_olist__product_categories') }}
),

-- Join with categories and create rankings for products
product_metrics as (
    select
        p.*,
        c.category_name_english as category_name,
        -- Calculate percentiles for products
        percent_rank() over (order by p.total_orders desc) as order_volume_percentile,
        percent_rank() over (order by p.avg_price desc) as price_percentile,
        percent_rank() over (order by p.avg_review_score desc) as review_score_percentile
    from product_performance p
    left join product_categories c on p.category_id = c.category_id
)

select
    -- Product identifiers
    product_id,
    category_name,
    category_id,

    -- Physical attributes
    weight_g,
    length_cm,
    height_cm,
    width_cm,
    volume_cm3,
    is_missing_dimensions,

    -- Performance metrics
    total_orders,
    gmv,
    avg_price,
    min_price,
    max_price,
    price_variance,

    -- Order metrics
    first_ordered_at,
    last_ordered_at,
    days_since_first_order,
    days_since_last_order,
    active_months,

    -- Review metrics
    review_count,
    avg_review_score,
    positive_reviews,
    negative_reviews,
    review_rate,

    -- Product rankings
    case
        when order_volume_percentile >= 0.9 then 'top 10%'
        when order_volume_percentile >= 0.7 then 'top 30%'
        when order_volume_percentile >= 0.5 then 'top 50%'
        else 'bottom 50%'
    end as volume_ranking,

    case
        when price_percentile >= 0.9 then 'premium'
        when price_percentile >= 0.7 then 'high'
        when price_percentile >= 0.3 then 'medium'
        else 'low'
    end as price_tier,

    case
        when review_score_percentile >= 0.9 then 'excellent'
        when review_score_percentile >= 0.7 then 'good'
        when review_score_percentile >= 0.4 then 'average'
        else 'poor'
    end as rating_tier,

    -- Composite score (average of percentiles)
    (order_volume_percentile + review_score_percentile) / 2 as overall_product_score,

    -- Metadata
    current_timestamp as generated_at

from product_metrics