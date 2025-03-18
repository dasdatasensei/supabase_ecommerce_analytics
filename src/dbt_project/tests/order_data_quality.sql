-- This test ensures that order dates are logical and consistent
-- It checks that order_purchase_timestamp is always before order_delivered_customer_date
-- and that order_approved_at is always after order_purchase_timestamp

SELECT
    order_id,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_customer_date
FROM {{ ref('stg_olist__orders') }}
WHERE
    -- Test for orders that have delivery dates before purchase (illogical)
    (order_delivered_customer_date IS NOT NULL AND order_purchase_timestamp > order_delivered_customer_date)

    -- Test for orders that have approval dates before purchase (illogical)
    OR (order_approved_at IS NOT NULL AND order_purchase_timestamp > order_approved_at)

    -- Test for future order dates (beyond current date)
    OR order_purchase_timestamp > CURRENT_DATE