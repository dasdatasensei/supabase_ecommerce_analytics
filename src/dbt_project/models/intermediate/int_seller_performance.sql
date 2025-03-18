{{
    config(
        materialized='incremental',
        unique_key='seller_id',
        on_schema_change='sync_all_columns'
    )
}}

with sellers as (

    select * from {{ ref('stg_olist__sellers') }}

),

orders_with_items as (

    select * from {{ ref('int_orders_with_items') }}
    {% if is_incremental() %}
    -- Only fetch new orders or updated orders since last run
    where purchased_at > (select coalesce(max(last_order_at), '2000-01-01'::timestamp) from {{ this }})
    {% endif %}

),

order_items as (

    select * from {{ ref('stg_olist__order_items') }}
    {% if is_incremental() %}
    -- Only process order items for updated orders
    where order_id in (select order_id from orders_with_items)
    {% endif %}

),

modified_sellers as (
    {% if is_incremental() %}
    -- Get sellers who have new/updated orders
    select distinct oi.seller_id
    from order_items oi
    {% else %}
    -- For full refresh, include all sellers
    select distinct seller_id
    from {{ ref('stg_olist__sellers') }}
    {% endif %}
),

seller_orders as (

    select
        -- seller keys
        s.seller_id,
        s.zip_code_prefix,
        s.city_normalized,
        s.state_normalized,

        -- order counts
        count(distinct o.order_id) as total_orders,
        sum(case when o.order_status = 'delivered' then 1 else 0 end) as delivered_orders,
        sum(case when o.order_status = 'canceled' then 1 else 0 end) as canceled_orders,

        -- customers
        count(distinct o.customer_id) as unique_customers,

        -- financial metrics
        sum(oi.price_amount) as total_gmv,
        avg(oi.price_amount) as avg_order_item_value,
        sum(oi.shipping_amount) as total_shipping_collected,

        -- review metrics
        avg(o.review_score) as avg_review_score,
        count(case when o.is_positive_review then 1 end) as positive_reviews,
        count(case when o.is_negative_review then 1 end) as negative_reviews,

        -- delivery metrics
        avg(o.delivery_time_days) as avg_delivery_time_days,
        sum(case when o.is_delivered_on_time then 1 else 0 end) as on_time_deliveries,
        sum(case when not o.is_delivered_on_time then 1 else 0 end) as late_deliveries,

        -- timestamps
        min(o.purchased_at) as first_order_at,
        max(o.purchased_at) as last_order_at,

        -- calculated fields
        count(distinct date_trunc('month', o.purchased_at)) as active_months,
        date_part('day', max(o.purchased_at) - min(o.purchased_at)) as seller_lifetime_days

    from sellers s
    left join order_items oi
        on s.seller_id = oi.seller_id
    left join orders_with_items o
        on oi.order_id = o.order_id
    {% if is_incremental() %}
    where s.seller_id in (select seller_id from modified_sellers)
    {% endif %}
    group by 1, 2, 3, 4

),

final as (

    select
        *,
        -- derived metrics
        cast((total_orders::decimal / nullif(active_months, 0)) as numeric(10,2)) as orders_per_month,
        cast((total_gmv::decimal / nullif(active_months, 0)) as numeric(10,2)) as gmv_per_month,
        cast((total_gmv::decimal / nullif(total_orders, 0)) as numeric(10,2)) as avg_order_value,
        cast(((positive_reviews::decimal / nullif(total_orders, 0)) * 100) as numeric(10,2)) as positive_review_rate,
        cast(((on_time_deliveries::decimal / nullif(total_orders, 0)) * 100) as numeric(10,2)) as on_time_delivery_rate,
        cast((unique_customers::decimal / nullif(total_orders, 0)) as numeric(10,2)) as customer_reorder_rate,

        -- seller segments
        case
            when total_orders >= 100 then 'high_volume'
            when total_orders >= 20 then 'medium_volume'
            else 'low_volume'
        end as volume_segment,

        case
            when total_gmv >= 50000 then 'high_value'
            when total_gmv >= 10000 then 'medium_value'
            else 'low_value'
        end as value_segment,

        case
            when avg_review_score >= 4.5 then 'excellent'
            when avg_review_score >= 4.0 then 'good'
            when avg_review_score >= 3.0 then 'average'
            else 'poor'
        end as performance_segment,

        case
            when cast(((on_time_deliveries::decimal / nullif(total_orders, 0)) * 100) as numeric(10,2)) >= 95 then 'excellent'
            when cast(((on_time_deliveries::decimal / nullif(total_orders, 0)) * 100) as numeric(10,2)) >= 85 then 'good'
            when cast(((on_time_deliveries::decimal / nullif(total_orders, 0)) * 100) as numeric(10,2)) >= 70 then 'average'
            else 'poor'
        end as delivery_segment

    from seller_orders

)

{% if is_incremental() %}
-- For incremental updates, merge with existing data
select
    f.*
from final f
{% else %}
-- For full refresh, just use the final CTE
select * from final
{% endif %}