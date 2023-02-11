-- Show history of a staff - according to staff's usernames
CREATE OR REPLACE FUNCTION staff_history(input_username VARCHAR)
RETURNS TABLE (
   username VARCHAR,
   name text,
   order_id INT,
   order_date TIMESTAMP,
   total_amount NUMERIC
) 
AS $$
BEGIN
   RETURN QUERY SELECT 
            s.username, 
            s.first_name||' '||s.last_name AS name, 
            o.order_id, 
            o.order_date,
            o.total_amount
   FROM staffs s, orders o
   WHERE o.staff_id = s.username
   AND s.username = input_username;
END; $$
LANGUAGE plpgsql;

DROP FUNCTION date_history;

-- view to simplify query related to staffs, customers, orders
-- CREATE VIEW order_product_relation AS
-- SELECT *
-- FROM customers c, orders o, orderlines ol
-- WHERE o.customer_id = c.phone AND o.order_id = ol.order_id;

-- Show history between a period of time
CREATE OR REPLACE FUNCTION date_history(day1 DATE, day2 DATE)
RETURNS TABLE(
   username VARCHAR,
   staff_name text,
   order_id INT,
   order_date TIMESTAMP,
   total_amount NUMERIC,
   cus_name text,
   cus_phone CHAR(10)
)
AS $$
BEGIN
   RETURN QUERY SELECT 
            s.username, 
            s.first_name||' '||s.last_name AS staff_name, 
            o.order_id, 
            o.order_date,
            o.total_amount,
            c.first_name||' '||c.last_name AS cus_name, 
            c.phone
   FROM staffs s, orders o, customers c
   WHERE o.staff_id = s.username
   AND o.customer_id = c.phone
   AND o.order_date >= day1
   And o.order_date <= day2;
END; $$
LANGUAGE plpgsql;

SELECT * FROM date_history('2021-12-08', '2021-12-30');
-- SHOW history of a customers - according to customers' phone

CREATE OR REPLACE FUNCTION cus_history(input_cus_phone CHAR(10))
RETURNS TABLE (
   cus_name text,
   cus_phone CHAR(10),
   order_id INT,
   order_date TIMESTAMP,
   total_amount NUMERIC,
   staff_name text
) 
AS $$
BEGIN
   RETURN QUERY SELECT 
            c.first_name||' '||c.last_name AS cus_name,
            c.phone,
            o.order_id, 
            o.order_date,
            o.total_amount,
            s.first_name||' '||s.last_name AS staff_name
   FROM staffs s, orders o, customers c
   WHERE o.staff_id = s.username
   AND o.customer_id = c.phone
   AND c.phone = input_cus_phone;
END; $$
LANGUAGE plpgsql;

SELECT * FROM cus_history('6092114493');

-- QUERY Changes in Price of a product (Query by pattern of product_id)
DROP FUNCTION price_change;

CREATE OR REPLACE FUNCTION price_change(name text)
RETURNS TABLE(
   product_id VARCHAR,
   product_name VARCHAR,
   date_change TIMESTAMP,
   new_price NUMERIC
)
AS $$
DECLARE
      parttern text := name;
BEGIN 
   RETURN QUERY 
   SELECT p.product_id, p.name, h.date_in, h.new_price
   FROM products p, price_history h
   WHERE p.product_id = h.product_id
   AND p.product_id LIKE '%'||parttern||'%'; 
END; $$
LANGUAGE plpgsql;

SELECT p.product_id, p.name, h.date_in, h.new_price
FROM products p, price_history h
WHERE p.product_id = h.product_id;

--Staff find product of the same category (Search by category name)

CREATE OR REPLACE FUNCTION find_category(category text)
RETURNS TABLE(
   product_id VARCHAR,
   product_name VARCHAR,
   quantity_available INT,
   category_name VARCHAR
) AS $$
DECLARE
   category_name text := category;
BEGIN
   RETURN QUERY SELECT p.product_id, p.name, p.quan_in_stock, c.name
   FROM products p, category c
   WHERE p.category_id = c.category_id
   AND c.name LIKE '%'||category_name||'%';
END; $$
LANGUAGE plpgsql;

--Query the money coming in and out through a period of time
DROP FUNCTION money_flow;
CREATE OR REPLACE FUNCTION money_flow(day1 DATE, day2 DATE)
RETURNS TABLE(
      product_id VARCHAR,
      date TIMESTAMP,
      type text,
      amount NUMERIC
)
AS $$
BEGIN
   RETURN QUERY
   SELECT * FROM
   ( 
         SELECT 
            ph.product_id, 
            ph.date_in as date, 
            'OUT' as type, 
            ph.entry_price * ph.quantity as amount
         FROM product_history ph
         WHERE ph.date_in > day1
         AND ph.date_in < day2
      UNION
         SELECT
            ol.product_id,
            o.order_date as date,
            'IN' as type,
            ol.total_amount as amount
         FROM orderlines ol, orders o
         WHERE ol.order_id = o.order_id
         AND o.order_date >day1
         AND o.order_date <day2
   ) AS table1
   ORDER BY date;
END; $$
LANGUAGE plpgsql;

SELECT * FROM money_flow('2020-12-6', '2022-12-12');

-- Query the sum of money coming in and out in a period of time
DROP FUNCTION sum_money;
CREATE OR REPLACE FUNCTION sum_money(day1 DATE, day2 DATE)
RETURNS TABLE(
   money_out NUMERIC,
   money_in NUMERIC
) 
AS $$
BEGIN 
   RETURN QUERY 
      WITH T1 AS (
         SELECT COALESCE(SUM(ph.entry_price * ph.quantity), 0) AS money_out 
         FROM product_history ph
         WHERE ph.date_in >= day1
         AND ph.date_in <= day2
), T2 AS (
         SELECT COALESCE(CAST(SUM(ol.total_amount) as NUMERIC), 0) as money_in
         FROM orderlines ol, orders o
         WHERE ol.order_id = o.order_id
         AND o.order_date >= day1
         AND o.order_date <= day2
)
SELECT * FROM T1 CROSS JOIN T2;
END; $$
LANGUAGE plpgsql;

-- view for staff can see information of other employees in the store
CREATE VIEW staff_public AS
SELECT permissions, first_name, last_name, DoB, gender, phone, email, address, working_status
FROM staffs;

SELECT * FROM staff_public;

select * from staffs;
