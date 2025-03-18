with source as (

    select * from {{ source('olist', 'order_items') }}

),

renamed as (

    select
        -- ids
        {{ dbt_utils.generate_surrogate_key(['order_id', 'order_item_id']) }} as order_item_sk,
        order_id,
        order_item_id,
        product_id,
        seller_id,

        -- timestamps
        shipping_limit_date::timestamp as shipping_limit_at,

        -- amounts
        price::decimal(10,2) as price_amount,
        freight_value::decimal(10,2) as shipping_amount,
        (price::decimal(10,2) + freight_value::decimal(10,2)) as total_amount,

        -- calculated fields
        case
            when price::decimal(10,2) = 0 then true
            else false
        end as is_free_item,

        case
            when freight_value::decimal(10,2) = 0 then true
            else false
        end as is_free_shipping

    from source

)

select * from renamed