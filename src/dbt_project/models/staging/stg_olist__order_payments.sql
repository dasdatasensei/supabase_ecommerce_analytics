with source as (

    select * from {{ source('olist', 'order_payments') }}

),

renamed as (

    select
        -- ids
        {{ dbt_utils.generate_surrogate_key(['order_id', 'payment_sequential']) }} as order_payment_sk,
        order_id,
        payment_sequential,

        -- payment details
        payment_type,
        payment_installments,
        payment_value::decimal(10,2) as payment_amount,

        -- calculated fields
        case
            when payment_installments > 1 then true
            else false
        end as is_installment_payment,

        case
            when payment_type = 'credit_card' then true
            else false
        end as is_credit_card,

        case
            when payment_type = 'debit_card' then true
            else false
        end as is_debit_card,

        case
            when payment_type = 'voucher' then true
            else false
        end as is_voucher,

        case
            when payment_type = 'boleto' then true
            else false
        end as is_boleto,

        payment_value::decimal(10,2) / nullif(payment_installments, 0) as installment_amount

    from source

)

select * from renamed