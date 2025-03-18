-- depends_on: {{ ref('int_orders_with_items') }}
{{
    config(
        materialized='incremental',
        unique_key='product_id',
        on_schema_change='sync_all_columns',
        post_hook=[
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_product_id_idx ON {{ this }} (product_id)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_category_name_idx ON {{ this }} (category_name)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_total_orders_idx ON {{ this }} (total_orders)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_last_ordered_at_idx ON {{ this }} (last_ordered_at)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_avg_review_score_idx ON {{ this }} (average_review_score)"
        ]
    )
}}

with product_performance as (

    select * from {{ ref('int_product_performance') }}
    {% if is_incremental() %}
    -- Only process products with recent activity
    where product_id in (
        select distinct oi.product_id
        from {{ ref('stg_olist__order_items') }} oi
        inner join {{ ref('stg_olist__orders') }} o
            on oi.order_id = o.order_id
        where o.purchased_at > (select coalesce(max(last_ordered_at), '2000-01-01'::timestamp) from {{ this }})
    )
    {% endif %}

)

select * from product_performance