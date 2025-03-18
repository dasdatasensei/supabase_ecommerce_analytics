with source as (

    select * from {{ source('olist', 'products') }}

),

renamed as (

    select
        -- ids
        product_id,
        product_category_name as category_id,

        -- dimensions
        product_weight_g as weight_g,
        product_length_cm as length_cm,
        product_height_cm as height_cm,
        product_width_cm as width_cm,

        -- metadata
        product_name_lenght as name_length,
        product_description_lenght as description_length,
        product_photos_qty as photos_count,

        -- calculated fields
        round(
            (product_length_cm * product_height_cm * product_width_cm)::numeric,
            2
        ) as volume_cm3,

        -- flags
        case
            when product_weight_g is null
                or product_length_cm is null
                or product_height_cm is null
                or product_width_cm is null
            then true
            else false
        end as is_missing_dimensions

    from source

)

select * from renamed

