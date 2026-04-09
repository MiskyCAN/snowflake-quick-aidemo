-- =============================================================================
-- Publish Streamlit App from Workspace
-- Deploys the Retail Sales Assistant Streamlit app using the warehouse runtime
-- with environment.yml to pin Streamlit 1.35+ (supports chat UI components).
--
-- Prerequisites:
--   1. RETAIL_DEMO database and MODELS schema must exist
--   2. RETAIL_DEMO_WH warehouse must exist
--   3. streamlit_app.py and environment.yml must be in the
--      streamlit_example/ folder in the workspace
--
-- Setup:
--   Set WORKSPACE_NAME below to match your workspace name.
--   Find it via: SHOW WORKSPACES;
--
-- Usage:
--   Run each statement in order (select + execute one at a time).
--
-- After running, open the app:
--   Projects » Streamlit » RETAIL_SALES_ASSISTANT
-- =============================================================================

SET WORKSPACE_NAME = 'snowflake-quick-aidemo';

CREATE OR REPLACE STREAMLIT RETAIL_DEMO.MODELS."Retail Sales AI DEMO"
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = RETAIL_DEMO_WH;

ALTER STREAMLIT RETAIL_DEMO.MODELS."Retail Sales AI DEMO" ADD LIVE VERSION FROM LAST;

DECLARE
    ws_url VARCHAR DEFAULT CONCAT(
        'snow://workspace/USER', CHAR(36), CURRENT_USER(),
        '.PUBLIC."', GETVARIABLE('WORKSPACE_NAME'), '"/versions/live/streamlit_example');
    copy_cmd VARCHAR;
BEGIN
    copy_cmd := 'COPY FILES INTO ''snow://streamlit/RETAIL_DEMO.MODELS."Retail Sales AI DEMO"/versions/live/'''
        || ' FROM ''' || :ws_url || ''''
        || ' FILES = (''streamlit_app.py'', ''environment.yml'')';
    EXECUTE IMMEDIATE :copy_cmd;
END;
