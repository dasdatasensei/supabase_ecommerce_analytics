{{
    config(
        materialized='incremental',
        unique_key='order_id',
        on_schema_change='sync_all_columns',
        post_hook=[
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_order_id_idx ON {{ this }} (order_id)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_customer_id_idx ON {{ this }} (customer_id)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_seller_id_idx ON {{ this }} (seller_id)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_purchased_at_idx ON {{ this }} (purchased_at)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_order_status_idx ON {{ this }} (order_status)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_delivery_time_days_idx ON {{ this }} (delivery_time_days)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_review_score_idx ON {{ this }} (review_score)"
        ]
    )
}}

select * from {{ ref('int_orders_with_items') }}

{% if is_incremental() %}
-- Only process new orders
where purchased_at > (select coalesce(max(purchased_at), '2000-01-01'::timestamp) from {{ this }})
{% endif %}