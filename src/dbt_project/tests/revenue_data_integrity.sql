-- This test ensures that revenue data is consistent
-- It verifies that the sum of order items price matches the order total price
-- and checks for any negative prices which would be invalid

WITH order_totals AS (
    SELECT
        order_id,
        SUM(price) AS calculated_total_price
    FROM {{ ref('stg_olist__order_items') }}
    GROUP BY order_id
),

payment_totals AS (
    SELECT
        order_id,
        SUM(payment_value) AS payment_total
    FROM {{ ref('stg_olist__order_payments') }}
    GROUP BY order_id
)

SELECT
    ot.order_id,
    ot.calculated_total_price,
    pt.payment_total,
    -- Discrepancy amount (allow for small rounding differences)
    ABS(ot.calculated_total_price - pt.payment_total) AS discrepancy
FROM order_totals ot
JOIN payment_totals pt ON ot.order_id = pt.order_id
WHERE
    -- Check for discrepancies greater than 1 unit of currency
    ABS(ot.calculated_total_price - pt.payment_total) > 1.0

    -- Also fail if there are any negative values
    OR ot.calculated_total_price < 0
    OR pt.payment_total < 0