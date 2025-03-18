with source as (

    select * from {{ source('olist', 'customers') }}

),

renamed as (

    select
        -- ids
        customer_id,
        customer_unique_id,
        customer_zip_code_prefix as zip_code_prefix,

        -- location attributes
        customer_city as city,
        customer_state as state,

        -- standardized location fields
        initcap(customer_city) as city_normalized,
        upper(customer_state) as state_normalized

    from source

)

select
    *,
    -- add location reference
    {{ dbt_utils.generate_surrogate_key(
        ['zip_code_prefix', 'city_normalized', 'state_normalized']
    ) }} as location_id

from renamed