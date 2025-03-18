with source as (

    select * from {{ source('olist', 'orders') }}

),

renamed as (

    select
        -- ids
        order_id,
        customer_id,

        -- status
        order_status,

        -- dates
        order_purchase_timestamp::timestamp as purchased_at,
        order_approved_at::timestamp as approved_at,
        order_delivered_carrier_date::timestamp as shipped_at,
        order_delivered_customer_date::timestamp as delivered_at,
        order_estimated_delivery_date::timestamp as estimated_delivery_at,

        -- calculated fields
        extract(epoch from (order_delivered_customer_date::timestamp - order_purchase_timestamp::timestamp))/86400.0 as delivery_time_days,
        extract(epoch from (order_estimated_delivery_date::timestamp - order_delivered_customer_date::timestamp))/86400.0 as delivery_variance_days,

        -- flags
        case
            when order_delivered_customer_date is not null
                and order_delivered_customer_date <= order_estimated_delivery_date
            then true
            else false
        end as is_delivered_on_time,

        case
            when order_delivered_customer_date is not null then true
            else false
        end as is_delivered

    from source

)

select * from renamed