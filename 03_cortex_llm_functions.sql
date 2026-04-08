-- ============================================================
-- SNOWFLAKE AI DEMO — RETAIL SALES
-- File 03: Cortex LLM Functions (Segment 2 — 4 minutes)
-- "This is what Copilot does in Fabric notebooks — except
--  it's a SQL function running on data that never moved."
-- ============================================================

USE WAREHOUSE RETAIL_DEMO_WH;
USE DATABASE  RETAIL_DEMO;
USE SCHEMA    RETAIL_DEMO.SALES;


-- ── A. DEMO STEP 1: Sentiment scoring ───────────────────────
-- Talk track: "One function call. No Python, no model deployment."
-- Compare to: Azure OpenAI calls wrapped in Fabric notebook cells.

SELECT
    FEEDBACK_ID,
    CUSTOMER_ID,
    CHANNEL,
    LEFT(FEEDBACK_TEXT, 60)                                    AS FEEDBACK_PREVIEW,
    SNOWFLAKE.CORTEX.SENTIMENT(FEEDBACK_TEXT)                  AS SENTIMENT_SCORE,
    CASE
        WHEN SNOWFLAKE.CORTEX.SENTIMENT(FEEDBACK_TEXT) >= 0.3  THEN 'Positive'
        WHEN SNOWFLAKE.CORTEX.SENTIMENT(FEEDBACK_TEXT) <= -0.3 THEN 'Negative'
        ELSE 'Neutral'
    END                                                        AS SENTIMENT_LABEL
FROM CUSTOMER_FEEDBACK
ORDER BY SENTIMENT_SCORE;


-- ── B. DEMO STEP 2: Summarize + extract root cause ──────────
-- Talk track: "Now I want a one-line summary AND a structured
--  insight — the kind of thing you'd build a Copilot plugin for."

SELECT
    FEEDBACK_ID,
    CHANNEL,
    SNOWFLAKE.CORTEX.SENTIMENT(FEEDBACK_TEXT)                  AS SENTIMENT_SCORE,
    SNOWFLAKE.CORTEX.SUMMARIZE(FEEDBACK_TEXT)                  AS SUMMARY,
    TRIM(SNOWFLAKE.CORTEX.COMPLETE(
        'mistral-large',
        CONCAT(
            'You are a retail customer experience analyst. ',
            'Read this customer feedback and respond with ONLY a JSON object ',
            'with two keys: "issue_category" (one of: Shipping | Product Quality | ',
            'Staff | Returns | App/Tech | Price | Positive) and "action_required" ',
            '(true or false). Feedback: ', FEEDBACK_TEXT
        )
    ))                                                         AS STRUCTURED_INSIGHT
FROM CUSTOMER_FEEDBACK
ORDER BY SENTIMENT_SCORE;


-- ── C. BONUS: Aggregate — which channel has the worst sentiment? ─
-- Talk track: "This is where it gets interesting — AI output
--  becomes a first-class column you can GROUP BY, filter, join."

WITH SCORED AS (
    SELECT
        CHANNEL,
        STORE_ID,
        SNOWFLAKE.CORTEX.SENTIMENT(FEEDBACK_TEXT) AS SCORE
    FROM CUSTOMER_FEEDBACK
)
SELECT
    CHANNEL,
    COUNT(*)                    AS FEEDBACK_COUNT,
    ROUND(AVG(SCORE), 3)        AS AVG_SENTIMENT,
    ROUND(MIN(SCORE), 3)        AS WORST_SCORE
FROM SCORED
GROUP BY CHANNEL
ORDER BY AVG_SENTIMENT;

-- ── D. GOVERNANCE reminder (for your wrap segment) ──────────
-- The data never left Snowflake. The LLM call stays within the
-- Snowflake governance boundary. RBAC on CUSTOMER_FEEDBACK
-- controls who can even run these queries.
-- No Azure OpenAI endpoint, no API key management, no egress.

