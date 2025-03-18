{{
    config(
        materialized='incremental',
        unique_key='product_id',
        on_schema_change='sync_all_columns'
    )
}}

with products as (

    select * from {{ ref('stg_olist__products') }}

),

categories as (

    select * from {{ ref('stg_olist__product_categories') }}

),

orders_with_items as (

    select * from {{ ref('int_orders_with_items') }}
    {% if is_incremental() %}
    -- Only fetch new orders or updated orders since last run
    where purchased_at > (select coalesce(max(last_ordered_at), '2000-01-01'::timestamp) from {{ this }})
    {% endif %}

),

order_items as (

    select * from {{ ref('stg_olist__order_items') }}
    {% if is_incremental() %}
    -- Only include order items for new orders
    where order_id in (select order_id from orders_with_items)
    {% endif %}

),

modified_products as (
    {% if is_incremental() %}
    -- Get products with new orders
    select distinct oi.product_id
    from order_items oi
    {% else %}
    -- For full refresh, include all products
    select distinct product_id
    from {{ ref('stg_olist__products') }}
    {% endif %}
),

product_orders as (

    select
        -- product keys and attributes
        p.product_id,
        p.category_id,
        c.category_name_english,
        c.category_name_portuguese,
        p.name_length,
        p.description_length,
        p.photos_count,
        p.weight_g,
        p.length_cm,
        p.height_cm,
        p.width_cm,
        p.volume_cm3,
        p.is_missing_dimensions,

        -- order counts
        count(distinct oi.order_id) as total_orders,
        count(distinct o.customer_id) as unique_customers,
        count(distinct oi.seller_id) as unique_sellers,

        -- financial metrics
        sum(oi.price_amount) as total_revenue,
        sum(oi.shipping_amount) as total_shipping_revenue,
        sum(oi.total_amount) as total_gmv,
        min(oi.price_amount) as min_price,
        max(oi.price_amount) as max_price,
        stddev(oi.price_amount) as price_variance,
        avg(oi.price_amount) as avg_price,
        avg(oi.shipping_amount) as avg_shipping_fee,

        -- review metrics
        avg(o.review_score) as avg_review_score,
        count(case when o.is_positive_review then 1 end) as positive_reviews,
        count(case when o.is_negative_review then 1 end) as negative_reviews,
        count(case when o.has_review_comment then 1 end) as reviews_with_comments,
        count(case when o.review_score is not null then 1 end) as review_count,

        -- delivery metrics
        avg(o.delivery_time_days) as avg_delivery_time_days,
        avg(o.delivery_variance_days) as avg_delivery_variance_days,
        sum(case when o.is_delivered_on_time then 1 else 0 end) as on_time_deliveries,
        sum(case when not o.is_delivered_on_time then 1 else 0 end) as late_deliveries,

        -- timestamps
        min(o.purchased_at) as first_ordered_at,
        max(o.purchased_at) as last_ordered_at,

        -- calculated fields
        count(distinct date_trunc('month', o.purchased_at)) as active_months,
        date_part('day', now() - min(o.purchased_at)) as days_since_first_order,
        date_part('day', now() - max(o.purchased_at)) as days_since_last_order,
        date_part('day', max(o.purchased_at) - min(o.purchased_at)) as product_lifetime_days,
        sum(oi.order_item_id) as total_items_sold

    from products p
    left join categories c
        on p.category_id = c.category_id
    left join order_items oi
        on p.product_id = oi.product_id
    left join orders_with_items o
        on oi.order_id = o.order_id
    {% if is_incremental() %}
    where p.product_id in (select product_id from modified_products)
    {% endif %}
    group by 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13

),

final as (

    select
        *,
        -- derived metrics
        cast((total_orders::decimal / nullif(active_months, 0)) as numeric(10,2)) as orders_per_month,
        cast((total_gmv::decimal / nullif(active_months, 0)) as numeric(10,2)) as gmv_per_month,
        cast(((positive_reviews::decimal / nullif(total_orders, 0)) * 100) as numeric(10,2)) as positive_review_rate,
        cast(((on_time_deliveries::decimal / nullif(total_orders, 0)) * 100) as numeric(10,2)) as on_time_delivery_rate,
        cast(((review_count::decimal / nullif(total_orders, 0)) * 100) as numeric(10,2)) as review_rate,

        -- Rename total_revenue to gmv for mart compatibility
        total_gmv as gmv,

        -- product segments
        case
            when total_orders >= 50 then 'high_volume'
            when total_orders >= 10 then 'medium_volume'
            else 'low_volume'
        end as volume_segment,

        case
            when avg_price >= 500 then 'premium'
            when avg_price >= 100 then 'mid_range'
            else 'budget'
        end as price_segment,

        case
            when avg_review_score >= 4.5 then 'excellent'
            when avg_review_score >= 4.0 then 'good'
            when avg_review_score >= 3.0 then 'average'
            else 'poor'
        end as rating_segment,

        case
            when weight_g >= 10000 then 'heavy'
            when weight_g >= 2000 then 'medium'
            else 'light'
        end as weight_segment,

        case
            when volume_cm3 >= 50000 then 'large'
            when volume_cm3 >= 10000 then 'medium'
            else 'small'
        end as size_segment

    from product_orders

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