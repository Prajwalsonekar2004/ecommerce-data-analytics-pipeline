SELECT * FROM olist_customers_dataset LIMIT 20;
SELECT * FROM olist_geolocation_dataset LIMIT 20;
SELECT * FROM olist_order_items_dataset LIMIT 20;
SELECT * FROM olist_order_payments_dataset LIMIT 20;
SELECT * FROM olist_order_reviews_dataset LIMIT 20;
SELECT * FROM olist_orders_dataset LIMIT 20;
SELECT * FROM olist_products_dataset LIMIT 20;
SELECT * FROM olist_sellers_dataset LIMIT 20;
SELECT * FROM product_category_name_translation LIMIT 20;

-- Overall Business Performance
-- Q1. What is total revenue and total number of orders?
SELECT ROUND(SUM(olist_order_payments_dataset.payment_value::NUMERIC),2) AS total_revenue, 
COUNT(DISTINCT(olist_orders_dataset.order_id)) AS "total number of orders"
FROM olist_order_payments_dataset
JOIN olist_orders_dataset ON olist_order_payments_dataset.order_id = olist_orders_dataset.order_id
WHERE olist_orders_dataset.order_status = 'delivered';

-- Q2. Monthly revenue trend
SELECT DATE_TRUNC('month', o.order_purchase_timestamp) AS month,
ROUND(SUM(p.payment_value)::NUMERIC, 2) AS monthly_revenue
FROM olist_orders_dataset o
JOIN olist_order_payments_dataset p ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY 1
ORDER BY 1;

-- Customer Analytics
-- Q3. How many repeat vs one-time customers?
WITH customer_orders AS (
SELECT c.customer_unique_id, COUNT(o.order_id) AS total_orders
FROM olist_customers_dataset c
JOIN olist_orders_dataset o ON c.customer_id = o.customer_id
GROUP BY c.customer_unique_id
)

SELECT
CASE 
WHEN total_orders = 1 THEN 'One-time'
ELSE 'Repeat'
END AS customer_type, 
COUNT(*) AS customers
FROM customer_orders 
GROUP BY customer_type;

-- Q4. Top 10 customers by lifetime value
SELECT c.customer_unique_id, ROUND(SUM(p.payment_value::NUMERIC),2) AS "lifetime value"
FROM olist_customers_dataset c
JOIN olist_orders_dataset o ON c.customer_id = o.customer_id
JOIN olist_order_payments_dataset p ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_unique_id
ORDER BY "lifetime value" DESC
LIMIT 10;

-- Q5. Revenue by customer state
SELECT c.customer_state, ROUND(SUM(p.payment_value::NUMERIC),2) AS "Revenue by state"
FROM olist_customers_dataset c
JOIN olist_orders_dataset o ON c.customer_id = o.customer_id
JOIN olist_order_payments_dataset p ON o.order_id = p.order_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY "Revenue by state" DESC
LIMIT 10;

-- Product Analytics
-- Q6. Top 10 product categories by revenue
SELECT n.product_category_name_english, ROUND(SUM(i.price::NUMERIC),2) AS revenue
FROM product_category_name_translation n
JOIN olist_products_dataset o ON n.product_category_name = o.product_category_name
JOIN olist_order_items_dataset i ON o.product_id = i.product_id
JOIN olist_orders_dataset ord ON i.order_id = ord.order_id
WHERE ord.order_status = 'delivered'
GROUP BY n.product_category_name_english
ORDER BY revenue DESC
LIMIT 10;

-- Q7. Products with highest average price
SELECT n.product_category_name_english, ROUND(AVG(i.price::NUMERIC),2) AS avg_product_price
FROM product_category_name_translation n
JOIN olist_products_dataset p ON n.product_category_name = p.product_category_name
JOIN olist_order_items_dataset i ON p.product_id = i.product_id
JOIN olist_orders_dataset ord ON i.order_id = ord.order_id
WHERE ord.order_status = 'delivered'
GROUP BY n.product_category_name_english
ORDER BY avg_product_price DESC
LIMIT 10;

-- Seller Performance
-- Q8. Top 10 sellers by revenue
SELECT s.seller_id, ROUND(SUM(i.price::NUMERIC + freight_value::NUMERIC),2) AS revenue_by_sellers
FROM olist_sellers_dataset s
JOIN olist_order_items_dataset i ON s.seller_id = i.seller_id
JOIN olist_orders_dataset ord ON i.order_id = ord.order_id
WHERE ord.order_status = 'delivered'
GROUP BY s.seller_id
ORDER BY revenue_by_sellers DESC
LIMIT 10;

-- Q9. Seller delivery performance (average delivery time)
WITH seller_orders AS (
SELECT DISTINCT i.seller_id, ord.order_id, ord.order_purchase_timestamp, ord.order_delivered_customer_date
FROM olist_order_items_dataset i
JOIN olist_orders_dataset ord ON i.order_id = ord.order_id
WHERE ord.order_status = 'delivered' AND ord.order_delivered_customer_date IS NOT NULL
)

SELECT seller_id, ROUND(AVG(EXTRACT(EPOCH FROM(order_delivered_customer_date - order_purchase_timestamp) / 86400)),2) AS average_delivery_days 
FROM seller_orders
GROUP BY seller_id
ORDER BY average_delivery_days
LIMIT 10;

-- Payment Analytics
-- Q10. Revenue by payment type
SELECT p.payment_type, ROUND(SUM(p.payment_value::NUMERIC),2) AS "Revenue by payment type",
ROUND(100.0 * SUM(p.payment_value::NUMERIC) / SUM(SUM(p.payment_value::NUMERIC))OVER(),2) AS revenue_percent
FROM olist_order_payments_dataset p
JOIN olist_orders_dataset ord ON p.order_id = ord.order_id
WHERE ord.order_status = 'delivered'
GROUP BY p.payment_type
ORDER BY "Revenue by payment type" DESC;
 
-- Q11. Average payment installments by payment type
SELECT p.payment_type, ROUND(AVG(p.payment_installments::NUMERIC),2) AS "Average payment installments"
FROM olist_order_payments_dataset p
JOIN olist_orders_dataset ord ON p.order_id = ord.order_id
WHERE ord.order_status = 'delivered'
GROUP BY p.payment_type
ORDER BY "Average payment installments" DESC;

-- Delivery & Logistics
-- Q12. Late delivery rate by month
SELECT DATE_TRUNC('month', order_purchase_timestamp) AS month, COUNT(*) AS total_orders, COUNT(*) FILTER (
WHERE order_delivered_customer_date > order_estimated_delivery_date) AS late_orders,
ROUND(100.0 * COUNT(*) FILTER (
WHERE order_delivered_customer_date > order_estimated_delivery_date) / NULLIF(COUNT(*), 0),2) AS late_delivery_rate
FROM olist_orders_dataset
WHERE order_status = 'delivered'
GROUP BY month
ORDER BY month;

-- Reviews & Customer Satisfaction
-- Q13. Average review score by product category
SELECT n.product_category_name_english, ROUND(AVG(r.review_score),2) AS "Average review score",
COUNT(DISTINCT r.review_id) AS total_reviews
FROM product_category_name_translation n
JOIN olist_products_dataset p ON n.product_category_name = p.product_category_name
JOIN olist_order_items_dataset i ON p.product_id = i.product_id
JOIN olist_order_reviews_dataset r ON i.order_id = r.order_id
JOIN olist_orders_dataset ord ON r.order_id = ord.order_id
WHERE ord.order_status = 'delivered'
GROUP BY n.product_category_name_english
HAVING COUNT(DISTINCT r.review_id) >= 50
ORDER BY "Average review score" DESC;

-- Q15. Does faster delivery improve ratings?
SELECT CASE 
WHEN ord.order_delivered_customer_date <= ord.order_estimated_delivery_date 
THEN 'On Time' ELSE 'Late' END AS delivery_status, ROUND(AVG(r.review_score),2) AS avg_review,
COUNT(*) AS total_orders
FROM olist_orders_dataset ord 
JOIN olist_order_reviews_dataset r ON ord.order_id = r.order_id
WHERE ord.order_status = 'delivered'
AND ord.order_delivered_customer_date IS NOT NULL
AND ord.order_estimated_delivery_date IS NOT NULL
GROUP BY delivery_status
ORDER BY avg_review DESC;
