
-- drop table
DROP TABLE IF EXISTS product_history;
DROP TABLE IF EXISTS price_history;
DROP TABLE IF EXISTS orderlines;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS customers;
DROP TABLE IF EXISTS staffs;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS category;
DROP TABLE IF EXISTS discount;

-- Entity

-- user management
CREATE TABLE IF NOT EXISTS customers (
	phone char(10) NOT NULL PRIMARY KEY,
	first_name varchar(25),
	last_name varchar(25),
	DoB date,
	gender varchar(10),  -- Male, Female, Other? 
	email varchar(50),
	address varchar(100),
	member_type varchar default 'copper',  
	point int default 0
);

ALTER TABLE customers
ADD CONSTRAINT check_member_type CHECK (member_type in ('diamond', 'gold', 'silver', 'copper'));

CREATE TABLE IF NOT EXISTS staffs (
	username varchar NOT NULL PRIMARY KEY,
	password text NOT NULL DEFAULT 'abc123',
 	manager_id varchar,
 	permissions varchar ,
	first_name varchar(25) NOT NULL,
	last_name varchar(25) NOT NULL,
	DoB date,
	gender varchar(10),  -- Male, Female, Other? 
	phone char(10) NOT NULL,
	email varchar(50),
	address varchar,
	hire_date date NOT NULL,
	off_date date,
	working_status varchar(10) DEFAULT 'doing' 
);

ALTER TABLE staffs
   ADD CONSTRAINT st_fk_st_man FOREIGN KEY (manager_id) REFERENCES staffs(username),
   ADD CONSTRAINT check_working_status CHECK (working_status in ('doing', 'quit'))
;

-- product management

CREATE TABLE IF NOT EXISTS discount (
	discount_id int NOT NULL PRIMARY KEY,
	name varchar,
	description varchar,
	discount_percent decimal NOT NULL,
	begin_date date,  
	end_date date 
);

CREATE TABLE IF NOT EXISTS category (
	category_id int NOT NULL PRIMARY KEY,
	name varchar(25) NOT NULL,
	description text
);

-- quan_in_stock update by trigger whenever insert into product_history 
CREATE TABLE IF NOT EXISTS products (
	product_id varchar(25) NOT NULL PRIMARY KEY,   -- add constraint to check format xxx-COLOR-SIZE  
	name varchar(50),
	size varchar(5), 
	color varchar(10),
	description text,
	category_id int REFERENCES category(category_id),
	sale_price decimal(10, 2) NOT NULL,
	quan_in_stock int DEFAULT 0, 
	discount_id int REFERENCES discount(discount_id)
);

-- need function to update product
CREATE TABLE IF NOT EXISTS product_history (
	product_id varchar(25) NOT NULL REFERENCES products(product_id),
	date_in timestamp NOT NULL,
	quantity int NOT NULL,
	entry_price decimal(10, 2) NOT NULL,
	manager_id varchar NOT NULL REFERENCES staffs(username),
	CONSTRAINT pk_pro_his_id PRIMARY KEY (product_id, date_in)
);	

CREATE TABLE IF NOT EXISTS price_history (
	product_id varchar(25) NOT NULL REFERENCES products(product_id),
	date_in timestamp NOT NULL,
	old_price decimal(10, 2) NOT NULL, 
	new_price decimal(10, 2) NOT NULL
);

-- shopping management

CREATE TABLE IF NOT EXISTS orders (
	order_id int NOT NULL PRIMARY KEY, 
	order_date timestamp DEFAULT current_date, 
	customer_id char(10) REFERENCES customers(phone),
	staff_id text REFERENCES staffs(username),
	discount decimal (12, 2) default 0,  -- phan tram giam gia theo rank
	total_amount decimal(12, 2) default 0,  -- tong tien, da tinh giam gia theo rank
	point decimal(10, 2) default 0,			-- diem tich duoc sau moi hoa don
	payment_type varchar(10)
);

ALTER TABLE orders
	ADD CONSTRAINT ct_payment_type CHECK (payment_type in ('cash', 'card', 'banking'));
	
CREATE TABLE IF NOT EXISTS orderlines (
	order_id int NOT NULL REFERENCES orders(order_id),
	product_id varchar(25) NOT NULL REFERENCES products(product_id),
	quantity int NOT NULL,
	total_amount int default 0, -- tong tien, da tinh tien giam gia theo san pham
	discount int default 0, -- phan tram giam gia theo san pham
	CONSTRAINT pk_orderlines PRIMARY KEY (order_id, product_id)
	-- discount
);

