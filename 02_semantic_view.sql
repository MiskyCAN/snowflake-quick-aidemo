-- ============================================================
-- SNOWFLAKE AI DEMO — RETAIL SALES
-- File 02: Semantic View DDL with inline synonyms and comments
-- Run AFTER 01_setup.sql.
-- ============================================================

USE WAREHOUSE RETAIL_DEMO_WH;
USE DATABASE  RETAIL_DEMO;
USE SCHEMA    RETAIL_DEMO.MODELS;


CREATE OR REPLACE SEMANTIC VIEW RETAIL_DEMO.MODELS.RETAIL_SALES_SV

  TABLES (
    sales AS RETAIL_DEMO.SALES.VW_SALES_ENRICHED PRIMARY KEY (SALE_ID)
      COMMENT = 'One row per sale transaction across all stores, products, channels and customers'
  )

  FACTS (
    sales.NET_REVENUE      AS net_revenue
      COMMENT = 'Unit price x quantity x (1 - discount%). Use this as the basis for revenue metrics',
    sales.GROSS_REVENUE    AS gross_revenue
      COMMENT = 'Unit price x quantity before discounts',
    sales.GROSS_MARGIN     AS gross_margin
      COMMENT = '(Unit price - unit cost) x quantity',
    sales.MARGIN_PCT       AS margin_pct
      COMMENT = 'Gross margin as a percentage of selling price',
    sales.QUANTITY         AS quantity
      COMMENT = 'Number of units sold in the transaction',
    sales.DISCOUNT_PCT     AS discount_pct
      COMMENT = 'Discount percentage applied, 0-100',
    sales.UNIT_PRICE       AS unit_price
      COMMENT = 'Actual selling price per unit'
  )

  DIMENSIONS (
    sales.SALE_DATE        AS sale_date
      WITH SYNONYMS = ('transaction date', 'order date', 'purchase date', 'date of sale')
      COMMENT = 'Date the sale transaction occurred',
    sales.SALE_MONTH       AS sale_month
      WITH SYNONYMS = ('month', 'monthly')
      COMMENT = 'Sale date truncated to the first of the month',
    sales.SALE_QUARTER     AS sale_quarter
      WITH SYNONYMS = ('quarter', 'quarterly', 'Q1', 'Q2', 'Q3', 'Q4')
      COMMENT = 'Sale date truncated to the first day of the quarter',
    sales.SALE_YEAR        AS sale_year
      WITH SYNONYMS = ('year', 'annually', 'fiscal year')
      COMMENT = 'Calendar year of the sale',
    sales.PRODUCT_NAME     AS product_name
      WITH SYNONYMS = ('product', 'item', 'SKU', 'goods')
      COMMENT = 'Name of the product sold',
    sales.CATEGORY         AS category
      WITH SYNONYMS = ('product category', 'department', 'product type', 'product group')
      COMMENT = 'Product category: Electronics, Apparel, Home & Garden, Sports, Beauty',
    sales.BRAND            AS brand
      WITH SYNONYMS = ('brand name', 'manufacturer', 'label', 'make')
      COMMENT = 'Product brand',
    sales.STORE_NAME       AS store_name
      WITH SYNONYMS = ('store', 'location', 'retail location', 'shop', 'branch')
      COMMENT = 'Name of the retail store',
    sales.CITY             AS city
      WITH SYNONYMS = ('municipality', 'town')
      COMMENT = 'City where the store is located',
    sales.PROVINCE         AS province
      WITH SYNONYMS = ('state', 'territory')
      COMMENT = 'Canadian province where the store is located',
    sales.REGION           AS region
      WITH SYNONYMS = ('territory', 'sales region', 'geographic region', 'area')
      COMMENT = 'Geographic region: West, Central, or East',
    sales.CHANNEL          AS channel
      WITH SYNONYMS = ('sales channel', 'purchase channel', 'how they bought', 'channel type')
      COMMENT = 'How the sale was made: In-Store, Online, or Mobile',
    sales.CUSTOMER_NAME    AS customer_name
      WITH SYNONYMS = ('customer', 'buyer', 'shopper', 'client')
      COMMENT = 'Full name of the purchasing customer',
    sales.CUSTOMER_SEGMENT AS customer_segment
      WITH SYNONYMS = ('segment', 'tier', 'loyalty tier', 'customer tier', 'membership')
      COMMENT = 'Customer classification: Loyalty, Standard, or New'
  )

  METRICS (
    total_net_revenue      AS SUM(sales.net_revenue)
      WITH SYNONYMS = ('revenue', 'net revenue', 'sales', 'net sales', 'total sales', 'income', 'turnover')
      COMMENT = 'Total net revenue after discounts. Primary revenue metric.',
    total_gross_revenue    AS SUM(sales.gross_revenue)
      WITH SYNONYMS = ('gross revenue', 'gross sales', 'revenue before discounts')
      COMMENT = 'Total revenue before discounts are applied',
    total_gross_margin     AS SUM(sales.gross_margin)
      WITH SYNONYMS = ('margin', 'gross margin', 'profit', 'gross profit', 'total margin')
      COMMENT = 'Total gross profit across all transactions',
    avg_margin_pct         AS AVG(sales.margin_pct)
      WITH SYNONYMS = ('margin percentage', 'margin %', 'profit margin', 'margin rate')
      COMMENT = 'Average gross margin as a percentage of selling price',
    units_sold             AS SUM(sales.quantity)
      WITH SYNONYMS = ('quantity sold', 'items sold', 'units', 'volume', 'total units')
      COMMENT = 'Total number of units sold',
    avg_order_value        AS AVG(sales.net_revenue)
      WITH SYNONYMS = ('AOV', 'average basket', 'average transaction value', 'average sale value', 'basket size')
      COMMENT = 'Average net revenue per transaction',
    avg_discount_pct       AS AVG(sales.discount_pct)
      WITH SYNONYMS = ('average discount', 'discount rate', 'average discount percentage')
      COMMENT = 'Average discount percentage applied across transactions'
  )

  COMMENT = 'Retail sales semantic view — 18 months, 8 Canadian stores, 15 products,
             5 categories, 3 channels. Primary view for Cortex Analyst NL queries.';


-- ── Verify ───────────────────────────────────────────────────
SHOW SEMANTIC VIEWS IN SCHEMA RETAIL_DEMO.MODELS;


-- ── Validation query 1: revenue + margin by category ────────
SELECT *
FROM SEMANTIC_VIEW(
    RETAIL_DEMO.MODELS.RETAIL_SALES_SV
    METRICS    total_net_revenue,
               avg_margin_pct
    DIMENSIONS category
)
ORDER BY total_net_revenue DESC;
-- Expected: 5 rows, one per product category.


-- ── Validation query 2: revenue by channel and month ────────
SELECT *
FROM SEMANTIC_VIEW(
    RETAIL_DEMO.MODELS.RETAIL_SALES_SV
    METRICS    total_net_revenue,
               units_sold
    DIMENSIONS sale_month,
               channel
)
ORDER BY sale_month, channel;


-- ── Grants ───────────────────────────────────────────────────
-- Only needed if running under a role other than ACCOUNTADMIN.
-- Replace DEMO_ROLE with your actual role name.
-- GRANT USAGE ON DATABASE  RETAIL_DEMO        TO ROLE DEMO_ROLE;
-- GRANT USAGE ON SCHEMA    RETAIL_DEMO.MODELS TO ROLE DEMO_ROLE;
-- GRANT SELECT ON SEMANTIC VIEW RETAIL_DEMO.MODELS.RETAIL_SALES_SV TO ROLE DEMO_ROLE;
-- GRANT USAGE ON WAREHOUSE RETAIL_DEMO_WH     TO ROLE DEMO_ROLE;
-- GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER   TO ROLE DEMO_ROLE;

