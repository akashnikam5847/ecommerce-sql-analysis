-- Queries-- 

-- Query 1: Total orders, revenue, average order value

USE olist_ecommerce;

SELECT
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(SUM(oi.price) / COUNT(DISTINCT o.order_id), 2) AS avg_order_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered';

-- Query 2: Top 10 product categories by revenue

SELECT
    COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
    COUNT(*) AS items_sold,
    ROUND(SUM(oi.price), 2) AS revenue
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN category_translation t ON p.product_category_name = t.product_category_name
WHERE o.order_status = 'delivered'
GROUP BY category
ORDER BY revenue DESC
LIMIT 10;

-- Query 3: State-wise customers aur revenue

SELECT
    c.customer_state,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
    COUNT(DISTINCT o.order_id) AS orders,
    ROUND(SUM(oi.price), 2) AS revenue
FROM customers c
JOIN orders o ON c.customer_id = o.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY revenue DESC;

-- Query 4: Payment type distribution

SELECT
    payment_type,
    COUNT(DISTINCT order_id) AS orders,
    ROUND(SUM(payment_value), 2) AS total_value,
    ROUND(100 * SUM(payment_value) / SUM(SUM(payment_value)) OVER (), 2) AS pct_of_total
FROM order_payments
GROUP BY payment_type
ORDER BY total_value DESC;

-- Query 5: Monthly revenue aur MoM growth

WITH monthly AS (
    SELECT
        DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS month,
        ROUND(SUM(oi.price), 2) AS revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY month
)
SELECT
    month,
    revenue,
    LAG(revenue) OVER (ORDER BY month) AS prev_month_revenue,
    ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY month))
          / LAG(revenue) OVER (ORDER BY month), 2) AS mom_growth_pct
FROM monthly
ORDER BY month;

-- Query 6: Actual vs estimated delivery time, late %

SELECT
    COUNT(*) AS delivered_orders,
    ROUND(AVG(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)), 1) AS avg_actual_days,
    ROUND(AVG(DATEDIFF(order_estimated_delivery_date, order_purchase_timestamp)), 1) AS avg_estimated_days,
    SUM(order_delivered_customer_date > order_estimated_delivery_date) AS late_orders,
    ROUND(100 * SUM(order_delivered_customer_date > order_estimated_delivery_date) / COUNT(*), 2) AS late_pct
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;

  -- Query 7: Top 10 sellers, revenue aur average review

 WITH seller_revenue AS (
    SELECT oi.seller_id,
           COUNT(DISTINCT oi.order_id) AS orders,
           ROUND(SUM(oi.price), 2) AS revenue
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
    GROUP BY oi.seller_id
),
seller_reviews AS (
    SELECT x.seller_id, ROUND(AVG(r.review_score), 2) AS avg_review
    FROM (SELECT DISTINCT order_id, seller_id FROM order_items) x
    JOIN order_reviews r ON x.order_id = r.order_id
    GROUP BY x.seller_id
)
SELECT sr.seller_id, s.seller_state, sr.orders, sr.revenue, rv.avg_review
FROM seller_revenue sr
JOIN sellers s ON sr.seller_id = s.seller_id
JOIN seller_reviews rv ON sr.seller_id = rv.seller_id
ORDER BY sr.revenue DESC
LIMIT 10;

-- Query 8: Delivery delay vs review score

SELECT
    CASE
        WHEN o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN 'On time'
        ELSE 'Late'
    END AS delivery_status,
    COUNT(*) AS reviews,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM orders o
JOIN order_reviews r ON o.order_id = r.order_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY delivery_status;