-- ============================================================
-- SNOWFLAKE AI DEMO — RETAIL SALES
-- File 01: Full environment setup — run top to bottom once
-- Creates: warehouse, DB, schemas, all tables, all seed data,
--          enriched view, CUSTOMER_FEEDBACK, CALL_TRANSCRIPTS
-- ============================================================

-- ── 1. Environment ──────────────────────────────────────────
CREATE DATABASE IF NOT EXISTS RETAIL_DEMO;
CREATE SCHEMA  IF NOT EXISTS RETAIL_DEMO.SALES;
CREATE SCHEMA  IF NOT EXISTS RETAIL_DEMO.MODELS;
CREATE SCHEMA  IF NOT EXISTS RETAIL_DEMO.DOCS;

CREATE WAREHOUSE IF NOT EXISTS RETAIL_DEMO_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND   = 60
    AUTO_RESUME    = TRUE
    COMMENT        = 'Demo warehouse — suspends after 60s idle';

USE WAREHOUSE RETAIL_DEMO_WH;
USE DATABASE  RETAIL_DEMO;
USE SCHEMA    RETAIL_DEMO.SALES;


-- ── 2. Dimension tables ──────────────────────────────────────
CREATE OR REPLACE TABLE DIM_PRODUCT (
    PRODUCT_ID    NUMBER        PRIMARY KEY,
    PRODUCT_NAME  VARCHAR(100)  NOT NULL,
    CATEGORY      VARCHAR(50)   NOT NULL,
    BRAND         VARCHAR(50),
    UNIT_COST     NUMBER(10,2)  NOT NULL
);

CREATE OR REPLACE TABLE DIM_STORE (
    STORE_ID      NUMBER        PRIMARY KEY,
    STORE_NAME    VARCHAR(100)  NOT NULL,
    CITY          VARCHAR(60)   NOT NULL,
    PROVINCE      VARCHAR(40)   NOT NULL,
    REGION        VARCHAR(20)   NOT NULL
);

CREATE OR REPLACE TABLE DIM_CUSTOMER (
    CUSTOMER_ID   NUMBER        PRIMARY KEY,
    FULL_NAME     VARCHAR(100)  NOT NULL,
    SEGMENT       VARCHAR(30)   NOT NULL,
    EMAIL         VARCHAR(120)
);


-- ── 3. Fact table ────────────────────────────────────────────
CREATE OR REPLACE TABLE FACT_SALES (
    SALE_ID       NUMBER        PRIMARY KEY AUTOINCREMENT,
    SALE_DATE     DATE          NOT NULL,
    PRODUCT_ID    NUMBER        REFERENCES DIM_PRODUCT(PRODUCT_ID),
    STORE_ID      NUMBER        REFERENCES DIM_STORE(STORE_ID),
    CUSTOMER_ID   NUMBER        REFERENCES DIM_CUSTOMER(CUSTOMER_ID),
    QUANTITY      NUMBER        NOT NULL,
    UNIT_PRICE    NUMBER(10,2)  NOT NULL,
    DISCOUNT_PCT  NUMBER(5,2)   DEFAULT 0,
    CHANNEL       VARCHAR(20)   NOT NULL
);


-- ── 4. Unstructured tables ───────────────────────────────────
CREATE OR REPLACE TABLE CUSTOMER_FEEDBACK (
    FEEDBACK_ID   NUMBER PRIMARY KEY AUTOINCREMENT,
    CUSTOMER_ID   NUMBER,
    STORE_ID      NUMBER,
    FEEDBACK_DATE DATE,
    CHANNEL       VARCHAR(20),
    FEEDBACK_TEXT VARCHAR(2000)
);

CREATE OR REPLACE TABLE CALL_TRANSCRIPTS (
    TRANSCRIPT_ID  NUMBER PRIMARY KEY AUTOINCREMENT,
    CALL_DATE      DATE,
    STORE_ID       NUMBER,
    CUSTOMER_ID    NUMBER,
    AGENT_NAME     VARCHAR(60),
    CALL_TYPE      VARCHAR(40),
    BODY_TEXT      VARCHAR(4000)
);


-- ── 5. Seed data — products ──────────────────────────────────
INSERT INTO DIM_PRODUCT VALUES
    (1,  'UltraPhone X12',       'Electronics',  'TechNova',   420.00),
    (2,  'SmartWatch Pro',       'Electronics',  'TechNova',   180.00),
    (3,  'Wireless Earbuds',     'Electronics',  'SoundPeak',   55.00),
    (4,  'Laptop Slim 14',       'Electronics',  'TechNova',   700.00),
    (5,  'Yoga Pants Elite',     'Apparel',      'ActiveWear',  28.00),
    (6,  'Trail Runner Jacket',  'Apparel',      'ActiveWear',  52.00),
    (7,  'Classic Tee 3-Pack',   'Apparel',      'BasicCo',     12.00),
    (8,  'Espresso Maker Pro',   'Home & Garden','BrewMaster',  95.00),
    (9,  'Air Purifier 360',     'Home & Garden','CleanAir',   140.00),
    (10, 'Garden Tool Set',      'Home & Garden','GreenThumb',  35.00),
    (11, 'Foam Roller Set',      'Sports',       'FlexFit',     22.00),
    (12, 'Resistance Bands Kit', 'Sports',       'FlexFit',     14.00),
    (13, 'Moisturizer SPF 50',   'Beauty',       'GlowLab',     18.00),
    (14, 'Vitamin C Serum',      'Beauty',       'GlowLab',     24.00),
    (15, 'Smart Home Hub',       'Electronics',  'ConnectX',   110.00);


-- ── 6. Seed data — stores ────────────────────────────────────
INSERT INTO DIM_STORE VALUES
    (1, 'Vancouver Downtown',  'Vancouver',  'British Columbia', 'West'),
    (2, 'Calgary Centre',      'Calgary',    'Alberta',         'West'),
    (3, 'Edmonton Whyte Ave',  'Edmonton',   'Alberta',         'West'),
    (4, 'Winnipeg Portage',    'Winnipeg',   'Manitoba',        'Central'),
    (5, 'Toronto Queen West',  'Toronto',    'Ontario',         'East'),
    (6, 'Ottawa ByWard',       'Ottawa',     'Ontario',         'East'),
    (7, 'Montreal Plateau',    'Montreal',   'Quebec',          'East'),
    (8, 'Halifax Spring Gdn',  'Halifax',    'Nova Scotia',     'East');


-- ── 7. Seed data — customers ─────────────────────────────────
INSERT INTO DIM_CUSTOMER VALUES
    (1,  'Avery Chen',      'Loyalty',   'avery.chen@email.ca'),
    (2,  'Jordan Park',     'Standard',  'j.park@email.ca'),
    (3,  'Sam Okafor',      'New',       'samokafor@email.ca'),
    (4,  'Morgan Tremblay', 'Loyalty',   'mtremblay@email.ca'),
    (5,  'Riley Singh',     'Standard',  'riley.singh@email.ca'),
    (6,  'Casey Dubois',    'New',       'cdubois@email.ca'),
    (7,  'Taylor Kowalski', 'Loyalty',   'tkowalski@email.ca'),
    (8,  'Drew Fontaine',   'Standard',  'drew.f@email.ca'),
    (9,  'Alex Nguyen',     'Loyalty',   'alex.nguyen@email.ca'),
    (10, 'Jamie Lavoie',    'New',       'j.lavoie@email.ca');


-- ── 8. Seed data — fact sales ────────────────────────────────
-- Store weights make larger markets (Toronto, Vancouver, Calgary)
-- generate more transactions than smaller ones (Halifax, Winnipeg).
-- HASH-based randomisation ensures different products and customers
-- appear across different stores rather than cycling uniformly.
INSERT INTO FACT_SALES (SALE_DATE, PRODUCT_ID, STORE_ID, CUSTOMER_ID, QUANTITY, UNIT_PRICE, DISCOUNT_PCT, CHANNEL)
WITH
dates AS (
    SELECT DATEADD(DAY, SEQ4(), '2023-07-01') AS d
    FROM TABLE(GENERATOR(ROWCOUNT => 547))
),
-- Store weights: major markets get more daily transactions
store_weights AS (
    SELECT * FROM VALUES
        (1, 3),   -- Vancouver: 3 txn/day
        (2, 4),   -- Calgary: 4 txn/day (busiest West)
        (3, 3),   -- Edmonton: 3 txn/day
        (4, 1),   -- Winnipeg: 1 txn/day (smallest)
        (5, 6),   -- Toronto: 6 txn/day (busiest overall)
        (6, 2),   -- Ottawa: 2 txn/day
        (7, 4),   -- Montreal: 4 txn/day
        (8, 1)    -- Halifax: 1 txn/day (smallest)
    AS t(STORE_ID, DAILY_TXN)
),
-- Explode each day × store weight to get realistic row counts
base AS (
    SELECT
        d.d                                                        AS SALE_DATE,
        sw.STORE_ID,
        -- Hash-based product selection varies by store + date + row
        1 + MOD(ABS(HASH(d.d, sw.STORE_ID, seq.n)), 15)          AS PRODUCT_ID,
        1 + MOD(ABS(HASH(d.d, sw.STORE_ID, seq.n * 7)), 10)      AS CUSTOMER_ID,
        1 + MOD(ABS(HASH(d.d, sw.STORE_ID, seq.n * 13)), 5)      AS QUANTITY,
        CASE
            WHEN MONTH(d.d) IN (11,12) THEN 1.15
            WHEN MONTH(d.d) IN (6,7,8) THEN 1.05
            ELSE 1.00
        END                                                        AS SEASON_FACTOR,
        CASE MOD(ABS(HASH(d.d, sw.STORE_ID, seq.n * 3)), 3)
            WHEN 0 THEN 'In-Store'
            WHEN 1 THEN 'Online'
            ELSE       'Mobile'
        END                                                        AS CHANNEL,
        CASE WHEN DAYOFWEEK(d.d) IN (1,7) THEN 5 ELSE 0 END      AS DISCOUNT_PCT
    FROM dates d
    JOIN store_weights sw ON TRUE
    -- Generate exactly DAILY_TXN rows per store per day
    JOIN (SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) AS n FROM TABLE(GENERATOR(ROWCOUNT => 6))) seq ON seq.n <= sw.DAILY_TXN
),
priced AS (
    SELECT
        b.SALE_DATE,
        b.PRODUCT_ID,
        b.STORE_ID,
        b.CUSTOMER_ID,
        b.QUANTITY,
        ROUND(p.UNIT_COST * b.SEASON_FACTOR *
              (1 + MOD(ABS(HASH(b.SALE_DATE, b.PRODUCT_ID, b.STORE_ID)), 30) / 100.0), 2) AS UNIT_PRICE,
        b.DISCOUNT_PCT,
        b.CHANNEL
    FROM base b
    JOIN DIM_PRODUCT p ON p.PRODUCT_ID = b.PRODUCT_ID
)
SELECT * FROM priced;


-- ── 9. Enriched view ─────────────────────────────────────────
CREATE OR REPLACE VIEW VW_SALES_ENRICHED AS
SELECT
    fs.SALE_ID,
    fs.SALE_DATE,
    DATE_TRUNC('MONTH', fs.SALE_DATE)                                        AS SALE_MONTH,
    DATE_TRUNC('QUARTER', fs.SALE_DATE)                                      AS SALE_QUARTER,
    YEAR(fs.SALE_DATE)                                                        AS SALE_YEAR,
    fs.CHANNEL,
    p.PRODUCT_NAME,
    p.CATEGORY,
    p.BRAND,
    s.STORE_NAME,
    s.CITY,
    s.PROVINCE,
    s.REGION,
    c.FULL_NAME     AS CUSTOMER_NAME,
    c.SEGMENT       AS CUSTOMER_SEGMENT,
    fs.QUANTITY,
    fs.UNIT_PRICE,
    fs.DISCOUNT_PCT,
    fs.UNIT_PRICE * fs.QUANTITY                                               AS GROSS_REVENUE,
    fs.UNIT_PRICE * fs.QUANTITY * (1 - fs.DISCOUNT_PCT / 100.0)              AS NET_REVENUE,
    (fs.UNIT_PRICE - p.UNIT_COST) * fs.QUANTITY                              AS GROSS_MARGIN,
    ROUND((fs.UNIT_PRICE - p.UNIT_COST) / NULLIF(fs.UNIT_PRICE,0) * 100, 2) AS MARGIN_PCT
FROM FACT_SALES   fs
JOIN DIM_PRODUCT  p  ON p.PRODUCT_ID  = fs.PRODUCT_ID
JOIN DIM_STORE    s  ON s.STORE_ID    = fs.STORE_ID
JOIN DIM_CUSTOMER c  ON c.CUSTOMER_ID = fs.CUSTOMER_ID;

-- Sanity check — should show ~13,000 rows and realistic revenue spread
SELECT COUNT(*) AS ROW_COUNT, ROUND(SUM(NET_REVENUE),0) AS TOTAL_NET_REVENUE
FROM VW_SALES_ENRICHED;

-- Verify store distribution is varied (not all equal)
SELECT STORE_NAME, COUNT(*) AS TRANSACTIONS
FROM VW_SALES_ENRICHED
GROUP BY STORE_NAME
ORDER BY TRANSACTIONS DESC;


-- ── 10. Customer feedback data ───────────────────────────────
INSERT INTO CUSTOMER_FEEDBACK (CUSTOMER_ID, STORE_ID, FEEDBACK_DATE, CHANNEL, FEEDBACK_TEXT) VALUES
(1, 5, '2024-11-03', 'Online',   'Absolutely love my new UltraPhone. Delivery was lightning fast and the packaging was perfect. Will definitely shop here again!'),
(2, 2, '2024-11-07', 'In-Store', 'The staff were friendly but the checkout line took forever. Product is great but the wait ruined the experience a bit.'),
(3, 1, '2024-11-12', 'Mobile',   'Ordered the wireless earbuds — they arrived damaged. Still waiting on a replacement after 10 days. Very disappointed with support.'),
(4, 5, '2024-11-15', 'Online',   'Great selection online. Found the laptop I wanted at a better price than competitors. Smooth checkout process too.'),
(5, 3, '2024-11-20', 'In-Store', 'The Home & Garden section was totally understocked. Asked three staff members where the espresso makers were and nobody knew.'),
(6, 7, '2024-12-01', 'Online',   'Holiday shipping was delayed by a week. Understandable given the season but a heads-up email would have been helpful.'),
(7, 5, '2024-12-05', 'Mobile',   'Returned the jacket — wrong size. Returns process was seamless, full refund within 2 days. Top marks for that.'),
(8, 4, '2024-12-10', 'In-Store', 'Staff member in Electronics was incredibly knowledgeable. Spent 20 minutes helping me compare smartwatches. Bought one on the spot.'),
(9, 6, '2024-12-14', 'Online',   'The Vitamin C Serum I ordered arrived past its best before date. This is completely unacceptable for a skincare product.'),
(10,2, '2024-12-18', 'Mobile',   'App crashed three times during checkout. Eventually managed to complete the purchase on the website. Needs a serious fix.');


-- ── 11. Call transcripts data ────────────────────────────────
INSERT INTO CALL_TRANSCRIPTS (CALL_DATE, STORE_ID, CUSTOMER_ID, AGENT_NAME, CALL_TYPE, BODY_TEXT) VALUES
('2024-10-14', 5, 1, 'Priya Sharma',   'Complaint',
 'Customer Avery Chen called regarding a delayed online order for the UltraPhone X12. Order was placed October 8th with 3-day shipping selected. As of October 14th the package had not arrived. Tracking showed it was stuck in the Calgary distribution centre. Agent Priya escalated to the logistics team and issued a $25 store credit as a goodwill gesture. Customer was satisfied with the resolution but requested a follow-up call once the package moved.'),
('2024-10-22', 2, 2, 'Marcus Lee',     'Return',
 'Jordan Park visited the Calgary Centre location requesting a return of the Laptop Slim 14 purchased online. Reason cited: received the wrong colour (space grey instead of silver). Agent Marcus Lee verified the purchase and confirmed the return was within the 30-day window. Full refund processed to original payment method. Customer asked about re-ordering — confirmed the silver variant is in stock at the Edmonton location and offered to arrange a store transfer.'),
('2024-11-03', 3, 3, 'Hina Baig',      'Enquiry',
 'Sam Okafor called the Edmonton Whyte Ave store enquiring about the Air Purifier 360. Specifically wanted to know if the HEPA filter was washable and how often it needed replacement. Agent Hina Baig confirmed HEPA filters are not washable and should be replaced every 6 months under normal use. Sam was satisfied and said he would visit the store on the weekend to purchase. No issues logged.'),
('2024-11-19', 1, 4, 'Priya Sharma',   'Complaint',
 'Morgan Tremblay called the Vancouver Downtown location upset about a pricing discrepancy. The Espresso Maker Pro was listed at $159 on the website but rang up at $179 in store. After checking the system, Agent Priya Sharma confirmed the online price was a web-exclusive promotion not available in store. Morgan escalated, requesting a price match. Store manager approved the price match as a one-time exception. Morgan was appreciative and mentioned she had been a loyalty customer for 4 years.'),
('2024-12-02', 5, 5, 'Aiden Walsh',    'Compliment',
 'Riley Singh called Toronto Queen West to compliment staff member David Kim for exceptional service during a recent in-store visit. Riley had been looking for a gift for her father and David spent considerable time helping her compare the SmartWatch Pro versus a competitor product, explaining features in plain language. Riley said it was the best retail experience she had had in years and that she would be bringing her whole family for holiday shopping. Agent Aiden Walsh logged the compliment and forwarded to the store manager.'),
('2024-12-11', 7, 6, 'Sophie Gagnon',  'Complaint',
 'Casey Dubois called the Montreal Plateau location regarding a Beauty order — the Vitamin C Serum arrived with a broken pump dispenser. Casey had already sent photos via email. Agent Sophie Gagnon located the email thread and confirmed a replacement unit was being dispatched with expedited shipping at no cost. Casey was concerned about product quality controls and asked whether the serum had been stored correctly. Sophie confirmed products are stored in temperature-controlled facilities and that this was an isolated packaging defect.'),
('2025-01-08', 4, 7, 'Marcus Lee',     'Enquiry',
 'Taylor Kowalski called the Winnipeg Portage location asking about the upcoming winter clearance on Apparel. Specifically interested in the Trail Runner Jacket and Yoga Pants Elite. Agent Marcus Lee confirmed a 20% off clearance event running January 15-31 and that both items would be included. Taylor asked if Loyalty customers received an additional discount — Marcus confirmed Loyalty members receive an extra 5% on clearance items. Taylor said she would wait for the sale and planned to purchase at least two jackets.'),
('2025-01-21', 6, 8, 'Hina Baig',      'Return',
 'Drew Fontaine called the Ottawa ByWard location to initiate a return of the Resistance Bands Kit. Reason: the bands snapped during first use. Drew had photos. Agent Hina Baig confirmed this was a product defect within the warranty period and initiated a full refund plus a replacement kit to be shipped free of charge. Hina also flagged this to the product team as the third defect report for this SKU in January — possible quality control issue with a specific batch. Escalation ticket opened.'),
('2025-02-03', 1, 9, 'Aiden Walsh',    'Compliment',
 'Alex Nguyen contacted Vancouver Downtown to thank the team for a smooth curbside pickup experience during the January sale. Alex noted that the wait time was under 5 minutes, staff were organized and friendly, and the Smart Home Hub was properly packaged. Alex mentioned he had previously had a bad experience at a competitor and would be switching all his tech purchases to this retailer going forward. Agent Aiden Walsh logged the compliment and noted the curbside pickup as a standout example for the operations team.'),
('2025-02-17', 2, 10,'Sophie Gagnon',  'Complaint',
 'Jamie Lavoie called Calgary Centre frustrated that the Mobile app had crashed twice during checkout, causing him to lose his cart both times. On the third attempt he switched to the website and completed the purchase successfully. Agent Sophie Gagnon apologized and explained the engineering team was aware of a cart-persistence bug introduced in the January app update, with a fix scheduled for the February release. Jamie asked for compensation — Sophie offered a 10% discount code for next purchase which Jamie accepted. Bug report updated with customer impact note.');


-- ── 12. Docs stage (optional — for PDF-based Cortex Search) ──
USE SCHEMA RETAIL_DEMO.DOCS;
CREATE STAGE IF NOT EXISTS RETAIL_DEMO.DOCS.CALL_TRANSCRIPTS
    DIRECTORY = (ENABLE = TRUE)
    COMMENT   = 'Optional stage for PDF transcripts (demo uses inline table instead)';

