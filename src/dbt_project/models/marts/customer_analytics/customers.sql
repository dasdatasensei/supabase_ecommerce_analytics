{{
    config(
        materialized='incremental',
        unique_key='customer_id',
        on_schema_change='sync_all_columns',
        post_hook=[
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_customer_id_idx ON {{ this }} (customer_id)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_customer_state_idx ON {{ this }} (customer_state)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_customer_city_idx ON {{ this }} (customer_city)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_first_order_date_idx ON {{ this }} (first_order_date)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_last_order_date_idx ON {{ this }} (last_order_date)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_total_orders_idx ON {{ this }} (total_orders)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_ltv_idx ON {{ this }} (customer_total_gmv)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_recency_segment_idx ON {{ this }} (recency_segment)"
        ]
    )
}}

with customer_base as (

    select * from {{ ref('stg_olist__customers') }}

),

orders_with_items as (

    select * from {{ ref('int_orders_with_items') }}
    {% if is_incremental() %}
    -- Only process orders newer than the latest order in the existing table
    where purchased_at > (select coalesce(max(last_order_date), '2000-01-01'::timestamp) from {{ this }})
    {% endif %}

),

modified_customers as (
    {% if is_incremental() %}
    -- Get customer_ids with new order activity
    select distinct customer_id
    from orders_with_items
    {% else %}
    -- For full refresh, include all customers
    select distinct customer_id
    from {{ ref('stg_olist__customers') }}
    {% endif %}
),

customer_orders as (

    select
        o.customer_id,

        -- order statistics
        count(distinct o.order_id) as total_orders,
        sum(o.is_delivered) as delivered_orders,
        sum(o.is_canceled) as canceled_orders,
        sum(o.is_delivered_on_time) as on_time_deliveries,
        sum(case when not o.is_delivered_on_time and o.is_delivered then 1 else 0 end) as late_deliveries,

        -- monetary values
        sum(o.total_amount) as lifetime_value,
        sum(o.products_amount) as total_products_amount,
        sum(o.shipping_amount) as total_shipping_amount,
        sum(o.payment_total) as total_payment_amount,
        avg(o.total_amount) as average_order_value,
        avg(o.item_count) as average_items_per_order,
        sum(o.item_count) as total_items_purchased,
        sum(o.unique_products) as total_unique_products,
        sum(o.unique_sellers) as total_unique_sellers,
        avg(o.shipping_amount) as average_shipping_amount,

        -- payment methods
        count(distinct case when o.used_credit_card then o.order_id end) as credit_card_orders,
        count(distinct case when o.used_boleto then o.order_id end) as boleto_orders,
        count(distinct case when o.used_voucher then o.order_id end) as voucher_orders,
        count(distinct case when o.used_debit_card then o.order_id end) as debit_card_orders,

        -- review metrics
        avg(o.review_score) as average_review_score,
        count(distinct case when o.review_score is not null then o.order_id end) as orders_with_reviews,
        count(distinct case when o.is_positive_review then o.order_id end) as positive_reviews,
        count(distinct case when o.is_negative_review then o.order_id end) as negative_reviews,
        count(distinct case when o.has_review_comment then o.order_id end) as reviews_with_comments,

        -- date/time metrics
        min(o.purchased_at) as first_order_date,
        max(o.purchased_at) as last_order_date,
        avg(o.delivery_time_days) as average_delivery_time_days,
        avg(o.delivery_variance_days) as average_delivery_variance_days,

        -- activity metrics
        count(distinct date_trunc('month', o.purchased_at)) as active_months

    from orders_with_items o
    group by 1

),

final as (

    select
        -- customer keys and attributes
        c.customer_id,
        c.customer_unique_id,
        c.customer_city,
        c.customer_state,
        c.geolocation_lat,
        c.geolocation_lng,

        -- order statistics
        coalesce(o.total_orders, 0) as total_orders,
        coalesce(o.delivered_orders, 0) as delivered_orders,
        coalesce(o.canceled_orders, 0) as canceled_orders,
        coalesce(o.on_time_deliveries, 0) as on_time_deliveries,
        coalesce(o.late_deliveries, 0) as late_deliveries,

        -- monetary values
        coalesce(o.lifetime_value, 0) as lifetime_value,
        coalesce(o.total_products_amount, 0) as total_products_amount,
        coalesce(o.total_shipping_amount, 0) as total_shipping_amount,
        coalesce(o.total_payment_amount, 0) as total_payment_amount,
        coalesce(o.average_order_value, 0) as average_order_value,
        coalesce(o.average_items_per_order, 0) as average_items_per_order,
        coalesce(o.total_items_purchased, 0) as total_items_purchased,
        coalesce(o.total_unique_products, 0) as total_unique_products,
        coalesce(o.total_unique_sellers, 0) as total_unique_sellers,
        coalesce(o.average_shipping_amount, 0) as average_shipping_amount,

        -- payment methods
        coalesce(o.credit_card_orders, 0) as credit_card_orders,
        coalesce(o.boleto_orders, 0) as boleto_orders,
        coalesce(o.voucher_orders, 0) as voucher_orders,
        coalesce(o.debit_card_orders, 0) as debit_card_orders,

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
            when o.total_orders > 1 then true
            else false
        end as is_repeat_customer,

        case
            when o.last_order_date is null then 'no_orders'
            when date_part('day', now() - o.last_order_date) <= 30 then 'active_30d'
            when date_part('day', now() - o.last_order_date) <= 90 then 'active_90d'
            when date_part('day', now() - o.last_order_date) <= 180 then 'active_180d'
            when date_part('day', now() - o.last_order_date) <= 365 then 'active_365d'
            else 'inactive'
        end as recency_segment,

        case
            when o.total_orders >= 4 then 'high'
            when o.total_orders >= 2 then 'medium'
            else 'low'
        end as frequency_segment,

        case
            when o.lifetime_value >= 500 then 'high'
            when o.lifetime_value >= 100 then 'medium'
            else 'low'
        end as monetary_segment,

        case
            when average_review_score >= 4.5 then 'promoter'
            when average_review_score >= 3.0 then 'passive'
            when average_review_score is null then 'unknown'
            else 'detractor'
        end as nps_segment

    from customer_base c
    left join customer_orders o
        on c.customer_id = o.customer_id
    {% if is_incremental() %}
    where c.customer_id in (select customer_id from modified_customers)
    {% endif %}
)

select * from final