-- ============================================================
-- SNOWFLAKE AI DEMO — RETAIL SALES
-- File 06: MCP Server setup (Segment 5 — 5 minutes)
-- "Your Copilot Studio agent can already talk to this data.
--  No import, no ETL, same RBAC it's always had."
-- ============================================================

USE WAREHOUSE RETAIL_DEMO_WH;
USE DATABASE  RETAIL_DEMO;
USE SCHEMA    RETAIL_DEMO.MODELS;


-- ── STEP 1: Create the managed MCP server with both tools ──────
-- Correct syntax: all tools defined together in a single
-- FROM SPECIFICATION $$ ... $$ YAML block.
-- 03b_semantic_view.sql and 04_cortex_search.sql must be run first.

CREATE OR REPLACE MCP SERVER RETAIL_DEMO.MODELS.RETAIL_MCP_SERVER
FROM SPECIFICATION $$
tools:
  - name: "analyst-sales-query"
    type: "CORTEX_ANALYST_MESSAGE"
    identifier: "RETAIL_DEMO.MODELS.RETAIL_SALES_SV"
    description: "Answer natural language questions about retail sales revenue, margin, channel performance, and customer segments. Use this for any structured data question about sales metrics."
    title: "Retail Sales Analytics"
  - name: "search-call-transcripts"
    type: "CORTEX_SEARCH_SERVICE_QUERY"
    identifier: "RETAIL_DEMO.MODELS.TRANSCRIPT_SEARCH"
    description: "Search sales call transcripts and customer feedback using semantic search. Use this for questions about customer complaints, compliments, returns, or call history."
    title: "Call Transcript Search"
$$;


-- ── STEP 4: Verify the server and its tools ──────────────────
SHOW MCP SERVERS IN SCHEMA RETAIL_DEMO.MODELS;
-- Look for the MCP endpoint URL in the output — you'll need this
-- when configuring Copilot Studio.


-- ── STEP 5: Get the endpoint URL ─────────────────────────────
-- Run this to get the full HTTPS endpoint to paste into Copilot Studio:
DESCRIBE MCP SERVER RETAIL_DEMO.MODELS.RETAIL_MCP_SERVER;


-- ── STEP 6: Grant access ─────────────────────────────────────
-- The Copilot Studio service principal needs USAGE on the MCP server.
-- Replace COPILOT_SERVICE_ROLE with your actual service principal role.

-- GRANT USAGE ON MCP SERVER RETAIL_DEMO.MODELS.RETAIL_MCP_SERVER
--     TO ROLE COPILOT_SERVICE_ROLE;


-- ============================================================
-- COPILOT STUDIO CONFIGURATION (done in the browser, not SQL)
-- ============================================================
-- 1. In Copilot Studio: Settings → Connections → + Add MCP Tool
-- 2. Enter the endpoint URL from DESCRIBE MCP SERVER above
-- 3. Auth: choose "API Key" for demo (OAuth for production)
--    - Generate an API key: ALTER USER ... SET API_KEY = ...
-- 4. Copilot Studio will auto-discover your two tools:
--    - analyst_sales_query
--    - search_call_transcripts
-- 5. Test in the Copilot Studio chat:
--    "What was the top selling category last quarter?"
--    → Copilot calls analyst_sales_query → Cortex Analyst → SQL
--    → Result returned to Copilot → Displayed to user
--
-- TALK TRACK:
-- "Notice: the data never moved. Copilot is making an API call
--  to Snowflake's MCP server. Cortex Analyst generates SQL,
--  runs it against the warehouse, and returns the result.
--  The RBAC on this semantic view controls what Copilot can see.
--  If a column is masked for a role, it's masked here too."
-- ============================================================

