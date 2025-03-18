-- depends_on: {{ ref('int_orders_with_items') }}
{{
    config(
        materialized='incremental',
        unique_key='seller_id',
        on_schema_change='sync_all_columns',
        post_hook=[
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_seller_id_idx ON {{ this }} (seller_id)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_seller_state_idx ON {{ this }} (seller_state)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_total_orders_idx ON {{ this }} (total_orders)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_last_order_date_idx ON {{ this }} (last_order_date)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_recency_segment_idx ON {{ this }} (recency_segment)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_volume_segment_idx ON {{ this }} (volume_segment)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_avg_review_score_idx ON {{ this }} (average_review_score)"
        ]
    )
}}

with sellers as (

    select * from {{ ref('stg_olist__sellers') }}

),

order_items as (

    select * from {{ ref('stg_olist__order_items') }}

),

orders as (

    select * from {{ ref('stg_olist__orders') }}
    {% if is_incremental() %}
    -- Only process orders newer than the latest order in the existing table
    where purchased_at > (select coalesce(max(last_order_date), '2000-01-01'::timestamp) from {{ this }})
    {% endif %}

),

modified_sellers as (
    {% if is_incremental() %}
    -- Get seller_ids with new order activity
    select distinct oi.seller_id
    from order_items oi
    inner join orders o
        on oi.order_id = o.order_id
    {% else %}
    -- For full refresh, include all sellers
    select distinct seller_id
    from {{ ref('stg_olist__sellers') }}
    {% endif %}
),

seller_orders as (

    select
        oi.seller_id,

        -- order statistics
        count(distinct oi.order_id) as total_orders,
        sum(o.is_delivered::int) as delivered_orders,
        sum((o.order_status = 'canceled')::int) as canceled_orders,
        sum(o.is_delivered_on_time::int) as on_time_deliveries,
        sum(case when not o.is_delivered_on_time and o.is_delivered then 1 else 0 end) as late_deliveries,

        -- product metrics
        count(distinct oi.product_id) as unique_products_sold,
        count(oi.order_item_id) as total_items_sold,

        -- monetary values
        sum(oi.price_amount) as total_revenue,
        sum(oi.shipping_amount) as total_shipping_revenue,
        sum(oi.total_amount) as total_gmv,
        avg(oi.price_amount) as average_item_price,
        avg(oi.shipping_amount) as average_shipping_fee,

        -- customer metrics
        count(distinct o.customer_id) as unique_customers,

        -- review metrics
        avg(r.review_score) as average_review_score,
        count(distinct case when r.review_score is not null then o.order_id end) as orders_with_reviews,
        count(distinct case when r.is_positive_review then o.order_id end) as positive_reviews,
        count(distinct case when r.is_negative_review then o.order_id end) as negative_reviews,
        count(distinct case when r.has_review_comment then o.order_id end) as reviews_with_comments,

        -- date/time metrics
        min(o.purchased_at) as first_order_date,
        max(o.purchased_at) as last_order_date,
        avg(o.delivery_time_days) as average_delivery_time_days,
        avg(o.delivery_variance_days) as average_delivery_variance_days,

        -- activity metrics
        count(distinct date_trunc('month', o.purchased_at)) as active_months

    from order_items oi
    inner join orders o
        on oi.order_id = o.order_id
    left join {{ ref('int_orders_with_items') }} r
        on oi.order_id = r.order_id
    group by 1

),

seller_locations as (

    select
        s.seller_id,
        s.seller_city,
        s.seller_state,
        s.geolocation_lat,
        s.geolocation_lng
    from sellers s

),

final as (

    select
        -- seller keys and attributes
        l.seller_id,
        l.seller_city,
        l.seller_state,
        l.geolocation_lat,
        l.geolocation_lng,

        -- order statistics
        coalesce(o.total_orders, 0) as total_orders,
        coalesce(o.delivered_orders, 0) as delivered_orders,
        coalesce(o.canceled_orders, 0) as canceled_orders,
        coalesce(o.on_time_deliveries, 0) as on_time_deliveries,
        coalesce(o.late_deliveries, 0) as late_deliveries,

        -- product metrics
        coalesce(o.unique_products_sold, 0) as unique_products_sold,
        coalesce(o.total_items_sold, 0) as total_items_sold,

        -- monetary values
        coalesce(o.total_revenue, 0) as total_revenue,
        coalesce(o.total_shipping_revenue, 0) as total_shipping_revenue,
        coalesce(o.total_gmv, 0) as total_gmv,
        coalesce(o.average_item_price, 0) as average_item_price,
        coalesce(o.average_shipping_fee, 0) as average_shipping_fee,

        -- customer metrics
        coalesce(o.unique_customers, 0) as unique_customers,

        -- review metrics
        o.average_review_score,
        coalesce(o.orders_with_reviews, 0) as orders_with_reviews,
        coalesce(o.positive_reviews, 0) as positive_reviews,
        coalesce(o.negative_reviews, 0) as negative_reviews,
        coalesce(o.reviews_with_comments, 0) as reviews_with_comments,

        -- date/time metrics
        o.first_order_date,
        o.last_order_date,
        coalesce(o.average_delivery_time_days, 0) as average_delivery_time_days,
        coalesce(o.average_delivery_variance_days, 0) as average_delivery_variance_days,
        date_part('day', now() - o.first_order_date) as days_since_first_order,
        date_part('day', now() - o.last_order_date) as days_since_last_order,

        -- activity metrics
        coalesce(o.active_months, 0) as active_months,

        -- calculated metrics
        case
            when o.last_order_date is null then 'no_orders'
            when date_part('day', now() - o.last_order_date) <= 30 then 'active_30d'
            when date_part('day', now() - o.last_order_date) <= 90 then 'active_90d'
            when date_part('day', now() - o.last_order_date) <= 180 then 'active_180d'
            when date_part('day', now() - o.last_order_date) <= 365 then 'active_365d'
            else 'inactive'
        end as recency_segment,

        case
            when o.total_orders >= 50 then 'high_volume'
            when o.total_orders >= 10 then 'medium_volume'
            else 'low_volume'
        end as volume_segment,

        case
            when o.total_gmv >= 10000 then 'high_value'
            when o.total_gmv >= 1000 then 'medium_value'
            else 'low_value'
        end as value_segment,

        case
            when o.average_review_score >= 4.5 then 'excellent'
            when o.average_review_score >= 4.0 then 'good'
            when o.average_review_score >= 3.0 then 'average'
            when o.average_review_score is null then 'unknown'
            else 'poor'
        end as rating_segment,

        case
            when o.on_time_deliveries > 0 and o.total_orders > 0
            then round((o.on_time_deliveries::decimal / nullif(o.delivered_orders, 0)) * 100, 2)
            else 0
        end as on_time_delivery_rate,

        case
            when o.positive_reviews > 0 and o.orders_with_reviews > 0
            then round((o.positive_reviews::decimal / nullif(o.orders_with_reviews, 0)) * 100, 2)
            else 0
        end as positive_review_rate

    from seller_locations l
    left join seller_orders o
        on l.seller_id = o.seller_id
    {% if is_incremental() %}
    where l.seller_id in (select seller_id from modified_sellers)
    {% endif %}
)

select * from final