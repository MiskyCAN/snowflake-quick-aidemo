-- =============================================================================
-- 05b: Publish Streamlit App from Workspace
-- Deploys the Retail Sales Assistant Streamlit app using the container runtime
-- which supports the latest Streamlit version (1.55+).
--
-- Prerequisites:
--   1. RETAIL_DEMO database and MODELS schema must exist
--   2. RETAIL_DEMO_WH warehouse must exist
--   3. SYSTEM_COMPUTE_POOL_CPU compute pool must exist
--   4. PYPI_ACCESS_INTEGRATION external access integration must exist
--      (one-time setup: see CREATE EXTERNAL ACCESS INTEGRATION below)
--   5. 05a_streamlit_app.py and pyproject.toml must be in the workspace
--
-- Setup:
--   Set WORKSPACE_NAME below to match your workspace name.
--   Find it via: SHOW WORKSPACES;
--
-- After running, open the app:
--   Projects » Streamlit » RETAIL_SALES_ASSISTANT
-- =============================================================================

SET WORKSPACE_NAME = 'snowflake-quick-aidemo';

CREATE EXTERNAL ACCESS INTEGRATION IF NOT EXISTS pypi_access_integration
    ALLOWED_NETWORK_RULES = (snowflake.external_access.pypi_rule)
    ENABLED = true;

CREATE OR REPLACE STREAMLIT RETAIL_DEMO.MODELS."Retail Sales Assistant DEMO"
    MAIN_FILE = '05a_streamlit_app.py'
    QUERY_WAREHOUSE = RETAIL_DEMO_WH
    RUNTIME_NAME = 'SYSTEM$ST_CONTAINER_RUNTIME_PY3_11'
    COMPUTE_POOL = SYSTEM_COMPUTE_POOL_CPU
    EXTERNAL_ACCESS_INTEGRATIONS = (pypi_access_integration);

ALTER STREAMLIT RETAIL_DEMO.MODELS."Retail Sales Assistant DEMO" ADD LIVE VERSION FROM LAST;

DECLARE
    ws_url VARCHAR DEFAULT CONCAT(
        'snow://workspace/USER', CHAR(36), CURRENT_USER(),
        '.PUBLIC."', GETVARIABLE('WORKSPACE_NAME'), '"/versions/live');
    copy_cmd VARCHAR;
BEGIN
    copy_cmd := 'COPY FILES INTO ''snow://streamlit/RETAIL_DEMO.MODELS."Retail Sales Assistant DEMO"/versions/live/'''
        || ' FROM ''' || :ws_url || ''''
        || ' FILES = (''05a_streamlit_app.py'')';
    EXECUTE IMMEDIATE :copy_cmd;
END;