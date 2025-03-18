with source as (

    select * from {{ source('olist', 'sellers') }}

),

renamed as (

    select
        -- ids
        seller_id,
        seller_zip_code_prefix as zip_code_prefix,

        -- location attributes
        seller_city as city,
        seller_state as state,

        -- standardized location fields
        initcap(seller_city) as city_normalized,
        upper(seller_state) as state_normalized

    from source

)

select
    *,
    -- add location reference
    {{ dbt_utils.generate_surrogate_key(
        ['zip_code_prefix', 'city_normalized', 'state_normalized']
    ) }} as location_id

from renamed