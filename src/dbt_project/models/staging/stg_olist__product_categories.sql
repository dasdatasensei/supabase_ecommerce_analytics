with source as (

    select * from {{ source('olist', 'product_categories') }}

),

renamed as (

    select
        -- ids
        product_category_name as category_id,

        -- attributes
        product_category_name_english as category_name_english,
        product_category_name as category_name_portuguese

    from source

)

select * from renamed