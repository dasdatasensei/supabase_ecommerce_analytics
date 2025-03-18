with customer_orders as (
    select * from {{ ref('int_customer_orders') }}
),

customer_segments as (
    select
        customer_id,
        frequency_segment,
        value_segment,
        nps_segment,

        -- Core metrics
        total_orders,
        total_spent,
        avg_order_amount,
        avg_review_score,

        -- Derived metrics
        first_order_at as first_order_date,
        last_order_at as last_order_date,
        customer_lifetime_days,
        spend_per_day as daily_customer_value,

        -- Additional metrics
        unique_sellers_bought_from,
        total_items_purchased,
        positive_review_rate,
        on_time_delivery_rate,

        -- Segment specific metrics
        case
            when frequency_segment = 'high_frequency' and value_segment = 'high_value' then 'VIP'
            when frequency_segment = 'high_frequency' and value_segment = 'medium_value' then 'Loyal'
            when frequency_segment = 'medium_frequency' and value_segment in ('high_value', 'medium_value') then 'Growing'
            when frequency_segment = 'low_frequency' and value_segment = 'high_value' then 'Big Spender'
            else 'Standard'
        end as customer_tier,

        -- Satisfaction indicators
        case
            when nps_segment = 'promoter' then 1
            else 0
        end as is_promoter,
        case
            when last_order_at >= (current_date - interval '3 months') then 1
            else 0
        end as is_active

    from customer_orders
),

customer_metrics as (
    select
        cs.*,
        -- Relative value metrics
        total_spent / nullif(avg(total_spent) over (), 0) as relative_customer_value,
        avg_order_amount / nullif(avg(avg_order_amount) over (), 0) as relative_order_value,
        -- Percentile calculations
        percent_rank() over (order by total_spent) as spend_percentile,
        percent_rank() over (order by total_orders) as frequency_percentile,
        percent_rank() over (order by avg_review_score) as satisfaction_percentile
    from customer_segments cs
)

select
    -- Primary key
    customer_id,

    -- Segment information
    frequency_segment,
    value_segment,
    nps_segment,
    customer_tier,

    -- Core metrics
    total_orders,
    total_spent,
    avg_order_amount as avg_order_value,
    avg_review_score,

    -- Temporal metrics
    first_order_date,
    last_order_date,
    customer_lifetime_days,
    daily_customer_value,

    -- Additional metrics
    unique_sellers_bought_from,
    total_items_purchased,
    positive_review_rate,
    on_time_delivery_rate,

    -- Status flags
    is_promoter,
    is_active,

    -- Relative performance
    relative_customer_value,
    relative_order_value,

    -- Percentiles
    spend_percentile,
    frequency_percentile,
    satisfaction_percentile,

    -- Metadata
    current_timestamp as generated_at

from customer_metrics