
-- TRIGGER 
--DROP trigger if exists update_point_and_rank on orders;
DROP trigger if exists check_out on orderlines;
DROP trigger if exists tg_import on product_history;
DROP trigger if exists change_price on products;
DROP trigger if exists cal_sum_orderlines on orderlines;
DROP TRIGGER check_quan_order ON orderlines;
DROP FUNCTION fn_check_quan_order;

-- func and trigger to insert new row into price_history when updating sale_price of product
CREATE OR REPLACE FUNCTION fn_change_price() 
RETURNS trigger 
AS $$
BEGIN
	INSERT INTO price_history 
	VALUES (new.product_id, current_date, old.sale_price, new.sale_price);
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
	
CREATE TRIGGER change_price
AFTER UPDATE ON products
FOR EACH ROW
WHEN (new.sale_price <> old.sale_price)
EXECUTE PROCEDURE fn_change_price();
-- SELECT * FROM products;
-- UPDATE products
-- SET sale_price = 13.99
-- WHERE product_id like 'RJB-%';
-- select * from products;
-- select * from price_history;


-- function to update discount_id for all item of store

CREATE OR REPLACE FUNCTION update_discount_id(in did int)
RETURNS void AS $$
BEGIN 
	UPDATE products
	SET discount_id = did
	WHERE current_date > (SELECT end_date FROM discount WHERE discount_id = products.discount_id) 
		OR (products.discount_id is NULL);
END;
$$ LANGUAGE plpgsql;
-- select update_discount_id(2);

-- function to update discount_id for certain category_id

CREATE OR REPLACE FUNCTION update_did_by_cate(in did int, in cate_id int)
RETURNS void AS $$
BEGIN 
	UPDATE products
	SET discount_id = did
	WHERE category_id = cate_id 
		AND ((current_date > (SELECT end_date FROM discount WHERE discount_id = products.discount_id)) OR (products.discount_id is NULL));
END;
$$ LANGUAGE plpgsql;
--select update_did_by_cate (10, 1);
-- select update_discount_id (2, 20);
-- select * from products, discount
-- where products.discount_id = discount.discount_id;

-- function and trigger to update quantity of product when import product 
CREATE OR REPLACE FUNCTION fn_import() 
RETURNS trigger 
AS $$
BEGIN
	UPDATE products
	SET quan_in_stock = quan_in_stock + new.quantity
	WHERE product_id = new.product_id;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
	
CREATE TRIGGER tg_import
AFTER INSERT ON product_history
FOR EACH ROW
EXECUTE PROCEDURE fn_import();


-- function and trigger to update quantity of product when checking-out
CREATE OR REPLACE FUNCTION fn_check_out() 
RETURNS trigger 
AS $$
BEGIN
	UPDATE products
	SET quan_in_stock = quan_in_stock - new.quantity
	WHERE product_id = new.product_id;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;
	
CREATE TRIGGER check_out
AFTER INSERT ON orderlines
FOR EACH ROW
EXECUTE PROCEDURE fn_check_out();


-- func and trigger to check quantity of orderline

CREATE OR REPLACE FUNCTION fn_check_quan_order()
  RETURNS TRIGGER AS $$
 DECLARE quan_stock int;
BEGIN
  quan_stock = (SELECT quan_in_stock FROM products WHERE product_id = new.product_id);
  IF NEW.quantity > quan_stock
  THEN
    RAISE EXCEPTION 'Product [id:%] is not enough to order!', NEW.product_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_quan_order
BEFORE INSERT OR UPDATE ON orderlines 
FOR EACH ROW EXECUTE PROCEDURE fn_check_quan_order();

-- function and trigger to calculate total_amount for each orderlines
CREATE OR REPLACE FUNCTION fn_cal_sum_orderlines()
RETURNS trigger 
AS $$
DECLARE total decimal :=0; discount_per decimal := 0; p_price decimal := 0; mtype varchar; discount_by_rank decimal := 0; cid varchar;
BEGIN
	cid = (SELECT customer_id FROM orders WHERE order_id = new.order_id);
	discount_per = (SELECT discount_percent 
					FROM discount, products 
					WHERE products.product_id = new.product_id AND products.discount_id = discount.discount_id);
	p_price = (SELECT sale_price FROM products WHERE product_id = new.product_id);
	total = p_price * new.quantity;
	-- update total_amount and discount of orderlines
	UPDATE orderlines
	SET total_amount = total * (100 - discount_per) / 100,
		discount = discount_per
	WHERE product_id = new.product_id;
	-- orders
	mtype = (SELECT member_type FROM customers WHERE phone = cid);
	IF (mtype = 'diamond') THEN discount_by_rank = 10;
	ELSIF (mtype = 'gold') THEN discount_by_rank = 7;
	ELSIF (mtype = 'silver') THEN discount_by_rank = 5;
	END IF;
	-- may occur conflict if rank is updated before finish insert enough orderlines for each order???
	-- update total_amount, discount, and point of order
	UPDATE orders
	SET total_amount = total_amount + (total * (100 - discount_per) / 100)*(100-discount_by_rank)/100,
		discount = discount_by_rank,
		point = point + (total * (100 - discount_per) / 100)*(100-discount_by_rank)/100*0.05
	WHERE order_id = new.order_id;
	-- update point of customer
	UPDATE customers 
	SET point = point + (total * (100 - discount_per) / 100)*(100-discount_by_rank)/100*0.05 -- tich diem = 5% gia tri don hang
	WHERE phone = cid;
	-- update rank of customer
	UPDATE customers SET member_type = 'diamond' WHERE phone = cid AND point >= 5000; -- update rank
	UPDATE customers SET member_type = 'gold' WHERE phone = cid AND point >= 1000 AND point < 5000;
	UPDATE customers SET member_type = 'silver' WHERE phone = cid AND point >= 100 AND point < 1000;
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER cal_sum_orderlines
AFTER INSERT ON orderlines
FOR EACH ROW
EXECUTE PROCEDURE fn_cal_sum_orderlines();

--select * from products where discount_id = 1;
--select * from orderlines natural join products where discount_id = 1;

-- func calculate total amount by month
-- DROP function if exists cal_sum_by_month(in char);
CREATE OR REPLACE FUNCTION cal_sum_by_month(in month_year char)
RETURNS SETOF decimal AS $$
BEGIN 
	RETURN query 
	SELECT sum(total_amount) FROM orders 
	WHERE to_char(order_date, 'YYYY/MM') = month_year;
END;
$$ LANGUAGE plpgsql;
-- select * from orders order by order_date;
-- select * from cal_sum_by_month ('2020/03');

--CREATE OR REPLACE FUNCTION fn_find_cate (in cate_name char)
--RETURN
CREATE VIEW product_inf AS
SELECT p.product_id, p.name, p.quan_in_stock, c.name as category
FROM products p, category c
WHERE p.category_id = c.category_id;

SELECT * from product_inf;