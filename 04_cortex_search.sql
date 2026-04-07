-- ============================================================
-- SNOWFLAKE AI DEMO — RETAIL SALES
-- File 04: Cortex Search (Segment 4 — 4 minutes)
-- CALL_TRANSCRIPTS table and data are in 01_setup.sql.
-- This file creates the search service and runs demo queries.
-- Kick this off during Segment 3 — takes ~2 min to build.
-- ============================================================

USE WAREHOUSE RETAIL_DEMO_WH;
USE DATABASE  RETAIL_DEMO;
USE SCHEMA    RETAIL_DEMO.SALES;

-- CALL_TRANSCRIPTS already exists from 01_setup.sql — no setup needed.


-- ── A. Create Cortex Search service ─────────────────────────
USE SCHEMA RETAIL_DEMO.MODELS;

CREATE OR REPLACE CORTEX SEARCH SERVICE RETAIL_DEMO.MODELS.TRANSCRIPT_SEARCH
    ON BODY_TEXT
    ATTRIBUTES CALL_TYPE, STORE_ID, CALL_DATE, AGENT_NAME
    WAREHOUSE  = RETAIL_DEMO_WH
    TARGET_LAG = '1 hour'
    COMMENT    = 'Hybrid semantic + keyword search over sales call transcripts'
AS (
    SELECT
        TRANSCRIPT_ID,
        CALL_DATE,
        STORE_ID,
        CUSTOMER_ID,
        AGENT_NAME,
        CALL_TYPE,
        BODY_TEXT
    FROM RETAIL_DEMO.SALES.CALL_TRANSCRIPTS
);


-- ── B. DEMO: Query the search service from SQL ───────────────
-- Talk track: "Cortex Search is doing hybrid search — keyword +
--  vector similarity — across all 10 transcripts in one call.
--  No vector database. No embedding pipeline. No Azure AI Search."

-- Example 1: Find complaints about product defects
SELECT PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'RETAIL_DEMO.MODELS.TRANSCRIPT_SEARCH',
        '{
           "query": "product defect quality issue",
           "columns": ["CALL_DATE", "CALL_TYPE", "AGENT_NAME", "BODY_TEXT"],
           "limit": 3
         }'
    )
) AS SEARCH_RESULTS;

-- Example 2: Find positive customer experiences
SELECT PARSE_JSON(
    SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'RETAIL_DEMO.MODELS.TRANSCRIPT_SEARCH',
        '{
           "query": "excellent service staff compliment",
           "columns": ["CALL_DATE", "CALL_TYPE", "AGENT_NAME", "BODY_TEXT"],
           "filter": {"@eq": {"CALL_TYPE": "Compliment"}},
           "limit": 3
         }'
    )
) AS SEARCH_RESULTS;

-- ── C. DEMO: AI-powered Q&A over the transcripts ────────────
-- This is the "chatbot over your documents" pattern.
-- Compare to: Copilot Studio with a SharePoint knowledge source.

SELECT SNOWFLAKE.CORTEX.COMPLETE(
    'mistral-large',
    CONCAT(
        'You are a retail operations analyst. Based on the following call transcripts, ',
        'identify the top 3 recurring issues and suggest one concrete action for each. ',
        'Be concise. Transcripts: ',
        (SELECT LISTAGG(LEFT(BODY_TEXT, 300), ' | ') FROM RETAIL_DEMO.SALES.CALL_TRANSCRIPTS
         WHERE CALL_TYPE = 'Complaint')
    )
) AS COMPLAINT_ANALYSIS;

