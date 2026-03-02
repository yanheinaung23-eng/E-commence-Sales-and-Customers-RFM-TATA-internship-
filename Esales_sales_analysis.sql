SELECT *
FROM Esales.invoice;



-- Identify the range of invoice date

SELECT MAX(InvoiceDate), MIN(InvoiceDate)
FROM Esales.invoice;

## 2010-12 to 2011-12

---------------------------------------------------------------------------------------------
-- MoM revenue and seasonality trend

SELECT EXTRACT( MONTH FROM InvoiceDate) AS month,
COUNT(*) AS total_invoice,
ROUND(SUM(Quantity),0) AS total_quantity,
ROUND(SUM(Revenue),2) AS total_revenue
FROM Esales.invoice
WHERE Transaction_type = 'Sale'
AND Quantity > 0
GROUP BY EXTRACT( MONTH FROM InvoiceDate)
ORDER BY month;

## Lowest - Q1 
## Stable - Q2 , Q3
## Highest - Q4

---------------------------------------------------------------------------------------------
-- CEO3. Country revenue 

SELECT Country,
COUNT(*) AS total_invoice,
ROUND(SUM(Revenue),2) AS total_revenue
FROM `Esales.invoice`
WHERE transaction_type = 'Sale'
GROUP BY Country
ORDER BY total_revenue DESC;

## Highest is UK.

---------------------------------------------------------------------------------------------
-- Pct Sales for UK and International Customers

WITH sales AS  
(
  SELECT 
  CASE 
  WHEN Country = 'United Kingdom' THEN 'UK'
  ELSE 'International'
  END AS region,
  ROUND(SUM(Revenue),2) AS sales_total
  FROM `Esales.invoice`
  WHERE Quantity > 0
  GROUP BY region
)
SELECT
region,
sales_total,
ROUND(
sales_total * 100 / SUM(sales_total) OVER(),2
) AS pct_of_sales
FROM sales;

---------------------------------------------------------------------------------------------
-- AOV calculation for UK and International 


  SELECT 
  CASE 
  WHEN Country = 'United Kingdom' THEN 'UK'
  ELSE 'International'
  END AS region,
  ROUND(AVG(Revenue),2) AS AOV
  FROM `Esales.invoice`
  WHERE Quantity > 0
  GROUP BY region;

----------------------------------------------------------------------------------------------
-- Are we depend on small number of customer? Revenue Concentration risk


--() For UK customers

SELECT CustomerID,
ROUND(SUM(Revenue),2) AS total_revenue 
FROM `Esales.invoice`
WHERE Country = 'United Kingdom' AND Transaction_type = 'Sale' AND CustomerID IS NOT NULL
GROUP BY CustomerID
ORDER BY total_revenue DESC; 

## There are 3 vip customers whose revenue is over 150k in UK

-- Loyal customers

WITH loyal_customer AS 
(
 SELECT CustomerID,
ROUND(SUM(Revenue),2) AS total_revenue 
FROM `Esales.invoice`
WHERE Country = 'United Kingdom' AND Transaction_type = 'Sale' AND CustomerID IS NOT NULL
GROUP BY CustomerID
ORDER BY total_revenue DESC
)
SELECT CustomerID, total_revenue 
FROM loyal_customer
WHERE total_revenue >= 50000;

## There are 16 loyal customers whose revenue is over 50k in UK

-- UK total Customers 

WITH pct_customer AS  
(
SELECT DISTINCT CustomerID
FROM Esales.invoice
WHERE Country = 'United Kingdom' AND Transaction_type = 'Sale' AND CustomerID IS NOT NULL
)
SELECT COUNT(*) AS total_customer
FROM pct_customer;

## UK Total customer 3921 



-- Calculate average revenue without loyal customer


WITH no_loyal_cust AS  
(
SELECT CustomerID, ROUND(SUM(Revenue),2) AS total_revenue
FROM Esales.invoice
WHERE Country = 'United Kingdom' AND Transaction_type = 'Sale' AND CustomerID IS NOT NULL
GROUP BY CustomerID
)
SELECT ROUND(AVG(total_revenue),2) AS average_revenue_without_loyal_customer
FROM no_loyal_cust
WHERE total_revenue < 50000;

## Average revenue without loyal customer is 1491.89

## So loyal customers generate 33.5x times than normal customers


--() For international country without UK

SELECT CustomerID, Country,
ROUND(SUM(Revenue),2) AS total_revenue 
FROM `Esales.invoice`
WHERE Country != 'United Kingdom' AND Transaction_type = 'Sale' AND CustomerID IS NOT NULL
GROUP BY CustomerID, Country
ORDER BY total_revenue DESC; 

## There is one high boss customers from Netherlands whose revenue is over 280k. 

-- Loyal customers

WITH loyal_customer AS 
(
 SELECT CustomerID, Country,
ROUND(SUM(Revenue),2) AS total_revenue 
FROM `Esales.invoice`
WHERE Country != 'United Kingdom' AND Transaction_type = 'Sale' AND CustomerID IS NOT NULL
GROUP BY CustomerID, Country
ORDER BY total_revenue DESC
)
SELECT CustomerID, Country,total_revenue 
FROM loyal_customer
WHERE total_revenue >= 50000;

## There are 4 loyal customers whose revenue is over 100k Internationally from Netherlands, EIRE, Australia

-- Percentage of loyal customers

WITH pct_customer AS  
(
SELECT DISTINCT CustomerID
FROM Esales.invoice
WHERE Country != 'United Kingdom' AND Transaction_type = 'Sale' AND CustomerID IS NOT NULL
)
SELECT COUNT(*) AS total_customer
FROM pct_customer;

## Total customer 418  

-- Calculate average revenue without loyal customer


WITH no_loyal_cust AS  
(
SELECT CustomerID, ROUND(SUM(Revenue),2) AS total_revenue
FROM Esales.invoice
WHERE Country != 'United Kingdom' AND Transaction_type = 'Sale' AND CustomerID IS NOT NULL
GROUP BY CustomerID
)
SELECT ROUND(AVG(total_revenue),2) AS average_revenue_without_loyal_customer
FROM no_loyal_cust
WHERE total_revenue < 50000;

## Average revenue without loyal customer is 2261.21

## So loyal customers generate 44x times than normal customers

---------------------------------------------------------------------------------------------------
-- Top 10 country internationally.

SELECT Country,
ROUND(SUM(Revenue),2) AS total_sales
FROM Esales.invoice
WHERE Quantity > 0 AND Country != 'United Kingdom'
GROUP BY Country
ORDER BY total_sales DESC;

--------------------------------------------------------------------------------------------------

-- Average order value for UK and international

-- UK AOV

SELECT
ROUND(SUM(Revenue)/ COUNT(*),2) AS AOV
FROM `Esales.invoice`
WHERE Country = 'United Kingdom' AND
Quantity > 0; 

## AOV UK = 18.71 

SELECT 
ROUND(SUM(Revenue)/ COUNT(*),2) AS AOV
FROM Esales.invoice
WHERE Country != 'United Kingdom' AND
Quantity > 0;

## AOV International = 36.52


-------------------------------------------------------------------------------------------------
-- One Time purchase vs repeated purchase

WITH Customer_orders AS 
(
  SELECT 
  CASE WHEN Country = 'United Kingdom' THEN 'UK'
   ELSE 'International'
   END  AS region,
   CustomerID,
   COUNT(Distinct invoiceNo) AS total_invoice
   FROM Esales.invoice 
   WHERE Quantity > 0 AND customerID IS NOT NULL
   GROUP BY CustomerID, region
),
customer_seg AS  
(
  SELECT
  region,
  CustomerID,
  (CASE 
  WHEN total_invoice = 1 THEN 'One Time'
  ELSE 'Multiple Times'
  END ) AS status
  FROM Customer_orders
)
SELECT 
region,
status,
COUNT(*) AS customer_count,
ROUND(
  COUNT(*) * 100 / SUM(COUNT(*)) OVER( PARTITION BY region),2 ) AS pct
FROM customer_seg
GROUP BY region, status;  

## Both UK and international the percentage are almost the same,
## One time 34%, mutiple times 66%


--------------------------------------------------------------------------------------------------
-- What % of revenue comes from repeat buyers vs one-time buyers?


WITH base AS   
(
  SELECT 
    CASE
      WHEN Country = 'United Kingdom' THEN 'UK'
      ELSE 'International'
    END AS region,
    CustomerID,
    COUNT(DISTINCT invoiceNo) AS order_count,
    SUM(Revenue) AS total_revenue
  FROM Esales.invoice
  GROUP BY CustomerID, region
),

customer_seg AS   
(
  SELECT
    region,
    CASE
      WHEN order_count = 1 THEN 'One Time'
      ELSE 'Repeated'
    END AS status,
    SUM(total_revenue) AS sum_revenue
  FROM base
  GROUP BY region, status
)

SELECT 
  region,
  status,
  ROUND(sum_revenue,2) AS revenue,
  ROUND(
    sum_revenue * 100 
    / SUM(sum_revenue) OVER (PARTITION BY region)
  ,2) AS revenue_percentage
FROM customer_seg;

## International Repeated customers generate 95.23% and One time customers generate 4.77%
## UK Repeated customers generate 95.96% and One time customers generate 4.04%


----------------------------------------------------------------------------------------------------------
-- Cohort Analysis

WITH first_purchase AS  
(
  SELECT
  CustomerID,
  DATE_TRUNC( MIN(invoice_Date), MONTH ) AS cohort_month
  FROM Esales.invoice
  WHERE Quantity > 0
  AND CustomerID IS NOT NULL
  GROUP BY CustomerID 
),
monthly_activity AS (
  SELECT
  CustomerID,
  DATE_TRUNC( invoice_Date, MONTH ) AS activity_month
  FROM Esales.invoice
  WHERE Quantity > 0
  AND CustomerID IS NOT NULL 
)
SELECT
f.cohort_month,
DATE_DIFF(m.activity_month, f.cohort_month, MONTH ) AS month_number,
COUNT(DISTINCT m.CustomerID) AS active_customers
FROM first_purchase f
JOIN monthly_activity m
ON f.CustomerID = m.CustomerID
GROUP BY cohort_month, month_number
ORDER BY cohort_month, month_number;

## On the month_number 1 , customer first purchase drop from 885 to 324 in january 2011, and the rate is stable.
## On the December it spike up to 445 
## So conclusion is Business heavily depend on seasonality. 

----------------------------------------------------------------------------------------------------------
-- CLV 

WITH CLV AS
(
  SELECT CustomerID,
  MIN(Invoice_date) AS first_purchase_date,
  MAX(Invoice_date) AS last_purchase_date,
  SUM(Revenue) AS total_revenue
  FROM Esales.invoice
  GROUP BY CustomerID
)
SELECT ROUND(AVG(total_revenue),2) AS avg_value,
ROUND(AVG(DATE_DIFF(last_purchase_date, first_purchase_date, DAY)),2) AS avg_lifespan_day
FROM CLV;

## Average Value $2433.59 
## Average Lifespan days 133.78 

----------------------------------------------------------------------------------------------------------
-- sales Running total

WITH Running_total_CTE AS
( 
SELECT 
Invoice_date,
ROUND(SUM(Revenue),2) AS daily_sales,
FROM Esales.invoice
WHERE Quantity > 0
GROUP BY Invoice_Date
ORDER BY Invoice_date
)
SELECT 
Invoice_date,
daily_sales,
ROUND(SUM(daily_sales) OVER( ORDER BY Invoice_date),2) AS running_total
FROM Running_total_CTE;


SELECT SUM(Revenue)
FROM Esales.invoice;



---------------------------------------------------------------------------------------------------------
-- Pareto Chart for excel

SELECT CustomerID,
CASE
WHEN Country = 'United Kingdom' THEN 'UK'
ELSE 'International'
END AS region,
ROUND(SUM(Revenue),2) AS Revenue_per_customer
FROM Esales.invoice
GROUP BY CustomerID, region;


----------------------------------------------------------------------------------------------------------
-- Which area do we need to focus apart from UK for international expansion.

SELECT
Country,
ROUND(SUM(Revenue),2) AS revenue
FROM Esales.invoice
WHERE Country != 'United Kingdom'
GROUP BY Country
ORDER BY revenue DESC;


----------------------------------------------------------------------------------------------------------
-- RFM score


WITH base AS
(
  SELECT
  CustomerID,
  CASE 
  WHEN Country = 'United Kingdom' THEN 'UK'
  ELSE 'International'
  END AS region,
  MIN(invoice_date) AS first_purchase_date,
  MAX(invoice_date) AS last_purchase_date,
  ROUND(SUM(Quantity),2) AS total_quantity,
  COUNT(*) AS Frequency,
  ROUND(SUM(Revenue),2) AS Monetary
  FROM Esales.invoice
  WHERE Quantity > 0 AND CustomerID IS NOT NULL
  GROUP BY CustomerID, Country
),
max_date AS  
(
  SELECT MAX(invoice_date) AS Maximum_date
  FROM Esales.invoice
)
SELECT 
b.CustomerID,
b.region,
b.first_purchase_date,
b.last_purchase_date,
b.total_quantity,
DATE_DIFF(m.Maximum_date, b.last_purchase_date, DAY) AS Recency,
b.Frequency,
b.Monetary,
CASE 
WHEN DATE_DIFF(m.Maximum_date, b.last_purchase_date, DAY) BETWEEN 0 and 14 THEN 5
WHEN DATE_DIFF(m.Maximum_date, b.last_purchase_date, DAY) BETWEEN 15 AND 45 THEN 4
WHEN DATE_DIFF(m.Maximum_date, b.last_purchase_date, DAY) BETWEEN 46 AND 90 THEN 3
WHEN DATE_DIFF(m.Maximum_date, b.last_purchase_date, DAY) BETWEEN 91 AND 180 THEN 2
ELSE 1
END AS R_score,
CASE 
WHEN b.Frequency <= 10 THEN 1
WHEN b.Frequency <= 39 THEN 2
WHEN b.Frequency <= 89 THEN 3
WHEN b.Frequency <= 149 THEN 4
ELSE 5 
END AS F_score,
CASE
WHEN b.Monetary <= 500 THEN 1
WHEN b.Monetary <= 2099 THEN 2
WHEN b.Monetary <= 5000 THEN 3
WHEN b.Monetary <= 14999 THEN 4
ELSE 5
END AS M_score, 
FROM base b
CROSS JOIN max_date m
ORDER BY R_score DESC, F_score DESC, M_score DESC;

--------------------------------------------------------------------------------------------------------------
                                        /* THE END */










