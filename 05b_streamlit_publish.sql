-- =============================================================================
-- 05b: Publish Streamlit App from Workspace
-- Deploys the Retail Sales Assistant Streamlit app directly from the current
-- user's workspace. Creates the Streamlit object, then copies the app file
-- from the workspace into its embedded stage.
--
-- Prerequisites:
--   1. RETAIL_DEMO database and MODELS schema must exist
--   2. RETAIL_DEMO_WH warehouse must exist
--   3. 05a_streamlit_app.py must be present in the workspace
--
-- After running, open the app:
--   Projects » Streamlit » RETAIL_SALES_ASSISTANT
-- =============================================================================

CREATE OR REPLACE STREAMLIT RETAIL_DEMO.MODELS.RETAIL_SALES_ASSISTANT
    MAIN_FILE = '05a_streamlit_app.py'
    QUERY_WAREHOUSE = RETAIL_DEMO_WH;

ALTER STREAMLIT RETAIL_DEMO.MODELS.RETAIL_SALES_ASSISTANT ADD LIVE VERSION FROM LAST;

DECLARE
    ws_url VARCHAR DEFAULT CONCAT('snow://workspace/USER', CHAR(36), CURRENT_USER(), '.PUBLIC.DEFAULT', CHAR(36), '/versions/live');
    st_url VARCHAR DEFAULT CONCAT('snow://streamlit/RETAIL_DEMO.MODELS.RETAIL_SALES_ASSISTANT/versions/live/');
    copy_cmd VARCHAR;
BEGIN
    copy_cmd := 'COPY FILES INTO ''' || :st_url || ''''
        || ' FROM ''' || :ws_url || ''''
        || ' FILES = (''05a_streamlit_app.py'')';
    EXECUTE IMMEDIATE :copy_cmd;
END;