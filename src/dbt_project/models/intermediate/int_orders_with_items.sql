{{
    config(
        materialized='incremental',
        unique_key='order_id',
        on_schema_change='sync_all_columns',
        post_hook=[
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_order_id_idx ON {{ this }} (order_id)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_customer_id_idx ON {{ this }} (customer_id)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_purchased_at_idx ON {{ this }} (purchased_at)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_order_status_idx ON {{ this }} (order_status)",
            "CREATE INDEX IF NOT EXISTS {{ this.name }}_is_delivered_idx ON {{ this }} (is_delivered)"
        ]
    )
}}

with orders as (

    select * from {{ ref('stg_olist__orders') }}
    {% if is_incremental() %}
    -- Only fetch new orders since last run
    where purchased_at > (select coalesce(max(purchased_at), '2000-01-01'::timestamp) from {{ this }})
    {% endif %}

),

order_items as (

    select * from {{ ref('stg_olist__order_items') }}
    {% if is_incremental() %}
    -- Only include order items for new orders
    where order_id in (select order_id from orders)
    {% endif %}

),

order_payments as (

    select * from {{ ref('stg_olist__order_payments') }}
    {% if is_incremental() %}
    -- Only include payments for new orders
    where order_id in (select order_id from orders)
    {% endif %}

),

order_reviews as (

    select * from {{ ref('stg_olist__order_reviews') }}
    {% if is_incremental() %}
    -- Only include reviews for new orders
    where order_id in (select order_id from orders)
    {% endif %}

),

order_financials as (

    select
        order_id,
        sum(payment_amount) as payment_total,
        sum(case when payment_type = 'credit_card' then payment_amount else 0 end) as credit_card_amount,
        sum(case when payment_type = 'boleto' then payment_amount else 0 end) as boleto_amount,
        sum(case when payment_type = 'voucher' then payment_amount else 0 end) as voucher_amount,
        sum(case when payment_type = 'debit_card' then payment_amount else 0 end) as debit_card_amount,
        count(distinct order_payment_sk) as payment_count,
        count(distinct payment_sequential) as payment_installments,
        max(case when payment_type = 'credit_card' then 1 else 0 end) = 1 as used_credit_card,
        max(case when payment_type = 'boleto' then 1 else 0 end) = 1 as used_boleto,
        max(case when payment_type = 'voucher' then 1 else 0 end) = 1 as used_voucher,
        max(case when payment_type = 'debit_card' then 1 else 0 end) = 1 as used_debit_card,
        count(distinct payment_type) as payment_methods_count
    from order_payments
    group by 1

),

order_items_agg as (

    select
        order_id,
        count(distinct order_item_id) as item_count,
        count(distinct product_id) as unique_products,
        count(distinct seller_id) as unique_sellers,
        sum(price_amount) as products_amount,
        sum(shipping_amount) as shipping_amount,
        sum(total_amount) as total_amount,
        min(shipping_limit_at) as first_shipping_limit_date,
        max(shipping_limit_at) as last_shipping_limit_date
    from order_items
    group by 1

),

order_reviews_agg as (

    select
        order_id,
        max(review_score) as review_score,
        max(review_comment_message) is not null as has_review_comment,
        max(case when review_score >= 4 then 1 else 0 end) = 1 as is_positive_review,
        max(case when review_score <= 2 then 1 else 0 end) = 1 as is_negative_review,
        max(created_at) as review_creation_date,
        max(answered_at) as review_answer_timestamp
    from order_reviews
    group by 1

),

final as (

    select
        -- keys
        o.order_id,
        o.customer_id,

        -- timestamps
        o.purchased_at,
        o.approved_at,
        o.estimated_delivery_at,
        o.delivered_at as delivery_date,
        o.shipped_at as last_updated_status_at,
        case
            when o.order_status = 'delivered' and o.delivered_at is not null
            then o.delivered_at - o.purchased_at
        end as actual_delivery_time,
        case
            when o.order_status = 'delivered' and o.delivered_at is not null
            then (o.delivered_at - o.estimated_delivery_at)
        end as delivery_variance,
        date_part('day', case
            when o.order_status = 'delivered' and o.delivered_at is not null
            then o.delivered_at - o.purchased_at
        end) as delivery_time_days,
        date_part('day', case
            when o.order_status = 'delivered' and o.delivered_at is not null
            then (o.delivered_at - o.estimated_delivery_at)
        end) as delivery_variance_days,

        -- item details
        i.item_count,
        i.unique_products,
        i.unique_sellers,
        i.products_amount,
        i.shipping_amount,
        i.total_amount,
        i.first_shipping_limit_date,
        i.last_shipping_limit_date,

        -- payment info
        p.payment_total,
        p.credit_card_amount,
        p.boleto_amount,
        p.voucher_amount,
        p.debit_card_amount,
        p.payment_count,
        p.payment_installments,
        p.used_credit_card,
        p.used_boleto,
        p.used_voucher,
        p.used_debit_card,
        p.payment_methods_count,

        -- review data
        r.review_score,
        r.has_review_comment,
        r.is_positive_review,
        r.is_negative_review,
        r.review_creation_date,
        r.review_answer_timestamp,

        -- status flags
        o.order_status,
        o.is_delivered,
        o.order_status = 'canceled' as is_canceled,
        o.order_status = 'shipped' as is_shipped,
        o.order_status = 'unavailable' as is_unavailable,
        o.order_status = 'invoiced' as is_invoiced,
        o.order_status = 'processing' as is_processing,
        o.order_status = 'created' as is_created,
        o.order_status = 'approved' as is_approved,
        o.is_delivered_on_time

    from orders o
    left join order_items_agg i
        on o.order_id = i.order_id
    left join order_financials p
        on o.order_id = p.order_id
    left join order_reviews_agg r
        on o.order_id = r.order_id

)

select * from final