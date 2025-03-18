{{
    config(
        materialized='incremental',
        unique_key='category_name',
        on_schema_change='sync_all_columns',
        post_hook=[
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_category_name_idx ON {{ this }} (category_name)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_total_orders_idx ON {{ this }} (total_orders)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_total_revenue_idx ON {{ this }} (total_revenue)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_total_products_idx ON {{ this }} (total_products)"
        ]
    )
}}

with category_metrics as (

    select
        p.category_name,

        -- product counts
        count(distinct p.product_id) as total_products,

        -- order metrics
        count(distinct o.order_id) as total_orders,
        count(distinct o.customer_id) as unique_customers,

        -- financial metrics
        sum(p.total_revenue) as total_revenue,
        sum(p.total_shipping_revenue) as total_shipping_revenue,
        sum(p.total_gmv) as total_gmv,

        -- review metrics
        avg(p.average_review_score) as average_review_score,
        count(distinct case when p.average_review_score >= 4 then p.product_id end) as highly_rated_products,
        sum(p.total_reviews) as total_reviews,

        -- time metrics
        min(p.first_ordered_at) as first_ordered_at,
        max(p.last_ordered_at) as last_ordered_at

    from {{ ref('products') }} p
    left join {{ ref('int_product_orders') }} o
        on p.product_id = o.product_id
    {% if is_incremental() %}
    -- Only process categories with recent activity
    where p.category_name in (
        select distinct p.category_name
        from {{ ref('products') }} p
        where p.last_ordered_at > (select coalesce(max(last_ordered_at), '2000-01-01'::timestamp) from {{ this }})
    )
    {% endif %}
    group by 1

),

category_stats as (

    select
        *,

        -- calculate per-product metrics
        total_revenue / nullif(total_products, 0) as revenue_per_product,
        total_orders / nullif(total_products, 0) as orders_per_product,

        -- segmentation
        case
            when total_products > 100 then 'large'
            when total_products > 20 then 'medium'
            else 'small'
        end as category_size,

        case
            when total_revenue > 100000 then 'high_revenue'
            when total_revenue > 10000 then 'medium_revenue'
            else 'low_revenue'
        end as revenue_segment,

        case
            when total_orders > 1000 then 'high_volume'
            when total_orders > 100 then 'medium_volume'
            else 'low_volume'
        end as volume_segment,

        case
            when average_review_score >= 4.5 then 'excellent'
            when average_review_score >= 4.0 then 'good'
            when average_review_score >= 3.0 then 'average'
            when average_review_score is null then 'unknown'
            else 'poor'
        end as rating_segment,

        -- recency metrics
        date_part('day', now() - last_ordered_at) as days_since_last_order,

        case
            when date_part('day', now() - last_ordered_at) <= 30 then 'active_30d'
            when date_part('day', now() - last_ordered_at) <= 90 then 'active_90d'
            when date_part('day', now() - last_ordered_at) <= 180 then 'active_180d'
            else 'inactive'
        end as recency_segment

    from category_metrics

)

select * from category_stats