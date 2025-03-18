with intermediate_seller_performance as (
    select * from {{ ref('int_seller_performance') }}
),

-- Calculate seller percentiles based on various metrics
seller_rankings as (
    select
        *,
        percent_rank() over (order by total_gmv desc) as gmv_percentile,
        percent_rank() over (order by avg_review_score desc) as review_score_percentile,
        percent_rank() over (order by on_time_delivery_rate desc) as delivery_rate_percentile,
        percent_rank() over (order by total_orders desc) as order_volume_percentile
    from intermediate_seller_performance
)

select
    -- Seller IDs and location
    seller_id,
    zip_code_prefix,
    city_normalized,
    state_normalized,

    -- Core metrics
    total_orders,
    total_gmv,
    unique_customers,
    avg_review_score,
    on_time_delivery_rate,
    avg_delivery_time_days,

    -- Customer relationships
    customer_reorder_rate,
    first_order_at,
    last_order_at,
    seller_lifetime_days,
    active_months,

    -- Volume metrics
    orders_per_month,
    gmv_per_month,
    avg_order_value,

    -- Review metrics
    positive_reviews,
    negative_reviews,
    positive_review_rate,

    -- Segments
    volume_segment,
    value_segment,
    performance_segment,
    delivery_segment,

    -- Rankings (percentiles)
    case
        when gmv_percentile >= 0.9 then 'top 10%'
        when gmv_percentile >= 0.7 then 'top 30%'
        when gmv_percentile >= 0.5 then 'top 50%'
        else 'bottom 50%'
    end as gmv_ranking,

    case
        when review_score_percentile >= 0.9 then 'top 10%'
        when review_score_percentile >= 0.7 then 'top 30%'
        when review_score_percentile >= 0.5 then 'top 50%'
        else 'bottom 50%'
    end as review_ranking,

    case
        when delivery_rate_percentile >= 0.9 then 'top 10%'
        when delivery_rate_percentile >= 0.7 then 'top 30%'
        when delivery_rate_percentile >= 0.5 then 'top 50%'
        else 'bottom 50%'
    end as delivery_ranking,

    case
        when order_volume_percentile >= 0.9 then 'top 10%'
        when order_volume_percentile >= 0.7 then 'top 30%'
        when order_volume_percentile >= 0.5 then 'top 50%'
        else 'bottom 50%'
    end as volume_ranking,

    -- Overall seller rank score (average of percentiles)
    (gmv_percentile + review_score_percentile + delivery_rate_percentile + order_volume_percentile) / 4
        as overall_seller_score,

    -- Metadata
    current_timestamp as generated_at

from seller_rankings