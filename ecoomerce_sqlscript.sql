create database e_commerce_analysis;
use e_commerce_analysis;
drop table customer;
create table customer(
user_id int,
session_id int,
date_purchased varchar(50),
month_purchased varchar(50),
channel_type varchar(50),
campaign_type varchar(50),
device varchar(50),
user_type varchar(50),
region varchar(50),
visited_website varchar(50),
viewed_product varchar(50),
added_to_cart	varchar(50),
checkout_started	varchar(50), 
purchase_completed	varchar(50),
discount_applied	varchar(50),
order_value  varchar(50),
revenue varchar(50)  );

describe customer;
SHOW VARIABLES LIKE 'secure_file_priv';
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/d2c_marketing_funnel_data.csv'
INTO TABLE customer
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;

SELECT COUNT(*), COUNT(DISTINCT session_id), MIN(session_id), MAX(session_id)
FROM customer;

select  * from customer;

SELECT user_id, COUNT(user_id)
FROM customer
group by user_id
having count(user_id) >1;

select count(*) as total_rows,
 count(distinct session_id) as unique_Sessions,
 count(distinct user_id) as unique_user
 from customer;
 
 alter table customer add primary key(session_id);
describe customer;

-- checking consistency of the dataset
SELECT DISTINCT channel_type
FROM customer
ORDER BY channel_type;

SELECT DISTINCT campaign_type
FROM customer
ORDER BY campaign_type;

SELECT DISTINCT device
FROM customer
ORDER BY device;

SELECT DISTINCT user_type
FROM customer
ORDER BY user_type;

SELECT DISTINCT region
FROM customer
ORDER BY region;


create table customer_clean as
select *,
case
when date_purchased like '%/%'
then str_to_date(date_purchased, '%m/%d/%Y')
when date_purchased like '%-%'
then str_to_date(date_purchased, '%m-%d-%Y')
else null
end as purchased_date
from customer;

SELECT
    date_purchased,
    DATE_FORMAT(purchased_date, '%Y-%m-%d') AS cleaned_date
FROM customer_clean;

ALTER TABLE customer
ADD COLUMN purchased_date DATE;

UPDATE customer c
JOIN customer_clean cc
    ON c.session_id = cc.session_id
SET c.purchased_date = cc.purchased_date;

SELECT date_purchased, purchased_date
FROM customer
LIMIT 20;

select * from customer limit 50; 

ALTER TABLE customer
DROP COLUMN date_purchased;

ALTER TABLE customer
RENAME COLUMN purchased_date TO date_purchased;
SELECT session_id, date_purchased
FROM customer
LIMIT 20;

-- finding the missing vallues
SELECT
    SUM(user_id IS NULL) AS missing_user_id,
    SUM(session_id IS NULL) AS missing_session_id,
    SUM(date_purchased IS NULL) AS missing_date,
    SUM(channel_type IS NULL OR TRIM(channel_type) = '') AS missing_channel,
    SUM(device IS NULL OR TRIM(device) = '') AS missing_device,
    SUM(order_value IS NULL) AS missing_order_value
FROM customer;

select distinct channel_type
from customer 
group by channel_type;

-- calculating the conversions and drop off percentage

select count(*) as total_rows,
sum(viewed_product = 'Yes') as product_views,
sum(added_to_cart ='Yes' ) as add_to_cart,
sum(checkout_started = 'Yes' ) as checkouts,
sum(purchase_completed = 'Yes') as purchases,

round(
sum(added_to_cart = 'Yes') * 100/
sum(viewed_product = 'Yes'),2) as view_to_cart,

round(
sum(checkout_started = 'Yes') * 100/
sum(added_to_cart = 'Yes'),2) as cart_to_checkout,

round(
sum(purchase_completed = 'Yes') * 100/
sum(checkout_started = 'Yes'),2) as purchase_to_cart

from customer;

-- finding which channel type performming the best

select channel_type, count(*) as total_Sessions,
sum(purchase_completed = 'Yes') as purchases,
round(sum(purchase_completed = 'Yes') * 100/ count(*) ,2)
as purchase_rate_percentage
from customer
group by channel_type
order by purchase_rate_percentage desc;

-- revenue by each channel
select channel_type, count(*) as total_session,
sum(purchase_completed = 'Yes' ) as purchases,
round(sum(revenue),2) as total_revenue
from customer
group by channel_type
order by total_revenue desc;

-- calculating the average order value means avg revenue per purchase completed

select 
round(sum(case when purchase_completed = 'Yes' then revenue else 0 
end)/ sum(purchase_completed = 'Yes'),2) as avg_order_val
from customer;


-- unique customers
SELECT
    COUNT(DISTINCT user_id) AS unique_customers,
    COUNT(*) AS total_sessions
FROM customer;


-- calculating the repeat cutsomers and repeat purchae rate
SELECT
    COUNT(*) AS total_purchasing_customers,
    SUM(purchase_count > 1) AS repeat_customers,
    SUM(purchase_count = 1) AS one_time_customers,
    ROUND(
        SUM(purchase_count > 1) * 100 / COUNT(*),
        2
    ) AS repeat_purchase_rate
FROM (
    SELECT
        user_id,
        SUM(purchase_completed = 'Yes') AS purchase_count
    FROM customer
    GROUP BY user_id
    HAVING SUM(purchase_completed = 'Yes') > 0
) AS customer_purchases;  


-- cohort nalysis , like analyzing customer beaviour over months
-- we anazed july has most purchases and december has least purchases
select * from customer limit 50;

select month_purchased, count(distinct user_id) as purchasing_customer,
sum(purchase_completed='Yes') as total_purchases,
round(sum(case when purchase_completed = 'Yes' then revenue else 0 end),2)as total_revenue
from customer 
where purchase_completed = 'Yes'
group by month_purchased
order by month_purchased;

-- grouping the user id wo returned for ppurchasing in other months
WITH first_purchase AS (
    SELECT
        user_id,
        MIN(month_purchased) AS cohort_month
    FROM customer
    WHERE purchase_completed = 'Yes'
    GROUP BY user_id
),
cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(*) AS cohort_size
    FROM first_purchase
    GROUP BY cohort_month
),
monthly_purchases AS (
    SELECT DISTINCT
        user_id,
        month_purchased AS activity_month
    FROM customer
    WHERE purchase_completed = 'Yes'
)
SELECT
    fp.cohort_month,
    mp.activity_month,
    COUNT(DISTINCT fp.user_id) AS active_customers,
    cs.cohort_size,
    ROUND(
        COUNT(DISTINCT fp.user_id) * 100.0 / cs.cohort_size,
        2
    ) AS retention_percentage
FROM first_purchase fp
JOIN monthly_purchases mp
    ON fp.user_id = mp.user_id
JOIN cohort_sizes cs
    ON fp.cohort_month = cs.cohort_month
WHERE mp.activity_month >= fp.cohort_month
GROUP BY
    fp.cohort_month,
    mp.activity_month,
    cs.cohort_size
ORDER BY
    fp.cohort_month, 
    mp.activity_month;  
    
-- yes or no record count
SELECT
    purchase_completed,
    COUNT(*) AS record_count
FROM customer
GROUP BY purchase_completed; 


-- revenue by device
SELECT
    device,

    COUNT(*) AS total_sessions,

    SUM(purchase_completed = 'Yes') AS completed_purchases,

    ROUND(
        SUM(
            CASE
                WHEN purchase_completed = 'Yes'
                THEN COALESCE(
                    CAST(NULLIF(TRIM(revenue), '') AS DECIMAL(12,2)),
                    0
                )
                ELSE 0
            END
        ), 2
    ) AS total_revenue,

    ROUND(
        SUM(purchase_completed = 'Yes') * 100.0 / COUNT(*),
        2
    ) AS conversion_rate,

    ROUND(
        SUM(
            CASE
                WHEN purchase_completed = 'Yes'
                THEN COALESCE(
                    CAST(NULLIF(TRIM(revenue), '') AS DECIMAL(12,2)),
                    0
                )
                ELSE 0
            END
        ) / NULLIF(SUM(purchase_completed = 'Yes'), 0),
        2
    ) AS average_order_value

FROM customer
GROUP BY device
ORDER BY total_revenue DESC;

        
-- conversion and revenue by region
SELECT
    region,
    COUNT(*) AS total_sessions,
    SUM(purchase_completed = 'Yes') AS completed_purchases,
    ROUND(
        SUM(
            CASE
                WHEN purchase_completed = 'Yes' THEN revenue
                ELSE 0
            END
        ), 2
    ) AS total_revenue,
    ROUND(
        SUM(purchase_completed = 'Yes') * 100.0 / COUNT(*),
        2
    ) AS conversion_rate
FROM customer
GROUP BY region
ORDER BY total_revenue DESC;



-- customer analysis

SELECT
    user_type,
    COUNT(*) AS total_sessions,
    SUM(purchase_completed = 'Yes') AS completed_purchases
FROM customer
GROUP BY user_type
ORDER BY total_sessions DESC;



-- new customers and returning customers behave differently in terms of purchases and revenue

SELECT
    user_type,
    COUNT(*) AS total_sessions,
    SUM(purchase_completed = 'Yes') AS completed_purchases
FROM customer
GROUP BY user_type
ORDER BY total_sessions DESC;
 
 
-- which customer type contributes more to revenue

SELECT
    user_type,
    SUM(purchase_completed = 'Yes') AS completed_purchases,
    ROUND(
        SUM(
            CASE
                WHEN purchase_completed = 'Yes' THEN revenue
                ELSE 0
            END
        ), 2
    ) AS total_revenue,
    ROUND(
        SUM(
            CASE
                WHEN purchase_completed = 'Yes' THEN revenue
                ELSE 0
            END
        ) / SUM(purchase_completed = 'Yes'),
        2
    ) AS average_order_value
FROM customer
GROUP BY user_type
ORDER BY total_revenue DESC;

-- repeat purchase rate by channel type
SELECT
    channel_type,
    COUNT(*) AS purchasing_customers,
    SUM(purchase_count > 1) AS repeat_customers,
    ROUND(
        SUM(purchase_count > 1) * 100.0 / COUNT(*),
        2
    ) AS repeat_purchase_rate
FROM (
    SELECT
        user_id,
        channel_type,
        SUM(purchase_completed = 'Yes') AS purchase_count
    FROM customer
    GROUP BY user_id, channel_type
    HAVING SUM(purchase_completed = 'Yes') > 0
) AS customer_channel_purchases
GROUP BY channel_type
ORDER BY repeat_purchase_rate DESC;


-- funnel performance by desktop vs mobile
SELECT
    device,
    COUNT(*) AS total_sessions,

    SUM(visited_website = 'Yes') AS website_visits,
    SUM(viewed_product = 'Yes') AS product_views,
    SUM(added_to_cart = 'Yes') AS cart_additions,
    SUM(checkout_started = 'Yes') AS checkout_starts,
    SUM(purchase_completed = 'Yes') AS completed_purchases,

    ROUND(
        SUM(added_to_cart = 'Yes') * 100.0 /
        NULLIF(SUM(viewed_product = 'Yes'), 0), 2
    ) AS view_to_cart_rate,

    ROUND(
        SUM(checkout_started = 'Yes') * 100.0 /
        NULLIF(SUM(added_to_cart = 'Yes'), 0), 2
    ) AS cart_to_checkout_rate,

    ROUND(
        SUM(purchase_completed = 'Yes') * 100.0 /
        NULLIF(SUM(checkout_started = 'Yes'), 0), 2
    ) AS checkout_to_purchase_rate

FROM customer
GROUP BY device
ORDER BY total_sessions DESC;

-- funnel performance by marketing channel

SELECT
    channel_type,
    COUNT(*) AS total_sessions,
    SUM(viewed_product = 'Yes') AS product_views,
    SUM(added_to_cart = 'Yes') AS cart_additions,
    SUM(checkout_started = 'Yes') AS checkout_starts,
    SUM(purchase_completed = 'Yes') AS completed_purchases,

    ROUND(
        SUM(added_to_cart = 'Yes') * 100.0 /
        NULLIF(SUM(viewed_product = 'Yes'), 0), 2
    ) AS view_to_cart_rate,

    ROUND(
        SUM(checkout_started = 'Yes') * 100.0 /
        NULLIF(SUM(added_to_cart = 'Yes'), 0), 2
    ) AS cart_to_checkout_rate,

    ROUND(
        SUM(purchase_completed = 'Yes') * 100.0 /
        NULLIF(SUM(checkout_started = 'Yes'), 0), 2
    ) AS checkout_to_purchase_rate

FROM customer
GROUP BY channel_type
ORDER BY total_sessions DESC;

