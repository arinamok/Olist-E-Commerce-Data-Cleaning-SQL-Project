/***********************************************************************************

OLIST E-COMMERCE DATA CLEANING PROJECT

Author: Arina M
Date: May 2026
Purpose: Clean and prepare Olist Brazilian dataset for BI analysis and reporting.
Dataset: 100k orders from 2016-2018 across multiple Brazilian marketplaces.
Source: Kaggle - Brazilian E-Commerce Public Dataset by Olist.
Tables: customers, order_items, sellers, products, product_category_tranlsation, 
        geolocation, order_payments, order_reviews

***********************************************************************************/

-- ==================================================================
-- SECTION 1: CUSTOMERS
-- ==================================================================

-- ------------------------------------------------------------------
-- 1A. AUDIT
-- ------------------------------------------------------------------
-- Print customers table
SELECT *
FROM customers;

-- Row count and duplicates
SELECT 
    COUNT(*) AS total_rows,
    COUNT (DISTINCT customer_id) AS distinct_customer_ids,
    COUNT(*) - COUNT(DISTINCT customer_id) AS duplicates
FROM customers;
-- 99,441 rows | 99,441 distinct rows | 0 duplicates

-- Null scan
SELECT
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_ids,
    SUM(CASE WHEN customer_unique_id IS NULL THEN 1 ELSE 0 END) AS null_unique_id,
    SUM(CASE WHEN customer_zip_code_prefix IS NULL THEN 1 ELSE 0 END) AS null_zip,
    SUM(CASE WHEN customer_city IS NULL THEN 1 ELSE 0 END) AS null_cities,
    SUM(CASE WHEN customer_state IS NULL THEN 1 ELSE 0 END) AS null_states
FROM customers;
-- 0 nulls

-- Check state format (must be 2 characters)
SELECT
    SUM(CASE WHEN LEN(customer_state) <> 2 THEN 1 ELSE 0 END) AS invalid_state_lengths,
    COUNT(DISTINCT customer_state) AS distinct_states
FROM customers;
-- 0 invalid | 27 distinct states (all have 2 characters)

-- Check whitespace in text
SELECT COUNT(*) AS rows_with_hidden_spaces
FROM customers
WHERE customer_city LIKE ' %' OR customer_city  LIKE '% '
    OR customer_state LIKE ' %' OR customer_state LIKE '% ';
-- No hidden spaces found

-- Check cities
SELECT DISTINCT customer_city
FROM customers
ORDER BY customer_city;

-- Find cities with characters other than letters
SELECT DISTINCT customer_city
FROM customers
WHERE customer_city LIKE '%[^a-zA-Z ]%'
ORDER BY customer_city;
-- 53 cities that have ' or - in names (valid cities)

-- ------------------------------------------------------------------
-- 1B. FINDINGS
-- ------------------------------------------------------------------
/*
- 0 nulls, 0 white space, 27 states
- customer_city is lower case, includes hyphens and apostrophes 
*/

-- ------------------------------------------------------------------
-- 1C. TRANSFORMATION
-- ------------------------------------------------------------------
-- Apply title case to all words separated by spaces
UPDATE customers
SET customer_city = RTRIM(
    (
        SELECT
            UPPER(LEFT(value, 1)) + LOWER(SUBSTRING(value, 2, LEN(value))) + ' '
        FROM STRING_SPLIT(customer_city, ' ')
        FOR XML PATH('')
    )
)
WHERE customer_city IS NOT NULL;

-- Check
SELECT *
FROM customers;

-- Capitalize characters after hyphen (-)
UPDATE customers
SET customer_city = STUFF(
    customer_city,
    CHARINDEX('-', customer_city) + 1,
    1,
    UPPER(SUBSTRING(customer_city, CHARINDEX('-', customer_city) + 1, 1))
)
WHERE CHARINDEX('-', customer_city) > 0;

-- Capitalize character after every apostrophe (')
UPDATE customers
SET customer_city = STUFF(
    customer_city,
    CHARINDEX('''', customer_city) + 1, 1,
    UPPER(SUBSTRING(customer_city, CHARINDEX('''', customer_city) + 1, 1))
)
WHERE CHARINDEX('''', customer_city) > 0;

-- Check the changes
SELECT DISTINCT customer_city
FROM customers
WHERE customer_city LIKE '%-%'
    OR customer_city LIKE '%''%'
ORDER BY customer_city;

-- Make sure row count didn't change
SELECT COUNT(*) AS total_rows_after FROM customers;

-- Clean any extra space added
UPDATE customers 
SET customer_city = RTRIM(customer_city);

-- Final check
SELECT *
FROM customers;


-- ==================================================================
-- SECTION 2: ORDER ITEMS
-- ==================================================================

-- ------------------------------------------------------------------
-- 2A. AUDIT
-- ------------------------------------------------------------------
SELECT *
FROM order_items;

-- Row count and duplicates
-- Primary key here is a combination of order_id and order_item_id
SELECT 
    COUNT(*) AS total_rows,
    COUNT (DISTINCT order_id) AS distinct_orders,
    COUNT(DISTINCT CONCAT(order_id, order_item_id)) AS distinct_primary_key,
    COUNT(*) - COUNT(DISTINCT CONCAT(order_id, order_item_id)) AS primary_key_duplicates
FROM order_items;
-- 112,650 rows | 98,666 distinct orders | 112,650 distinct primary key | 0 primary key duplicates

-- Null scan
SELECT
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN order_item_id IS NULL THEN 1 ELSE 0 END) AS null_order_item_id,
    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_product_id,
    SUM(CASE WHEN seller_id IS NULL THEN 1 ELSE 0 END) AS null_seller_id,
    SUM(CASE WHEN shipping_limit_date IS NULL THEN 1 ELSE 0 END) AS null_shipping_limit_date,
    SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END) AS null_price,
    SUM(CASE WHEN freight_value IS NULL THEN 1 ELSE 0 END) AS null_freight_value
FROM order_items;
-- 0 nulls in all

-- Check price and freight value
SELECT
    SUM(CASE WHEN price <= 0 THEN 1 ELSE 0 END) AS zero_or_negative_price,
    SUM(CASE WHEN freight_value < 0 THEN 1 ELSE 0 END) AS negative_freight,
    SUM(CASE WHEN freight_value = 0 THEN 1 ELSE 0 END) AS zero_freight,
    MIN(price) AS min_price,
    MAX(price) AS max_price,
    MIN(freight_value) AS min_freight,
    MAX(freight_value) AS max_freight
FROM order_items;
-- 0 zero/negative price | 383 zero freight rows (most likely free shipping, no action taken) | price range: $0.85 - $6,735 | max freight: 409.68

-- ------------------------------------------------------------------
-- 2B. FINDINGS
-- ------------------------------------------------------------------
/*
- 0 duplicates, 0 nulls
- 383 zero freight can be free shipping
- No transformation needed 
*/


-- ==================================================================
-- SECTION 3: ORDERS
-- ==================================================================

-- ------------------------------------------------------------------
-- 3A. AUDIT
-- ------------------------------------------------------------------
SELECT *
FROM orders;

-- Row count and duplicates
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS distinct_order_ids,
    COUNT(*) - COUNT(DISTINCT order_id) AS duplicates
FROM orders;
-- 99,441 rows | 99,441 distinct order ids | 0 duplicates
-- Clean

-- Null scan
SELECT
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customer_id,
    SUM(CASE WHEN order_status IS NULL THEN 1 ELSE 0 END) AS null_order_status,
    SUM(CASE WHEN order_purchase_timestamp IS NULL THEN 1 ELSE 0 END) AS null_order_purchase_timestamp,
    SUM(CASE WHEN order_approved_at IS NULL THEN 1 ELSE 0 END) AS null_order_approved_at,
    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS null_delivery_date,
    SUM(CASE WHEN order_estimated_delivery_date IS NULL THEN 1 ELSE 0 END) AS null_estimated_delivery_date
FROM orders;
-- null_order_approved_at: 160 | null_delivery_date: 2,965 | others: 0

-- Order status
SELECT
    order_status,
    COUNT(*) AS total
FROM orders
GROUP BY order_status
ORDER BY total DESC;
-- delivered: 96,478 | shipped: 1,107 | canceled: 625 | unavailable: 609 | invoiced: 314
-- processing: 301 | created: 5 | approved: 2

/* Since this table has 160 nulls of order_approved_at and 2965 null delivery dates, 
I want to check if it's a problem or expected.
Whether the order was canceled/shipped which won't have a delivery date.
Or unexpected where delivered orders are missing a delivery date.*/
SELECT
    order_status,
    SUM(CASE WHEN order_approved_at IS NULL THEN 1 ELSE 0 END) AS null_approved,
    SUM(CASE WHEN order_delivered_carrier_date IS NULL THEN 1 ELSE 0 END) AS null_carrier,
    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END) AS null_delivered
FROM orders
GROUP BY order_status
ORDER BY order_status;

-- Purchase comes before approval and delivery, checking logic
SELECT COUNT(*) AS approved_before_purchase
FROM orders
WHERE order_approved_at < order_purchase_timestamp;

SELECT COUNT(*) AS delivered_before_purchase
FROM orders
WHERE order_delivered_customer_date < order_purchase_timestamp;
-- Both show no impossible sequences

-- Check nulls logic in table
SELECT *
FROM orders
WHERE order_approved_at IS NULL
OR order_delivered_customer_date IS NULL;

-- ------------------------------------------------------------------
-- 3B. FINDINGS
-- ------------------------------------------------------------------
/*
- 99,441 rows, zero nulls, and no duplicates
- 2,965 nulls in delivery date columns are normal for undelivered items
- 8 'delivered' orders missing a delivery date are real anomaly
- 160 nulls in order_approved_at: 141 are canceled, 14 are delivered (flagged), 5 are created
- Date logic is clean, all datetime is in datetime2
- No transformations required 
*/


-- ==================================================================
-- SECTION 4: SELLERS
-- ==================================================================

-- ------------------------------------------------------------------
-- 4A. AUDIT
-- ------------------------------------------------------------------
SELECT *
FROM sellers;

-- Row count and duplicates
SELECT 
    COUNT(*) AS total_rows,
    COUNT (DISTINCT seller_id) AS distinct_seller_ids,
    COUNT(*) - COUNT(DISTINCT seller_id) AS duplicates
FROM sellers;
-- 3,095 rows | 3,095 distinct seller ids | 0 duplicates

-- Null scan
SELECT
    SUM(CASE WHEN seller_id IS NULL THEN 1 ELSE 0 END) AS null_seller_id,
    SUM(CASE WHEN seller_zip_code_prefix IS NULL THEN 1 ELSE 0 END) AS null_zip,
    SUM(CASE WHEN seller_city IS NULL THEN 1 ELSE 0 END) AS null_cities,
    SUM(CASE WHEN seller_state IS NULL THEN 1 ELSE 0 END) AS null_states
FROM sellers;
-- 0 nulls for all

-- Check state format (needs to be 2 characters)
SELECT
    SUM(CASE WHEN LEN(seller_state) <> 2 THEN 1 ELSE 0 END) AS invalid_state_lengths,
    COUNT(DISTINCT seller_state) AS distinct_states
FROM sellers;
-- 0 invalid | 23 distinct states

-- Check whitespace in text
SELECT COUNT(*) AS rows_with_hidden_spaces
FROM sellers
WHERE seller_city LIKE ' %' OR seller_city  LIKE '% '
    OR seller_state LIKE ' %' OR seller_state LIKE '% ';
-- 0 rows

-- Check cities
SELECT DISTINCT seller_city
FROM sellers
ORDER BY seller_city;
-- Has many issues (including numbers, slashes, commas, hyphens...)

-- Find cities with characters other than letters
SELECT DISTINCT seller_city
FROM sellers
WHERE seller_city LIKE '%[^a-zA-Z ]%'
ORDER BY seller_city;

-- Check how many rows are affected by characters other than letters
SELECT
    SUM(CASE WHEN seller_city LIKE '%[0-9]%' THEN 1 ELSE 0 END) AS has_numbers,
    SUM(CASE WHEN seller_city LIKE '%/%' THEN 1 ELSE 0 END) AS has_forward_slash,
    SUM(CASE WHEN seller_city LIKE '%\%' THEN 1 ELSE 0 END) AS has_back_slash,
    SUM(CASE WHEN seller_city LIKE '%@%' THEN 1 ELSE 0 END) AS has_at_symbol,
    SUM(CASE WHEN seller_city LIKE '%,%' THEN 1 ELSE 0 END) AS has_comma,
    SUM(CASE WHEN seller_city LIKE '%(%' THEN 1 ELSE 0 END) AS has_parenthesis,
    SUM(CASE WHEN seller_city LIKE '%-%' THEN 1 ELSE 0 END) AS has_hyphen,
    -- This gave 3095 rows of underscore which counted all rows: SUM(CASE WHEN seller_city LIKE '%_%' THEN 1 ELSE 0 END) AS has_underscore
    SUM(CASE WHEN seller_city LIKE '%\_%' ESCAPE '\' THEN 1 ELSE 0 END) AS has_underscore,
    SUM(CASE WHEN seller_city LIKE '%''%' THEN 1 ELSE 0 END) AS has_apostrophe
FROM sellers;
-- numbers: 1 | forward slash: 15 | back slash: 1 | symbol: 1 | comma: 2
-- parenthesis: 1 | hyphen: 5 | underscore: 3,095 | apostrophe: 6

-- Checking underscore one more time
SELECT DISTINCT seller_city
FROM sellers
WHERE seller_city LIKE '%[_]%'
ORDER BY seller_city;

-- Hyphens and apostrophes separately since most are valid
SELECT DISTINCT seller_city FROM sellers WHERE seller_city LIKE '%-%' ORDER BY seller_city;
SELECT DISTINCT seller_city FROM sellers WHERE seller_city LIKE '%''%' ORDER BY seller_city;

-- Check the rest
SELECT DISTINCT seller_city
FROM sellers
WHERE seller_city LIKE '%/%'
    OR seller_city LIKE '%\%'
    OR seller_city LIKE '%@%'
    OR seller_city LIKE '%,%'
    OR seller_city LIKE '%[0-9]%'
ORDER BY seller_city;


-- TRANSFORMATION
-- Erase everything after forward slash keeping only the city
UPDATE sellers
SET seller_city = RTRIM(LEFT(seller_city, CHARINDEX('/', seller_city) - 1))
WHERE seller_city LIKE '%/%';

-- Checking if worked
SELECT DISTINCT seller_city
FROM sellers
WHERE seller_city LIKE '%/%';

-- Check if values are right
SELECT DISTINCT seller_city
FROM sellers
WHERE seller_city IN ('auriflama', 'carapicuiba', 'mogi das cruzes', 'sao sebastiao da grama', 'rio de janeiro', 'sbc', 'sp')
ORDER BY seller_city;

-- Cutting everything after backslash (including it)
UPDATE sellers
SET seller_city = RTRIM(LEFT(seller_city, CHARINDEX('\', seller_city) - 1))
WHERE seller_city LIKE '%\%';

-- Cutting everything after comma
UPDATE sellers
SET seller_city = RTRIM(LEFT(seller_city, CHARINDEX(',', seller_city) - 1))
WHERE seller_city LIKE '%,%';

-- Trim hyphen and state, without apostrophe cities
UPDATE sellers
SET seller_city = RTRIM(LEFT(seller_city, CHARINDEX('-', seller_city) - 1))
WHERE seller_city LIKE '%-%'
AND seller_city NOT LIKE '%d''%';

-- Get rid of parenthesis and everythign after it
UPDATE sellers
SET seller_city = RTRIM(LEFT(seller_city, CHARINDEX('(', seller_city) - 1))
WHERE seller_city LIKE '%(%';

-- The city as number is not a zip code (I checked), I will make it NULL
UPDATE sellers
SET seller_city = NULL
WHERE seller_city LIKE '%[0-9]%'
OR seller_city LIKE '%@%';

-- Capital letters for words separated by space
UPDATE sellers
SET seller_city = RTRIM(
    (
        SELECT UPPER(LEFT(value, 1)) + LOWER(SUBSTRING(value, 2, LEN(value))) + ' '
        FROM STRING_SPLIT(seller_city, ' ')
        FOR XML PATH('')
    )
)
WHERE seller_city IS NOT NULL;

-- Capital letter after apostrophe
UPDATE sellers
SET seller_city = STUFF
(
    seller_city,
    CHARINDEX('''', seller_city) + 1, 1,
    UPPER(SUBSTRING(seller_city, CHARINDEX('''', seller_city) + 1, 1))
)
WHERE CHARINDEX('''', seller_city) > 0;

-- Check if worked correctly
SELECT DISTINCT seller_city FROM sellers WHERE seller_city LIKE '%''%' ORDER BY seller_city;

-- Check what is left
SELECT DISTINCT seller_city
FROM sellers
WHERE seller_city LIKE '%\%'
    OR seller_city LIKE '%,%'
    OR seller_city LIKE '%-%'
    OR seller_city LIKE '%(%'
    OR seller_city LIKE '%[0-9]%'
    OR seller_city LIKE '%@%'
ORDER BY seller_city;

-- &#x20; is space that may have been imported incorrectly
-- Replace HTML space with real space
UPDATE sellers
SET seller_city = REPLACE(seller_city, '&#x20;', ' ')
WHERE seller_city LIKE '%&#x20;%';

-- Shorten double any spaces
UPDATE sellers
SET seller_city = REPLACE(seller_city, '  ', ' ')
WHERE seller_city LIKE '%  %';

-- Check to make sure these are cleaned
SELECT DISTINCT seller_city
FROM sellers
WHERE seller_city IN (
    'rio de janeiro \rio de janeiro',
    'novo hamburgo, rio grande do sul, brasil',
    'rio de janeiro, rio de janeiro, brasil',
    'andira-pr',
    'lages - sc',
    'sao paulo - sp',
    'arraial d''ajuda (porto seguro)',
    '04482255',
    'vendas@creditparts.com.br'
);

-- Checking cities
SELECT DISTINCT seller_city
FROM sellers
WHERE seller_city LIKE '%''%'
ORDER BY seller_city;

SELECT TOP 25 seller_city 
FROM sellers 
ORDER BY seller_city;

-- Aguas Claras has Df at the end which is a state abbreviation
-- Check all cities that have abbreviations and the end of city names
-- Find cities ending in 2-letter state abbreviation preceded by a space
SELECT DISTINCT seller_city
FROM sellers
WHERE seller_city LIKE '% Ac' OR seller_city LIKE '% Al' OR seller_city LIKE '% Am'
    OR seller_city LIKE '% Ap' OR seller_city LIKE '% Ba' OR seller_city LIKE '% Ce'
    OR seller_city LIKE '% Df' OR seller_city LIKE '% Es' OR seller_city LIKE '% Go'
    OR seller_city LIKE '% Ma' OR seller_city LIKE '% Mg' OR seller_city LIKE '% Ms'
    OR seller_city LIKE '% Mt' OR seller_city LIKE '% Pa' OR seller_city LIKE '% Pb'
    OR seller_city LIKE '% Pe' OR seller_city LIKE '% Pi' OR seller_city LIKE '% Pr'
    OR seller_city LIKE '% Rj' OR seller_city LIKE '% Rn' OR seller_city LIKE '% Ro'
    OR seller_city LIKE '% Rr' OR seller_city LIKE '% Rs' OR seller_city LIKE '% Sc'
    OR seller_city LIKE '% Se' OR seller_city LIKE '% Sp' OR seller_city LIKE '% To'
ORDER BY seller_city;

-- Found added endings for Aguas Claras Df, Angra Dos Reis Rj, Brasilia Df, Sao Paulo Sp
UPDATE sellers SET seller_city = 'Aguas Claras' WHERE seller_city = 'Aguas Claras Df';
UPDATE sellers SET seller_city = 'Angra Dos Reis' WHERE seller_city = 'Angra Dos Reis Rj';
UPDATE sellers SET seller_city = 'Brasilia' WHERE seller_city = 'Brasilia Df';
UPDATE sellers SET seller_city = 'Sao Paulo' WHERE seller_city = 'Sao Paulo Sp';

-- ------------------------------------------------------------------
-- 4B. FINDINGS
-- ------------------------------------------------------------------
/*
- 3,095 rows, 0 duplicates, 0 nulls
- seller_city had multiple issues:
        - 15 forward slashes, 1 backslash, 2 commas, 3 hyphens (removed city/state style)
        - parenthesis (removed neighborhood)
        - 3 rows with encoded spaces fixed
        - 4 cities had state abbreviations and the end, were cut
        - number and @ symbol cities were set to Null (unrecoverable)
- Capitalized first letters and post-apostrophe
- seller_state clean, 0 invalid lengths, 23 distinct states
*/


-- ==================================================================
-- SECTION 5: PRODUCTS
-- ==================================================================

-- ------------------------------------------------------------------
-- 5A. AUDIT
-- ------------------------------------------------------------------
SELECT *
FROM products;

-- Misspelled column names: product_name_length, product_description_length

-- Row count and duplicate
SELECT 
    COUNT(*) AS total_rows,
    COUNT (DISTINCT product_id) AS distinct_product_ids,
    COUNT(*) - COUNT(DISTINCT product_id) AS duplicates
FROM products;
--32,951 rows | 32,951 distinct product ids | 0 duplicates

-- Null scan
-- (Going back and changing product_name_lenght and product_description_lenght to correct spelling 'length'
-- since already changed it to run it again later)
SELECT
    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END) AS null_product_id,
    SUM(CASE WHEN product_category_name IS NULL THEN 1 ELSE 0 END) AS null_category,
    SUM(CASE WHEN product_name_length IS NULL THEN 1 ELSE 0 END) AS null_name_length,
    SUM(CASE WHEN product_description_length IS NULL THEN 1 ELSE 0 END) AS null_description_length,
    SUM(CASE WHEN product_photos_qty IS NULL THEN 1 ELSE 0 END) AS null_photos_qty,
    SUM(CASE WHEN product_weight_g IS NULL THEN 1 ELSE 0 END) AS null_weight,
    SUM(CASE WHEN product_length_cm IS NULL THEN 1 ELSE 0 END) AS null_length,
    SUM(CASE WHEN product_height_cm IS NULL THEN 1 ELSE 0 END) AS null_height,
    SUM(CASE WHEN product_width_cm IS NULL THEN 1 ELSE 0 END) AS null_width
FROM products;
-- null_category: 610 | null_name_length: 610 | null_description_length: 610 
-- null_weight: 2 | null_length: 2 | null_height: 2 | null_width: 2 

-- Distinct categories
SELECT
    COUNT(DISTINCT product_category_name) AS distinct_categories
FROM products;
-- 73 distinct categories

SELECT *
FROM products
WHERE product_category_name IS NULL;
-- 610 rows have NULL category name, description, and photos.
-- Physiccal dimensions exist so products are real but were not categorized. Leaving as Null

SELECT *
FROM products
WHERE product_weight_g IS NULL;

-- Rename misspelled columns
EXEC sp_rename 'products.product_name_lenght', 'product_name_length', 'COLUMN';
EXEC sp_rename 'products.product_description_lenght', 'product_description_length', 'COLUMN';

-- Check
SELECT product_name_length, product_description_length
FROM products;

-- ------------------------------------------------------------------
-- 5B. FINDINGS
-- ------------------------------------------------------------------
/*
- 32,951 rows, 0 duplicates
- 2 misspelled columns (product_name_length & product_description_length)
- 610 rows with null category, name length, description length, and photos
  where products exist and have physical dimensions but were not categorized
- 2 rows with null phyical dimensions, unrecoverable so kept as null
- nulls were not deleted because it would break order analysis
- 73 distinct product categories
- English translation will be added through join
*/


-- ==================================================================
-- SECTION 6: PRODUCT CATEGORY TRANSLATION
-- ==================================================================

-- ------------------------------------------------------------------
-- 6A. AUDIT & TRANSFORMATION
-- ------------------------------------------------------------------

SELECT *
FROM product_category_translation;

-- Row 1 is the column names
EXEC sp_rename 'product_category_translation.column1', 'product_category_name', 'COLUMN';
EXEC sp_rename 'product_category_translation.column2', 'product_category_name_english', 'COLUMN';

-- Delete false header
DELETE FROM product_category_translation
WHERE product_category_name = 'product_category_name';

-- Check
SELECT * FROM product_category_translation;

-- Check for row count and duplicates
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT product_category_name) AS distinct_portuguese,
    COUNT(DISTINCT product_category_name_english) AS distinct_english,
    COUNT(*) - COUNT(DISTINCT product_category_name) AS duplicates
FROM product_category_translation;
-- 71 rows | 71 distinct Portuguese | 71 distinct English | 0 duplicates

-- Null scan
SELECT 
    SUM(CASE WHEN product_category_name IS NULL THEN 1 ELSE 0 END) AS null_portuguese,
    SUM(CASE WHEN product_category_name_english IS NULL THEN 1 ELSE 0 END) AS null_english
FROM product_category_translation;
-- 0 nulls

-- ------------------------------------------------------------------
-- 6B. FINDINGS
-- ------------------------------------------------------------------
/* 
- Headers misimported as data, deleted
- column1 renamed to product_category_name, column2 to product_category_name_english
- 71 rows, 0 nulls, 0 duplicates, ready to use as lookup table
*/


-- ==================================================================
-- SECTION 7: GEOLOCATION
-- ==================================================================

-- ------------------------------------------------------------------
-- 7A. AUDIT
-- ------------------------------------------------------------------
-- Got a warning during import: up to 1,339 cells dropped in geolocation_lat and geolocation_lng
-- Check datatypes
SELECT TOP 10 geolocation_lat, geolocation_lng
FROM geolocation;

SELECT COLUMN_NAME, DATA_TYPE, NUMERIC_PRECISION, NUMERIC_SCALE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'geolocation';

-- Row count, distinct zip codes, null scan
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT geolocation_zip_code_prefix) AS distinct_zip,
    SUM(CASE WHEN geolocation_lat IS NULL THEN 1 ELSE 0 END) AS null_lat,
    SUM(CASE WHEN geolocation_lng IS NULL THEN 1 ELSE 0 END) AS null_lng,
    SUM(CASE WHEN geolocation_city IS NULL THEN 1 ELSE 0 END) AS null_city,
    SUM(CASE WHEN geolocation_state IS NULL THEN 1 ELSE 0 END) AS null_state
FROM geolocation;
-- 1,000,163 rows | 19,015 distinct zips | null_lat: 1,336 | null_lng: 3 | null_city: 0 | null_state: 0

-- How many exact duplicate rows?
SELECT COUNT(*) AS duplicate_rows
FROM (
    SELECT geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state,
    COUNT(*) AS cnt
    FROM geolocation
    GROUP BY geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state
    HAVING COUNT(*) > 1
) AS duplicates;
-- 128,270 duplicate row groups

-- Check null lat rows
SELECT TOP 10 *
FROM geolocation
WHERE geolocation_lat IS NULL;

-- Are the nulls clustered around specific zip codes?
SELECT geolocation_zip_code_prefix, COUNT(*) AS null_count
FROM geolocation
WHERE geolocation_lat IS NULL
GROUP BY geolocation_zip_code_prefix
ORDER BY null_count DESC;

-- I deleted and reuploaded the csv dataset because it doesnt have nulls, but while uploading it caused an issue. 
-- After uploading it, it still gave the warning of losing some data so I will delete it.
SELECT 
    COUNT(*) AS total_rows,
    SUM(CASE WHEN geolocation_lat IS NULL THEN 1 ELSE 0 END) AS null_lat,
    SUM(CASE WHEN geolocation_lng IS NULL THEN 1 ELSE 0 END) AS null_lng
FROM geolocation;

DELETE FROM geolocation
WHERE geolocation_lat IS NULL
    OR geolocation_lng IS NULL;

-- Check
SELECT 
    COUNT(*) AS total_rows,
    SUM(CASE WHEN geolocation_lat IS NULL THEN 1 ELSE 0 END) AS null_lat,
    SUM(CASE WHEN geolocation_lng IS NULL THEN 1 ELSE 0 END) AS null_lng
FROM geolocation;

-- There are 128,146 duplicates.
-- Delete duplicates keepign 1 unique row
WITH CTE AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY geolocation_zip_code_prefix,
                         geolocation_lat,
                         geolocation_lng,
                         geolocation_city,
                         geolocation_state
            ORDER BY (SELECT NULL)
        ) AS row_num
    FROM geolocation
)
DELETE FROM CTE WHERE row_num > 1;

-- Check
SELECT COUNT(*) AS remaining_rows FROM geolocation;

-- Brazil's Latitude: 5.27 to -33.75, Longitude: -34.78 to -73.98
-- Check if lat and lng are correct (in Brazil)
SELECT COUNT(*) AS out_of_bounds
FROM geolocation
WHERE geolocation_lat > 5.27
    OR geolocation_lat < -33.75
    OR geolocation_lng > -34.78
    OR geolocation_lng < -73.98;
-- There are 10 out of bound

-- Fernando de Noronha are accurate but slightly need to measurements to fit the city in.
SELECT *
FROM geolocation
WHERE geolocation_lat > 5.27
    OR geolocation_lat < -34.0
    OR geolocation_lng > -28.0
    OR geolocation_lng < -73.98;

/* Searched 4 rows in Google Maps:
Row 1 shows San Miguel, Argentina
Row 2 shows General Rodriguez, Argentina
Row 3 & 4 show Santa Rosa, Argentina */

-- Delete rows with false data
DELETE FROM geolocation
WHERE geolocation_lat > 5.27
    OR geolocation_lat < -34.0
    OR geolocation_lng > -28.0
    OR geolocation_lng < -73.98;

-- Check
SELECT *
FROM geolocation
WHERE geolocation_lat > 5.27
    OR geolocation_lat < -34.0
    OR geolocation_lng > -28.0
    OR geolocation_lng < -73.98;

-- Count rows
SELECT COUNT(*) AS remaining_rows FROM geolocation;
-- 736,841 rows

SELECT *
FROM geolocation;

SELECT DISTINCT geolocation_city 
FROM geolocation 
ORDER BY geolocation_city;

-- Apply title case to city names
UPDATE geolocation
SET geolocation_city = RTRIM(
    (
        SELECT UPPER(LEFT(value, 1)) + LOWER(SUBSTRING(value, 2, LEN(value))) + ' '
        FROM STRING_SPLIT(geolocation_city, ' ')
        FOR XML PATH('')
    )
)
WHERE geolocation_city IS NOT NULL;

-- There are 7,989 distinct city names including accent variants
-- Left uncorrected as joins use zip code prefix, not city name, no analytical impact

SELECT DISTINCT geolocation_city 
FROM geolocation 
ORDER BY geolocation_city;

-- There are 7989 distinct city names, including the same names just different accents being used.
-- City name accent inconsistencies (ex: Abaete/Abaeté) were left uncorrected as geolocation joins are performed on zip code prefix, not city name. No impact on analytical accuracy.

-- Fix useless characters
UPDATE geolocation
SET geolocation_city = LTRIM(REPLACE(REPLACE(REPLACE(
    geolocation_city, '*', ''), '.', ''), '´', ''))
WHERE geolocation_city LIKE '*%'
    OR geolocation_city LIKE '.%'
    OR geolocation_city LIKE '´%';

-- Check they are gone
SELECT DISTINCT geolocation_city
FROM geolocation
WHERE geolocation_city LIKE '*%'
    OR geolocation_city LIKE '.%'
    OR geolocation_city LIKE '´%';
-- 0 rows

-- Fix the number city names
UPDATE geolocation
SET geolocation_city = 'Centenario'
WHERE geolocation_city IN ('4º Centenario', '4o. Centenario');

-- Fix capitalization after hyphen
UPDATE geolocation
SET geolocation_city = STUFF(
    geolocation_city,
    CHARINDEX('-', geolocation_city) + 1,
    1,
    UPPER(SUBSTRING(geolocation_city, CHARINDEX('-', geolocation_city) + 1, 1))
)
WHERE CHARINDEX('-', geolocation_city) > 0;

-- Check hyphenated cities look right
SELECT DISTINCT geolocation_city
FROM geolocation
WHERE geolocation_city LIKE '%-%'
ORDER BY geolocation_city;

-- ------------------------------------------------------------------
-- 7B. FINDINGS
-- ------------------------------------------------------------------
/*
- 1,000,163 rows, 19,015 distinct zip codes
- 1,336 null lat/lng rows deleted 
- 261,982 exact duplicate rows deleted
- 4 rows deleted, found coordinates in Google Maps to be in Argentina not Brazil
- Fernando de Noronha island was a bit out of territory, but kept it and lat/lng adjusted
- Applied title casing to city names, additionally to post-hyphen 
- Corrected city Centenario
- Left the city names with accents since joins are based on zip code
- 736,841 clean rows remaining 
*/


-- ==================================================================
-- SECTION 8: ORDER PAYMENTS
-- ==================================================================

-- ------------------------------------------------------------------
-- 8A. AUDIT
-- ------------------------------------------------------------------
SELECT *
FROM order_payments;

-- Row count and duplicates
-- Primary key is a combination of order_id and payment_sequential
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(DISTINCT CONCAT(order_id, payment_sequential)) AS distinct_composite,
    COUNT(*) - COUNT(DISTINCT CONCAT(order_id, payment_sequential)) AS duplicates
FROM order_payments;
-- 103,886 rows | 99,440 distinct orders | 103,886 distinct composite key | 0 duplicates

-- Null scan
SELECT
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN payment_sequential IS NULL THEN 1 ELSE 0 END) AS null_sequential,
    SUM(CASE WHEN payment_type IS NULL THEN 1 ELSE 0 END) AS null_payment_type,
    SUM(CASE WHEN payment_installments IS NULL THEN 1 ELSE 0 END) AS null_installments,
    SUM(CASE WHEN payment_value IS NULL THEN 1 ELSE 0 END) AS null_payment_value
FROM order_payments;
-- 0 nulls

-- Payment type
SELECT payment_type, COUNT(*) AS total
FROM order_payments
GROUP BY payment_type
ORDER BY total DESC;
-- credit_card: 76,795 | boleto: 19,784 | voucher: 5,775 | debit_card: 1,529 | not_defined: 3

-- Payment value check
SELECT
    SUM(CASE WHEN payment_value <= 0 THEN 1 ELSE 0 END) AS zero_or_negative_payments,
    MIN(payment_value) AS min_value,
    MAX(payment_value) AS max_value
FROM order_payments;
-- 9 zero value payments | min: 0 | max: 13,664.08

-- Check 3 not_defined rows
SELECT *
FROM order_payments
WHERE payment_type = 'not_defined';
-- all 3 have payment_value = 0, leaving as is

-- Check zero value payments
SELECT *
FROM order_payments
WHERE payment_value = 0;
-- 9 rows leaving as is (3 not_defined rows, 6 zero value)

-- ------------------------------------------------------------------
-- 8B. FINDINGS
-- ------------------------------------------------------------------
/*
- 103,886 rows, clean composite primary key (order_id, payment_sequential), 0 duplicates
- 99,440 distinct orders , 0 nulls
- 4 payment types, most common is credit card at 76,795
- 3 not_defined rows all have 0 value, unrecoverable, kept as is
- 9 zero value payments: 3 not_defined, 6 vouchers (possible full discounts), kept as is
- No transformation needed
*/


-- ==================================================================
-- SECTION 9: ORDER REVIEWS
-- ==================================================================

SELECT *
FROM order_reviews;

-- ------------------------------------------------------------------
-- 9A. AUDIT
-- ------------------------------------------------------------------
-- Row count and duplicates
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT review_id) AS distinct_review_ids,
    COUNT(DISTINCT order_id) AS distinct_orders,
    COUNT(*) - COUNT(DISTINCT review_id) AS duplicates
FROM order_reviews;
-- 99,224 rows | 98,410 distinct review_ids | 98,673 distinct orders | 814 duplicates

-- Null scan
SELECT
    SUM(CASE WHEN review_id IS NULL THEN 1 ELSE 0 END) AS null_review_id,
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END) AS null_order_id,
    SUM(CASE WHEN review_score IS NULL THEN 1 ELSE 0 END) AS null_score,
    SUM(CASE WHEN review_comment_title IS NULL THEN 1 ELSE 0 END) AS null_title,
    SUM(CASE WHEN review_comment_message IS NULL THEN 1 ELSE 0 END) AS null_message,
    SUM(CASE WHEN review_creation_date IS NULL THEN 1 ELSE 0 END) AS null_creation_date,
    SUM(CASE WHEN review_answer_timestamp IS NULL THEN 1 ELSE 0 END) AS null_timestamp
FROM order_reviews;
-- null_title: 87,658 | null_message: 58,256 | others: 0
-- title and message nulls are expected, customers often skip writing comments

-- Score distribution
SELECT review_score, COUNT(*) AS total
FROM order_reviews
GROUP BY review_score
ORDER BY total DESC;
-- scores only 1-5, no invalid values
-- 5: 57,328 | 4: 19,142 | 1: 11,424 | 3: 8,179 | 2: 3,151

-- Duplicate review_ids on different orders
SELECT review_id, COUNT(DISTINCT order_id) AS distinct_orders
FROM order_reviews
GROUP BY review_id
HAVING COUNT(DISTINCT order_id) > 1;
-- 789 review_ids each linked to 2 different order_ids

-- Look into the 1st duplicate to check pattern
SELECT *
FROM order_reviews
WHERE review_id = '00130cbe1f9d422698c812ed8ded1919'
ORDER BY order_id;

-- Check 2nd duplicate
SELECT *
FROM order_reviews
WHERE review_id = '0115633a9c298b6a98bcbe4eee75345f'
ORDER BY order_id;
-- There are duplicates which have everything except order_id
-- Order_id is what order_reviews are joined to orders dataset so it is important to keep the accurate version

-- Check if both order_ids exist in the orders table
SELECT r.review_id, r.order_id,
    CASE WHEN o.order_id IS NOT NULL THEN 'EXISTS' ELSE 'NOT FOUND' END AS in_orders_table
FROM order_reviews r
LEFT JOIN orders o ON r.order_id = o.order_id
WHERE r.review_id = '00130cbe1f9d422698c812ed8ded1919';
-- Both exist in orders table

-- Check order details to see if one is more likely correct
SELECT r.review_id, r.order_id, o.order_status, o.order_purchase_timestamp
FROM order_reviews r
JOIN orders o ON r.order_id = o.order_id
WHERE r.review_id = '00130cbe1f9d422698c812ed8ded1919';
-- Both order_ids valid, both delivered, purchased 2 seconds apart
-- Likely same customer placing duplicate order

-- Check if either order already has multiple reviews
SELECT order_id, COUNT(*) AS review_count
FROM order_reviews
WHERE order_id IN (
    '04a28263e085d399c97ae49e0b477efa',
    'dfcdfc43867d1c1381bfaf62d6b9c195'
)
GROUP BY order_id;
-- Each order has exactly 1 review so cannot determine correct order_id. Kept all rows.

-- ------------------------------------------------------------------
-- 9B. FINDINGS
-- ------------------------------------------------------------------
/*
- 99,224 rows, 98,410 distinct review ids, 814 duplicates
- null_title: 87,658; null_message: 58,256; others: 0
- Title and message nulls expected, customers skip comments
- Scores valid, range 1-5, score 5 most common (57,328)
- 814 review_ids each linked to 2 valid order_ids
- Both order_ids exist in orders table, both delivered, purchased 2 seconds apart
- Each order has exactly 1 review, cannot determine correct order_id
- Source system bug, keeping all rows
- May cause double counting when joining reviews to orders
- No transformation applied
*/


-- ==================================================================
-- SECTION 10: ANALYSIS
-- ==================================================================

-- ------------------------------------------------------------------
-- 10A. JOIN TABLES (orders is the central table)
-- ------------------------------------------------------------------

-- Note: changed all JOINs to LEFT JOIN after verification showed (the proccess moved into comments for future accurate runs)
-- 775 orders were being dropped due to no matching order_items
-- LEFT JOIN shows all 99,441 orders

/*
CREATE VIEW olist_orders AS
SELECT

    -- Orders
    o.order_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    -- Customers
    c.customer_id,
    c.customer_unique_id,
    c.customer_zip_code_prefix,
    c.customer_city,
    c.customer_state,
    
    -- Order Items
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    oi.shipping_limit_date,
    oi.price,
    oi.freight_value,

    -- Products
    p.product_category_name,
    t.product_category_name_english,
    p.product_name_length,
    p.product_description_length,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,

    -- Sellers
    s.seller_zip_code_prefix,
    s.seller_city,
    s.seller_state,

    -- Order Payments
    op.payment_type,
    op.payment_installments,
    op.payment_value,

    -- Order Reviews
    r.review_id,
    r.review_score,
    r.review_comment_title,
    r.review_comment_message,
    r.review_creation_date,
    r.review_answer_timestamp

FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN sellers s ON oi.seller_id = s.seller_id
LEFT JOIN product_category_translation t ON p.product_category_name = t.product_category_name
LEFT JOIN order_payments op ON o.order_id = op.order_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id;

-- Check
SELECT TOP 20 * FROM olist_orders;
-- Tables were joined together

-- Row count
SELECT COUNT(*) AS total_rows FROM olist_orders;
-- 118,310 rows

-- Check 1: Order count should match original 99,441 rows table
SELECT COUNT(DISTINCT order_id) AS distinct_orders FROM olist_orders;
-- 98,666 rows (775  missing)

-- Check 2: Customer count should match original 99,441 rows table
SELECT COUNT(DISTINCT customer_id) AS distinct_customers FROM olist_orders;
-- 98,666 rows (775  missing)

-- Check 3: Check revenue total
SELECT ROUND(SUM(payment_value), 2) AS total_revenue FROM olist_orders;
-- 20,416,842.54

-- Check 4: Check if English names are working
SELECT DISTINCT product_category_name, product_category_name_english
FROM olist_orders
WHERE product_category_name IS NOT NULL
ORDER BY product_category_name;
-- 73 rows

-- Check 5: Check if all order statuses are present
SELECT order_status, COUNT(DISTINCT order_id) AS total
FROM olist_orders
GROUP BY order_status
ORDER BY total DESC;
-- delivered: 96,478 | shipped: 1,106 | canceled: 461 | invoiced: 312 | processing: 301 | unavailable: 6 | aproved: 2

-- Fing orders that exist in orders table but not in order_tems
SELECT COUNT(*) AS orders_missing_items
FROM orders o
WHERE NOT EXISTS (
    SELECT 1 FROM order_items oi WHERE oi.order_id = o.order_id
);
-- 775 missing orders

-- 775 orders have no matching items in order_items causing them to be dropped by a JOIN
-- I will run a LEFT JOIN on it

DROP VIEW olist_orders;
*/

CREATE VIEW olist_orders AS
SELECT

    -- Orders
    o.order_id,
    o.order_status,
    o.order_purchase_timestamp,
    o.order_approved_at,
    o.order_delivered_carrier_date,
    o.order_delivered_customer_date,
    o.order_estimated_delivery_date,

    -- Customers
    c.customer_id,
    c.customer_unique_id,
    c.customer_zip_code_prefix,
    c.customer_city,
    c.customer_state,
    
    -- Order Items
    oi.order_item_id,
    oi.product_id,
    oi.seller_id,
    oi.shipping_limit_date,
    oi.price,
    oi.freight_value,

    -- Products
    p.product_category_name,
    t.product_category_name_english,
    p.product_name_length,
    p.product_description_length,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,

    -- Sellers
    s.seller_zip_code_prefix,
    s.seller_city,
    s.seller_state,

    -- Order Payments
    op.payment_type,
    op.payment_installments,
    op.payment_value,

    -- Order Reviews
    r.review_id,
    r.review_score,
    r.review_comment_title,
    r.review_comment_message,
    r.review_creation_date,
    r.review_answer_timestamp

FROM orders o
LEFT JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN order_items oi ON o.order_id = oi.order_id
LEFT JOIN products p ON oi.product_id = p.product_id
LEFT JOIN sellers s ON oi.seller_id = s.seller_id
LEFT JOIN product_category_translation t ON p.product_category_name = t.product_category_name
LEFT JOIN order_payments op ON o.order_id = op.order_id
LEFT JOIN order_reviews r ON o.order_id = r.order_id;


-- Check
SELECT TOP 20 * FROM olist_orders;
-- Joins worked, everything looks good

-- Row count
SELECT COUNT(*) AS total_rows FROM olist_orders;
-- 119,143 rows

-- Check 1: Order count should match original 99,441 rows table
SELECT COUNT(DISTINCT order_id) AS distinct_orders FROM olist_orders;
-- 99,441 rows

-- Check 2: Customer count should match original 99,441 rows table
SELECT COUNT(DISTINCT customer_id) AS distinct_customers FROM olist_orders;
-- 99,441 rows

-- Check 3: Check revenue total
SELECT ROUND(SUM(payment_value), 2) AS total_revenue FROM olist_orders;
-- 20,579,664.01

-- Check 4: Check if English names are working
SELECT DISTINCT product_category_name, product_category_name_english
FROM olist_orders
WHERE product_category_name IS NOT NULL
ORDER BY product_category_name;
-- 73 rows

-- Check 5: Check if all order statuses are present
SELECT order_status, COUNT(DISTINCT order_id) AS total
FROM olist_orders
GROUP BY order_status
ORDER BY total DESC;
-- delivered: 96,478 | shipped: 1,107 | canceled: 625 | unavailable: 609 | invoiced: 314
-- processing: 301 | created: 5 | approved: 2

-- ------------------------------------------------------------------
-- 10B. KPI
-- ------------------------------------------------------------------

-- Top 10 Product Categories by Revenue
SELECT TOP 10
    product_category_name_english AS category,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(payment_value), 2) AS total_revenue,
    ROUND(AVG(payment_value), 2) AS avg_order_value
FROM olist_orders
WHERE product_category_name_english IS NOT NULL
AND order_status = 'delivered'
GROUP BY product_category_name_english
ORDER BY total_revenue DESC;
-- Bed bath table leads by total revenue, wacthes/gifts has highest average order value at $228.52


-- Average Delivery Time In Days
SELECT 
    ROUND(AVG(DATEDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date)), 1) AS avg_delivery_days,
    ROUND(MIN(DATEDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date)), 1) AS min_delivery_days,
    ROUND(MAX(DATEDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date)), 1) AS max_delivery_days
FROM olist_orders
WHERE order_status = 'delivered'
AND order_delivered_customer_date IS NOT NULL;
-- avg_delivery_days: 12 | min_delivery_days: 0 | max_delivery_days: 210


-- On-Time vs Late Delivery Rate
SELECT
    COUNT(*) AS total_delivered,
    SUM(CASE WHEN order_delivered_customer_date <= order_estimated_delivery_date
        THEN 1 ELSE 0 END) AS on_time,
    SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date
        THEN 1 ELSE 0 END) AS late,
    ROUND(100.0 * SUM(CASE WHEN order_delivered_customer_date <= order_estimated_delivery_date
        THEN 1 ELSE 0 END) / COUNT(*), 1) AS on_time_percentage,
    ROUND(100.0 * SUM(CASE WHEN order_delivered_customer_date > order_estimated_delivery_date
        THEN 1 ELSE 0 END) / COUNT(*), 1) AS late_percentage
FROM olist_orders
WHERE order_status = 'delivered'
AND order_delivered_customer_date IS NOT NULL
AND order_estimated_delivery_date IS NOT NULL;
-- 115,715 total delivered | on time: 106,648 | late: 9,067 | on time: 92.2% | late: 7.8%
-- 92% on-time delivery rate out of 115,715 delivered orders is good.


-- Top 10 Sellers by Revenue
SELECT TOP 10
    seller_id,
    seller_city,
    seller_state,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(payment_value), 2) AS total_revenue
FROM olist_orders
WHERE order_status = 'delivered'
AND seller_id IS NOT NULL
GROUP BY seller_id, seller_city, seller_state
ORDER BY total_revenue DESC;
-- Sao Paulo has 9/10 top sellers
-- Seller 3 has the most orders (at 1,772), while it's ranked 3rd in revenue.
-- Seller 1 has fewer orders (973) but highest revenue (has higher value items).


-- Average Review Score by Product Category
SELECT TOP 10
    product_category_name_english AS category,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(AVG(CAST(review_score AS FLOAT)), 2) AS avg_review_score
FROM olist_orders
WHERE product_category_name_english IS NOT NULL
AND review_score IS NOT NULL
GROUP BY product_category_name_english
ORDER BY avg_review_score DESC;
-- 4.64/5 review score is great for cds_dvds_musicals but with only 12 total orders so not as reliable.
-- Books and luggage are more meaningful since have hundreds of orders. 


-- Monthly Orders Over Time
SELECT
    FORMAT(order_purchase_timestamp, 'yyyy-MM') AS order_month,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(payment_value), 2) AS monthly_revenue
FROM olist_orders
WHERE order_purchase_timestamp IS NOT NULL
GROUP BY FORMAT(order_purchase_timestamp, 'yyyy-MM')
ORDER BY order_month;
-- Sep-Dec 2016 had nearly zero orders (1-324), showing Olist's early launch phase.
-- Strong growth throughout 2017, peaking in Nov 2017 at 7,544 orders and $1.6M revenue.
-- 2018 stabilized around 6,000-7,000 orders/month with consistently high revenue.
-- Sep-Oct 2018 drop to 16 then to 4 orders.

SELECT MAX(order_purchase_timestamp) AS latest_order
FROM olist_orders;
-- Sep-Oct 2018 drop to 16 then to 4 orders because the dataset ends on Oct 17, 2018,
-- meaning both months are incomplete and not representative of actual volume.