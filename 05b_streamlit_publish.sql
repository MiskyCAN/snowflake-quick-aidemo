-- =============================================================================
-- 05b: Publish Streamlit App from Workspace
-- Deploys the Retail Sales Assistant Streamlit app directly from the current
-- user's workspace. The workspace URL is built dynamically using CURRENT_USER()
-- so this script is portable across accounts.
--
-- Prerequisites:
--   1. RETAIL_DEMO database and MODELS schema must exist
--   2. RETAIL_DEMO_WH warehouse must exist
--   3. 05a_streamlit_app.py must be present in the workspace
--
-- After running, open the app:
--   Catalog » Apps » RETAIL_SALES_ASSISTANT
-- =============================================================================

SET workspace_url = (
    SELECT 'snow://workspace/' || CURRENT_USER() || '$.PUBLIC.DEFAULT$/versions/live'
);

CREATE OR REPLACE STREAMLIT RETAIL_DEMO.MODELS.RETAIL_SALES_ASSISTANT
  FROM $workspace_url
  MAIN_FILE = '05a_streamlit_app.py'
  QUERY_WAREHOUSE = RETAIL_DEMO_WH;