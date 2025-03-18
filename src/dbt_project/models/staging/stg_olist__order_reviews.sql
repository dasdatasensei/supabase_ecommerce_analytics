with source as (

    select * from {{ source('olist', 'order_reviews') }}

),

renamed as (

    select
        -- ids
        review_id,
        order_id,

        -- review details
        review_score,
        review_comment_title,
        review_comment_message,
        review_creation_date::timestamp as created_at,
        review_answer_timestamp::timestamp as answered_at,

        -- calculated fields
        case
            when review_score >= 4 then true
            else false
        end as is_positive_review,

        case
            when review_score <= 2 then true
            else false
        end as is_negative_review,

        case
            when review_comment_message is not null
                and trim(review_comment_message) != '' then true
            else false
        end as has_review_comment,

        extract(epoch from (review_answer_timestamp::timestamp - review_creation_date::timestamp))/3600.0 as response_time_hours

    from source

)

select * from renamed