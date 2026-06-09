# Olist E-Commerce Data Cleaning - SQL

An SQL data cleaning and preparation project using the [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce/data) from Kaggle. The goal was to clean, standardize, and join 8 relational tables into a single analysis-ready view for BI reporting.

--- 

## Dataset Summary
- **Source:** [Kaggle - Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce/data)
- **Period:** 2016-2018
- **Data:** ~100,000 orders across Brazilian marketplaces
- **Tables:** 9 (customers, orders, order items, order payments, order reviews, products, sellers, geolocation, product category translation)

---

## Cleaning Steps by Table

### Customers (`customers`)
- 99,441 rows, 0 nulls, 0 duplicates
- Applied title case to `customer_city` and capitalized characters after hyphens and apostrophes (Example: `d'ajuda` to `D'Ajuda`).

### Order Items (`order_items`)
- 112,650 rows with a composite primary key on `(order_id, order_item_id)`
- 0 nulls, 0 duplicates
- 383 zero-freight rows were kept as they likely represent free shipping

### Orders (`orders`)
- 99,441 rows, 0 duplicates, clean date logic with no impossible sequences
- 160 null `order_approved_at` values: 141 canceled (expected), 14 delivered (flagged as anomaly), 5 created
- 2,965 null delivery dates are expected for undelivered orders
- 8 delivered orders missing a delivery date were flagged as a real data anomaly. No transformations applied.

### Sellers (`sellers`)
- 3,095 rows, 0 nulls, 0 duplicates
- `seller_city` had extensive issues and required the most cleaning
- Removed city/state combinations split by `/`, `\`, and `,`
- Removed parenthetical neighborhoods (Example: `Arraial d'Ajuda (Porto Seguro)` to `Arraial D'Ajuda`)
- Set unrecoverable values (a phone number and an email address) to NULL
- Replaced HTML-encoded spaces (`&#x20;`)
- Removed trailing state abbreviations from 4 cities (Example: `Sao Paulo Sp` to `Sao Paulo`)
- Applied title case and capitalized characters after apostrophes

### Products (`products`)
- 32,951 rows, 0 duplicates
- Two misspelled column names were corrected: `product_name_lenght` to `product_name_length` and `product_description_lenght` to `product_description_length`
- 610 rows had null category, name length, description, and photo count but had physical dimensions, meaning the products are real but were never categorized. These were kept as NULL rather than deleted to avoid breaking order analysis.
- 2 rows with null physical dimensions were also kept for the same reason
- 73 distinct product categories.

### Product Category Translation (`product_category_tranlsation`)
- 71 rows after cleanup
- Column headers had been imported as a data row and were deleted
- `column1` and `column2` were renamed to `product_category_name` and `product_category_name_english`
- Used as a lookup table in the final view to bring in English category names.

### Geolocation (`geolocation`)
- Started with 1,000,163 rows, ended with 736,841 after cleaning
- 1,336 rows with null lat/lng were deleted (caused by an import encoding issue)
- 261,982 exact duplicate rows were removed using a `ROW_NUMBER()` CTE
- 4 rows with coordinates that mapped to Argentina were deleted after checking in Google Maps
- Brazil's bounding box was used to check bounds (lat 5.27 to -34.0, lng -28.0 to -73.98), with Fernando de Noronha island kept after adjusting the boundary slightly
- Applied title case to city names, along with capitalization after hyphens
- Geolocation was cleaned as a standalone reference table and not joined into the final view. Customer and seller city/state data were already available through their respective tables. Geolocation could be joined in the future if lat/lng coordinates are needed for geographic analysis.

### Order Payments (`order_payments`)
- 103,886 rows with a composite primary key on `(order_id, payment_sequential)`
- 0 nulls, 0 duplicates
- 4 payment types: credit card (76,795), boleto (19,784), voucher (5,775), debit card (1,529)
- 3 rows with `not_defined` payment type all had a value of $0 and were kept as unrecoverable
- 9 zero-value payments were also kept (3 not_defined, 6 vouchers likely representing full discounts)
- No transformations applied

### Order Reviews (`order_reviews`)
- 99,224 rows
- 87,658 null titles and 58,256 null messages are expected since customers often skip writing comments
- Review scores are valid, range 1-5, with 5 being most common (57,328)
- 814 review IDs were each linked to 2 different `order_id` values. Both order IDs exist in the orders table, both were delivered, and each order already has 1 review, so there was no way to tell which one is correct. Kept all rows as a source system bug. May cause double counting when joining two orders.

---

## Final View: olist_orders

All 8 tables are joined using `LEFT JOIN` with `orders` as the central table. An initial `INNER JOIN` approach dropped 775 orders that had no matching rows in `order_items`. Switching to `LEFT JOIN` kept all 99,441 orders.

- **Total rows in view:** 119,143 (due to many relationships across payments, items, and reviews)
- **Distinct orders:** 99,441
- **Total revenue:** $20,579,664.01

---

## Analysis Queries

| Query | Finding |
|---|---|
| Top 10 categories by revenue | Bed, bath & table leads overall; watches & gifts has the highest average order value at $228.52 |
| Average delivery time | 12 days on average, range 0-210 days |
| On-time delivery rate | 92.2% on time (106,648 out of 115,715 delivered orders) |
| Top 10 sellers by revenue | 9 out of 10 are based in São Paulo |
| Review scores by category | CDs/DVDs/musicals scored 4.64/5 but only had 12 orders, making it unreliable |
| Monthly orders over time | Peak was November 2017 at 7,544 orders and $1.6M revenue. September and October 2018 appear to drop sharply but the dataset ends October 17, 2018, so both months are incomplete |

---

## Known Data Issues

| Table | Issue | Action Taken |
|---|---|---|
| orders | 8 delivered orders missing a delivery date | Flagged, kept |
| orders | 14 delivered orders missing approval timestamp | Flagged, kept |
| geolocation | Import truncated some lat/lng values to NULL | Deleted affected rows |
| order_reviews | 814 review IDs each linked to 2 order IDs | Kept all rows, source system bug |
| sellers | Unrecoverable city values (number, email address) | Set to NULL |

---

## Tools & Environment

- **Database:** Microsoft SQL Server
- **Language:** SQL
- **Functions used:** `STRING_SPLIT`, `FOR XML PATH`, `STUFF`, `CHARINDEX`, `ROW_NUMBER()`, `DATEDIFF`, `FORMAT`, `sp_rename`, CTEs, window functions
