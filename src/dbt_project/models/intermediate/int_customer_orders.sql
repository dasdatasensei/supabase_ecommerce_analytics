{{
    config(
        materialized='incremental',
        unique_key='customer_id',
        on_schema_change='sync_all_columns'
    )
}}

with customers as (

    select * from {{ ref('stg_olist__customers') }}

),

orders_with_items as (

    select * from {{ ref('int_orders_with_items') }}
    {% if is_incremental() %}
    -- Only fetch new orders or updated orders since last run
    where purchased_at > (select coalesce(max(last_order_at), '2000-01-01'::timestamp) from {{ this }})
    {% endif %}

),

modified_customers as (
    {% if is_incremental() %}
    -- Get customers who have new orders
    select distinct customer_id
    from orders_with_items
    {% else %}
    -- For full refresh, include all customers
    select distinct customer_id
    from {{ ref('stg_olist__customers') }}
    {% endif %}
),

-- Prepare payment methods for each customer
customer_payments as (
    select
        o.customer_id,
        array_agg(distinct pm) as all_payment_methods
    from orders_with_items o
    cross join lateral unnest(o.payment_methods) as pm
    {% if is_incremental() %}
    where o.customer_id in (select customer_id from modified_customers)
    {% endif %}
    group by o.customer_id
),

customer_orders as (

    select
        -- customer keys
        c.customer_id,
        c.zip_code_prefix,
        c.city_normalized,
        c.state_normalized,

        -- order counts
        count(distinct o.order_id) as total_orders,
        sum(case when o.order_status = 'delivered' then 1 else 0 end) as delivered_orders,
        sum(case when o.order_status = 'canceled' then 1 else 0 end) as canceled_orders,

        -- items and sellers
        sum(o.number_of_items) as total_items_purchased,
        (select count(distinct s) from orders_with_items o_sub
         cross join lateral unnest(o_sub.seller_ids) as s
         where o_sub.customer_id = c.customer_id) as unique_sellers_bought_from,

        -- financial metrics
        sum(o.total_items_amount) as total_items_amount,
        sum(o.total_shipping_amount) as total_shipping_amount,
        sum(o.total_order_amount) as total_spent,
        avg(o.total_order_amount) as avg_order_amount,
        max(o.total_order_amount) as max_order_amount,

        -- payment behavior
        cp.all_payment_methods as all_payment_methods_used,
        avg(o.max_installments) as avg_installments_used,
        sum(case when o.has_payment_discrepancy then 1 else 0 end) as orders_with_payment_issues,

        -- review behavior
        avg(o.review_score) as avg_review_score,
        count(case when o.is_positive_review then 1 end) as positive_reviews,
        count(case when o.is_negative_review then 1 end) as negative_reviews,
        count(case when o.has_review_comment then 1 end) as reviews_with_comments,

        -- delivery metrics
        avg(o.delivery_time_days) as avg_delivery_time_days,
        sum(case when o.is_delivered_on_time then 1 else 0 end) as on_time_deliveries,
        sum(case when not o.is_delivered_on_time then 1 else 0 end) as late_deliveries,

        -- timestamps
        min(o.purchased_at) as first_order_at,
        max(o.purchased_at) as last_order_at,

        -- calculated fields
        count(distinct date_trunc('month', o.purchased_at)) as active_months,
        date_part('day', max(o.purchased_at) - min(o.purchased_at)) as customer_lifetime_days

    from customers c
    left join orders_with_items o
        on c.customer_id = o.customer_id
    left join customer_payments cp
        on c.customer_id = cp.customer_id
    {% if is_incremental() %}
    where c.customer_id in (select customer_id from modified_customers)
    {% endif %}
    group by 1, 2, 3, 4, cp.all_payment_methods

),

final as (

    select
        *,
        -- derived metrics
        cast((total_orders::decimal / nullif(active_months, 0)) as numeric(10,2)) as orders_per_month,
        cast((total_spent::decimal / nullif(total_orders, 0)) as numeric(10,2)) as avg_monthly_spend,
        cast(((positive_reviews::decimal / nullif(total_orders, 0)) * 100) as numeric(10,2)) as positive_review_rate,
        cast(((on_time_deliveries::decimal / nullif(delivered_orders, 0)) * 100) as numeric(10,2)) as on_time_delivery_rate,
        cast(((canceled_orders::decimal / nullif(total_orders, 0)) * 100) as numeric(10,2)) as order_cancellation_rate,

        -- customer value metrics
        cast((total_spent::decimal / nullif(customer_lifetime_days, 0)) as numeric(10,2)) as spend_per_day,
        cast((total_spent::decimal / nullif(active_months, 0)) as numeric(10,2)) as spend_per_month,

        -- customer segments
        case
            when total_orders >= 5 then 'high_frequency'
            when total_orders >= 2 then 'medium_frequency'
            else 'low_frequency'
        end as frequency_segment,

        case
            when avg_order_amount >= 500 then 'high_value'
            when avg_order_amount >= 100 then 'medium_value'
            else 'low_value'
        end as value_segment,

        case
            when avg_review_score >= 4 then 'promoter'
            when avg_review_score >= 3 then 'passive'
            else 'detractor'
        end as nps_segment

    from customer_orders

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