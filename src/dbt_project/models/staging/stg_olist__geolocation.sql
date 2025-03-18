with source as (

    select * from {{ source('olist', 'geolocation') }}

),

renamed as (

    select
        -- ids
        geolocation_zip_code_prefix as zip_code_prefix,

        -- location attributes
        geolocation_lat as latitude,
        geolocation_lng as longitude,
        geolocation_city as city,
        geolocation_state as state,

        -- add standardized city and state names
        initcap(geolocation_city) as city_normalized,
        upper(geolocation_state) as state_normalized

    from source

),

deduplicated as (
    -- Some zip codes have multiple lat/long entries
    -- Taking the first occurrence for each zip code
    select distinct on (zip_code_prefix)
        *
    from renamed
    order by
        zip_code_prefix,
        latitude,
        longitude
)

select * from deduplicated