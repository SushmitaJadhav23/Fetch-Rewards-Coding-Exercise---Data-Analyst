CREATE DATABASE fetch_rewards;
USE fetch_rewards;

-- Changing datatypes
ALTER TABLE df_users MODIFY created_date DATE;
ALTER TABLE df_users MODIFY lastLogin_date DATE;
ALTER TABLE df_users DROP COLUMN MyUnknownColumn;
ALTER TABLE df_brands DROP COLUMN MyUnknownColumn;
ALTER TABLE df_receipts_rewards DROP COLUMN MyUnknownColumn;
ALTER TABLE df_receipts_rewards MODIFY created_date DATE;
ALTER TABLE df_receipts_rewards MODIFY finish_date DATE;
ALTER TABLE df_receipts_rewards MODIFY modify_date DATE;
ALTER TABLE df_receipts_rewards MODIFY pointsawarded_date DATE;
ALTER TABLE df_receipts_rewards MODIFY purchased_date DATE;
ALTER TABLE df_receipts_rewards MODIFY scanned_date DATE;


SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'fetch_rewards' AND TABLE_NAME = 'df_users';
SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'fetch_rewards' AND TABLE_NAME = 'df_brands';
SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = 'fetch_rewards' AND TABLE_NAME = 'df_receipts_rewards';


SELECT * FROM df_users;
SELECT * FROM df_brands;
SELECT * FROM df_receipts_rewards;

/* Q1 What are the top 5 brands by receipts scanned for most recent month? */

-- locating brands using brandcode and barcode on the receipts
-- counting and ranking brands for only receipts having scanned date
-- filtering only top 5 brands
-- Assuming the scanned date is only available if the reward receipt is scanned else it is null


WITH tmp_cte AS
	(
	SELECT
		b.name AS brand_name
	    ,r.uuid
	    ,DATE_FORMAT(r.scanned_date, '%Y-%m') AS scanned_date
	    ,CASE WHEN r.scanned_date IS NOT NULL THEN 1 ELSE 0 END AS rs_flag
	FROM df_receipts_rewards r 
		LEFT JOIN df_brands b ON (r.barcode = b.barcode OR r.brandCode = b.brandCode) 
	    -- this will join on brand code as well as brand code 
	)
	,rnk AS
	(
	SELECT
		brand_name
        ,scanned_date
	    ,COUNT(DISTINCT uuid) AS num_receipts_scanned
	    ,row_number() over (ORDER BY COUNT(DISTINCT uuid) DESC) AS rnk
	FROM tmp_cte
	WHERE rs_flag = 1
	AND scanned_date = (SELECT MAX(DATE_FORMAT(scanned_date, '%Y-%m')) FROM df_receipts_rewards) -- max(scanned_date) for fetching most recent month
	GROUP BY 1,2
	)
SELECT
	brand_name
    ,scanned_date
	,num_receipts_scanned
FROM rnk
WHERE rnk <= 5;

-- Result:
-- For the most recent month '2021-03', there is only one scanned receipt for the brand 'Kraft'. However there are 29 scanned receipts which are not having any brand name.

/* Q2 How does the ranking of the top 5 brands by receipts scanned for 
the recent month compare to the ranking for the previous month?*/


WITH tmp_cte AS
	(
	SELECT
		b.name AS brand_name
	    ,r.uuid AS num_receipts
	    ,EXTRACT(year_month FROM CAST(r.scanned_date AS date)) AS scanned_date
	    ,CASE WHEN r.scanned_date IS NOT NULL THEN 1 ELSE 0 END AS rs_flag
	FROM df_receipts_rewards r 
		LEFT JOIN df_brands b ON (r.barcode = b.barcode OR r.brandCode = b.brandCode) 
	    -- this will join on brand code as well as brand code 
	WHERE DATE_FORMAT(r.scanned_date, '%Y')= '2021' 
    AND b.name IS NOT NULL
    )
  	,rnk AS(
	SELECT
		scanned_date AS ts
        ,brand_name
	    ,COUNT(num_receipts) AS num_receipts_scanned
	    ,row_number() over (PARTITION BY scanned_date ORDER BY COUNT(num_receipts) DESC) AS rnk
	FROM tmp_cte
	WHERE rs_flag = 1
	GROUP BY 1,2
	)
SELECT
	ts
    ,brand_name
	,num_receipts_scanned
    ,rnk
    ,LEAD(rnk,1) OVER (PARTITION BY brand_name ORDER BY ts) AS current_rank
FROM rnk
WHERE rnk <= 5;

-- Result:
-- Although most brands do not appear in every month, only brand_name Kleenex have rank shift from 3 to 1 from Jan'21 to Feb'21
-- There may be data quality issues as in Jan'21 Doritos have rank 1 



/* Q3 When considering average spend from receipts with 'rewardsReceiptStatus’ of ‘Accepted’ or ‘Rejected’, 
	which is greater? */

-- CASE 1: total spent per receipt
SELECT
	 SUM(CASE WHEN r.rewardsReceiptStatus = 'FINISHED' THEN r.totalSpent ELSE 0 END) / 
		(SELECT COUNT(*) FROM df_receipts_rewards WHERE rewardsReceiptStatus = 'FINISHED') AS 'Accepted'
    ,SUM(CASE WHEN r.rewardsReceiptStatus = 'REJECTED' THEN r.totalSpent ELSE 0 END) / 
		(SELECT COUNT(*) FROM df_receipts_rewards WHERE rewardsReceiptStatus = 'REJECTED') AS 'Rejected'
FROM df_receipts_rewards r 
WHERE r.rewardsReceiptStatus IN ('FINISHED','REJECTED');


-- CASE 2: 

-- Results:
--  The total spent looks higher for Accepted (finished) rewards recipts when compared to rejected ones.
SELECT
	 AVG(CASE WHEN r.rewardsReceiptStatus = 'FINISHED' THEN r.totalSpent ELSE 0 END) AS 'Accepted'
    ,AVG(CASE WHEN r.rewardsReceiptStatus = 'REJECTED' THEN r.totalSpent ELSE 0 END) AS 'Rejected'
FROM df_receipts_rewards r 
WHERE r.rewardsReceiptStatus IN ('FINISHED','REJECTED');



/* Q4 When considering total number of items purchased from receipts with 'rewardsReceiptStatus’ 
	of ‘Accepted’ or ‘Rejected’, which is greater? */
SELECT
	 SUM(CASE WHEN r.rewardsReceiptStatus = 'FINISHED' THEN r.purchasedItemCount ELSE 0 END) AS 'Accepted'
    ,SUM(CASE WHEN r.rewardsReceiptStatus = 'REJECTED' THEN r.purchasedItemCount ELSE 0 END) AS 'Rejected'
FROM df_receipts_rewards r 
WHERE r.rewardsReceiptStatus IN ('FINISHED','REJECTED');


-- Results:
-- The total number of items purchased from receipts with 'rewardsReceiptStatus'



/* Q5 Which brand has the most spend among users who were created within the past 6 months? */
-- pull users created within past 6 month

SELECT
	b.name AS brand_name
    ,ROUND(SUM(r.totalSpent),2) AS total_spend
FROM df_receipts_rewards r
	LEFT JOIN df_brands b ON (r.barcode = b.barcode OR r.brandCode = b.brandCode)
    LEFT JOIN df_users u ON r.userId = u.uuid 
WHERE u.created_date > DATE_SUB('2021-03-01', INTERVAL 6 MONTH)
GROUP BY 1
ORDER BY 2 DESC;

-- Results:
-- Doritos, KNORR, Dole Chilled Fruit Juices, Rice A Roni brand has the most spend among users who were created within the past 6 months


/* Q6. Which brand has the most transactions among users who were created within the past 6 months? */
SELECT
	b.name AS brand_name
    ,COUNT(DISTINCT r.uuid) AS num_transactions
FROM df_receipts_rewards r
	LEFT JOIN df_brands b ON (r.barcode = b.barcode OR r.brandCode = b.brandCode)
    LEFT JOIN df_users u ON r.userId = u.uuid 
WHERE u.created_date > DATE_SUB('2021-03-01', INTERVAL 6 MONTH) AND b.name IS NOT NULL
GROUP BY 1
ORDER BY 2 DESC;

-- Results:
-- Kleenex, KNORR, Swanson, Tostitos and Yuban Coffee brand has the most transactions among users who were created within the past 6 months




----------------------------------------------------------------------------------------------------
------------------------------------------- DATA QUALITY -------------------------------------------
----------------------------------------------------------------------------------------------------

-- Missing Information

-- Most of the receipts items do not have barcode or brandcode so their brand information is not available


WITH tmp_cte AS
	(
	SELECT
		b.name AS brand_name
	    ,r.uuid AS num_receipts
	    ,EXTRACT(year_month FROM CAST(r.scanned_date AS date)) AS scanned_date
	    ,CASE WHEN r.scanned_date IS NOT NULL THEN 1 ELSE 0 END AS rs_flag
	FROM df_receipts_rewards r 
		LEFT JOIN df_brands b ON (r.barcode = b.barcode OR r.brandCode = b.brandCode) 
	    -- this will join on brand code as well as brand code 
	)
	
SELECT
	brand_name
    ,COUNT(num_receipts) AS num_receipts_scanned
FROM tmp_cte
WHERE rs_flag = 1
AND scanned_date BETWEEN '202101' AND now()
GROUP BY 1;


-- The semi-structured JSON data have many columns with NULL values

-- Removing Duplicate Data
-- When parsing Nested JSON data for receipts that had rewards for items purchased, duplicate records existed, so



