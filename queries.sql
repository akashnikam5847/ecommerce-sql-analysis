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

-- 96,478 delivered orders generated ~13.22M in item revenue (BRL), average order value ~137.


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

-- health_beauty is the top category (~1.23M), followed by watches_gifts (~1.17M) and bed_bath_table (~1.02M).
-- The top 10 categories bring ~62% of total revenue.
-- bed_bath_table sells the most items (10,953) but at a lower price (~93 per item);
-- watches_gifts sells fewer items (5,859) at a higher price (~199 per item).

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

-- Sao Paulo (SP) alone gives ~38% of revenue (~5.07M); SP + RJ + MG together give ~63%.
-- Unique customers are almost equal to orders in every state (SP: 39,156 vs 40,501),
-- which hints at very few repeat buyers (confirmed in Query 11).


-- Query 4: Payment type distribution

SELECT
    payment_type,
    COUNT(DISTINCT order_id) AS orders,
    ROUND(SUM(payment_value), 2) AS total_value,
    ROUND(100 * SUM(payment_value) / SUM(SUM(payment_value)) OVER (), 2) AS pct_of_total
FROM order_payments
GROUP BY payment_type
ORDER BY total_value DESC;

-- (fill from your result: which payment type has the highest share, e.g. "credit_card is __% of total value")

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

-- Monthly revenue grew ~4x between Jan 2017 (~112K) and Jul 2017 (~482K).
-- Growth % for late 2016 / Jan 2017 looks extreme because the base was tiny (Dec 2016 revenue was only 10.90).
-- November 2016 has no delivered orders.

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

-- (fill from your result: avg actual delivery days vs avg estimated days, and late_pct)

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

-- 9 of the top 10 sellers by revenue are based in SP. The top seller made ~227K from 1,124 orders (avg review 4.13).
-- The one BA seller in the top 10 has only 348 orders but ~218K revenue (~626 per order).
-- The seller with the most orders (1,772) has a lower review score of 3.83.

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

-- On-time orders average 4.29 stars (88,653 reviews) while late orders average only 2.57 (7,700 reviews).
-- Late delivery drops the review score by ~1.7 points, and ~8% of reviewed orders were late.


-- Query 9: Har category ke top 3 products (RANK)

WITH product_rev AS (
    SELECT
        COALESCE(t.product_category_name_english, p.product_category_name, 'unknown') AS category,
        oi.product_id,
        ROUND(SUM(oi.price), 2) AS revenue
    FROM order_items oi
    JOIN orders o ON oi.order_id = o.order_id
    JOIN products p ON oi.product_id = p.product_id
    LEFT JOIN category_translation t ON p.product_category_name = t.product_category_name
    WHERE o.order_status = 'delivered'
    GROUP BY category, oi.product_id
),
ranked AS (
    SELECT *, RANK() OVER (PARTITION BY category ORDER BY revenue DESC) AS rnk
    FROM product_rev
)
SELECT category, product_id, revenue, rnk
FROM ranked
WHERE rnk <= 3
ORDER BY category, rnk;

-- 220 rows returned (top 3 products across ~70+ categories). Revenue is often concentrated in one product,
-- e.g. in "art" the top product earns ~10.6K while the 3rd earns only ~487.

-- Query 10: Running total revenue

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
    ROUND(SUM(revenue) OVER (ORDER BY month), 2) AS running_total
FROM monthly
ORDER BY month;

-- Cumulative revenue crossed ~2.48M by Jul 2017. Nov 2016 is missing because it has no delivered orders.


-- Query 11: Repeat vs one-time customers

WITH cust AS (
    SELECT c.customer_unique_id, COUNT(DISTINCT o.order_id) AS orders
    FROM customers c
    JOIN orders o ON c.customer_id = o.customer_id
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_unique_id
)
SELECT
    CASE WHEN orders = 1 THEN 'One-time' ELSE 'Repeat' END AS customer_type,
    COUNT(*) AS customers,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM cust
GROUP BY customer_type;

-- 97% of customers (90,557 of 93,358) ordered only once; just 3% (2,801) are repeat buyers.
-- Customer acquisition is strong but retention is weak.
