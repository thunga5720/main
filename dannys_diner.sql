CREATE TABLE sales (
  customer_id VARCHAR(1),
  order_date DATE,
  product_id INTEGER
);
INSERT INTO sales
  (customer_id, order_date, product_id)
VALUES
  ('A', '2021-01-01', '1'),
  ('A', '2021-01-01', '2'),
  ('A', '2021-01-07', '2'),
  ('A', '2021-01-10', '3'),
  ('A', '2021-01-11', '3'),
  ('A', '2021-01-11', '3'),
  ('B', '2021-01-01', '2'),
  ('B', '2021-01-02', '2'),
  ('B', '2021-01-04', '1'),
  ('B', '2021-01-11', '1'),
  ('B', '2021-01-16', '3'),
  ('B', '2021-02-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-01', '3'),
  ('C', '2021-01-07', '3');
CREATE TABLE menu (
  product_id INTEGER,
  product_name VARCHAR(5),
  price INTEGER
);
INSERT INTO menu
  (product_id, product_name, price)
VALUES
  ('1', 'sushi', '10'),
  ('2', 'curry', '15'),
  ('3', 'ramen', '12');
CREATE TABLE members (
  customer_id VARCHAR(1),
  join_date DATE
);
INSERT INTO members
  (customer_id, join_date)
VALUES
  ('A', '2021-01-07'),
  ('B', '2021-01-09');
-- Bonus 1: Join all the things
SELECT s.customer_id, s.order_date, mn.product_name, mn.price,
	CASE 
		WHEN s.order_date >= mb.join_date THEN 'Y'
        ELSE 'N'
        END AS member
	FROM sales s
		LEFT JOIN menu mn ON s.product_id = mn.product_id
		LEFT JOIN members mb ON s.customer_id = mb.customer_id
    ORDER BY customer_id, order_date;
-- Bonus 2: Rank all the things
WITH joined_table AS (
	SELECT s.customer_id, s.order_date, mn.product_name, mn.price,
	CASE 
		WHEN s.order_date >= mb.join_date THEN 'Y'
        ELSE 'N'
        END AS member
	FROM sales s
		LEFT JOIN menu mn ON s.product_id = mn.product_id
		LEFT JOIN members mb ON s.customer_id = mb.customer_id
    ORDER BY customer_id, order_date
		)
SELECT * ,
CASE 
	WHEN member = 'Y' THEN RANK () OVER (PARTITION BY customer_id, member
                                      ORDER BY order_date ASC) 
	ELSE 'NULL' END AS ranking
FROM joined_table;
-- 1.What is the total amount each customer spent at the restaurant?
SELECT customer_id, sum(price)
	FROM sales
    JOIN menu ON sales.product_id = menu.product_id
GROUP BY customer_id;
-- 2.How many days has each customer visited the restaurant?
SELECT customer_id, count(order_date)
	FROM sales
GROUP BY customer_id;
-- 3.What was the first item from the menu purchased by each customer?
SELECT customer_id, product_name 
	FROM sales
    JOIN menu ON sales.product_id = menu.product_id
    WHERE order_date IN (SELECT MIN(order_date)
							FROM sales
                            GROUP BY customer_id)
ORDER BY customer_id;
-- 4.What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT product_id, count(product_id)
	FROM sales
GROUP BY product_id
ORDER BY count(product_id) DESC;
-- The most purchased item on the menu has the product_id = 3
-- How many times was it purchased by all curtomers?
SELECT customer_id, count(product_id)
	FROM sales
    WHERE product_id = 3
GROUP BY customer_id;
-- 5.Which item was the most popular for each customer?
WITH ranking_table AS
(WITH joined_table AS  
(SELECT customer_id, s.product_id, m.product_name, count(s.product_id) AS order_time  
	FROM sales s     
	LEFT JOIN menu m ON s.product_id = m.product_id 
    GROUP BY customer_id, s.product_id) 
SELECT *,  
	RANK() OVER (PARTITION BY customer_id ORDER BY order_time DESC) AS ranking 
FROM joined_table)
SELECT customer_id, product_id, product_name 
FROM ranking_table
WHERE ranking = 1;
-- 6.Which item was purchased first by the customer after they became a member?
WITH ranking_table AS 
(WITH joined_table AS (
	SELECT s.customer_id, s.order_date, mn.product_name, mn.price,
	CASE 
		WHEN s.order_date >= mb.join_date THEN 'Y'
        ELSE 'N'
        END AS member
	FROM sales s
		LEFT JOIN menu mn ON s.product_id = mn.product_id
		LEFT JOIN members mb ON s.customer_id = mb.customer_id
    ORDER BY customer_id, order_date
		)
SELECT * ,
CASE 
	WHEN member = 'Y' THEN RANK () OVER (PARTITION BY customer_id, member
                                      ORDER BY order_date ASC) 
	ELSE 'NULL' END AS ranking
FROM joined_table)
SELECT customer_id, product_name
FROM ranking_table
WHERE ranking = 1;
-- 7.Which item was purchased just before the customer became a member?
WITH ranking_table AS
(WITH joined_table AS
(SELECT s.customer_id, s.product_id, product_name, order_date, join_date,
CASE	
	WHEN order_date >= join_date THEN 'Y'
    ELSE 'N' END AS member
	FROM sales s
    LEFT JOIN menu mn ON s.product_id = mn.product_id
    LEFT JOIN members mb ON s.customer_id = mb.customer_id)
SELECT *,
CASE
	WHEN member = 'N' THEN RANK() OVER(PARTITION BY customer_id, member
                                       ORDER BY order_date DESC)
	ELSE 'NULL' END AS ranking
FROM joined_table)
SELECT customer_id, product_id, product_name
FROM ranking_table 
WHERE join_date IS NOT NULL AND ranking = 1;
-- 8.What is the total items and amount spent for each member before they became a member?
WITH joined_table AS 
(SELECT s.customer_id, s.product_id, product_name, price, order_date, join_date,
CASE	
	WHEN order_date >= join_date THEN 'Y'
    ELSE 'N' END AS member
	FROM sales s
    LEFT JOIN menu mn ON s.product_id = mn.product_id
    LEFT JOIN members mb ON s.customer_id = mb.customer_id)
SELECT customer_id, COUNT(product_id), SUM(price)
FROM joined_table
WHERE member = 'N' AND join_date IS NOT NULL
GROUP BY customer_id;
-- 9.If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
WITH points_table AS
(SELECT s.customer_id, s.product_id, product_name, price, 
CASE  
	WHEN product_name = 'sushi' THEN price*20     
    ELSE price*10 END AS points  
    FROM sales s  
    LEFT JOIN menu m ON s.product_id = m.product_id) 
SELECT customer_id, SUM(points)
FROM points_table
GROUP BY customer_id;
-- 10.In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
WITH first_week_table AS 
(WITH joined_table AS
(SELECT s.customer_id, s.product_id, product_name, price, order_date, join_date,
CASE
	WHEN product_name = 'sushi' THEN price*20
    ELSE price*10 END AS points
FROM sales s
LEFT JOIN menu mn ON s.product_id = mn.product_id
LEFT JOIN members mb ON s.customer_id = mb.customer_id)
SELECT *,
CASE 
	WHEN order_date BETWEEN order_date AND ADDDATE(order_date, INTERVAL 6 DAY) THEN price*20
    ELSE points END AS first_week
FROM joined_table)
SELECT customer_id, SUM(first_week)
FROM first_week_table
WHERE order_date >= join_date AND join_date IS NOT NULL AND MONTH(order_date) = 01
GROUP BY customer_id;