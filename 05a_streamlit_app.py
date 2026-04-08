# ============================================================
# SNOWFLAKE AI DEMO — RETAIL SALES
# File 05: Streamlit in Snowflake — unified AI chat
#
# One chat interface, two Cortex backends:
#   • Cortex Analyst  — structured NL→SQL (sales data)
#   • Cortex Search   — semantic search over call transcripts
#
# The app classifies each question and routes to the right
# backend — or queries both when the question spans them.
# This mirrors how Snowflake Intelligence works internally.
#
# Setup: Snowsight → Projects → Streamlit → + Streamlit App
#        DB: RETAIL_DEMO | Schema: MODELS | WH: RETAIL_DEMO_WH
# ============================================================

import streamlit as st
import pandas as pd
import altair as alt
import requests
import json
from snowflake.snowpark import Session

SEMANTIC_VIEW    = "RETAIL_DEMO.MODELS.RETAIL_SALES_SV"
SEARCH_SERVICE   = "RETAIL_DEMO.MODELS.TRANSCRIPT_SEARCH"
MAX_CHART_ROWS   = 500
CHART_PALETTE    = ["#29B5E8","#6366f1","#f59e0b","#10b981","#ef4444","#8b5cf6","#ec4899","#14b8a6"]

# Keywords that suggest the question is about unstructured / call data
SEARCH_KEYWORDS  = [
    "call", "transcript", "complaint", "compliment", "feedback", "customer said",
    "agent", "ticket", "return", "refund", "issue", "support", "resolution",
    "what did", "who called", "any calls", "any feedback", "service experience",
]

st.set_page_config(page_title="Retail Sales AI Assistant", layout="wide")

st.markdown("""
<style>
    .block-container { padding-top: 1.5rem; }
    .hero {
        background: linear-gradient(135deg, #1B2A4A 0%, #29B5E8 100%);
        border-radius: 12px; padding: 1.5rem 2rem; margin-bottom: 1.5rem;
    }
    .hero h1 { color: #fff; font-size: 1.6rem; font-weight: 700; margin: 0; }
    .hero p  { color: rgba(255,255,255,0.85); font-size: 0.9rem; margin: 0.25rem 0 0 0; }
    .metric-card {
        background: #fff; border-radius: 10px; padding: 1rem 1.25rem;
        box-shadow: 0 1px 4px rgba(0,0,0,0.08); border-left: 4px solid #29B5E8;
    }
    .metric-card .label { font-size: 0.75rem; color: #888; text-transform: uppercase;
                          letter-spacing: 0.04em; font-weight: 600; }
    .metric-card .value { font-size: 1.5rem; font-weight: 700; color: #1B2A4A; margin-top: 2px; }
    .answer-bubble {
        background: linear-gradient(135deg, #eef8ff, #f0f4ff); border-radius: 10px;
        padding: 0.85rem 1.1rem; border-left: 4px solid #29B5E8; margin-bottom: 0.5rem;
        font-size: 0.9rem; line-height: 1.6;
    }
    .search-bubble {
        background: linear-gradient(135deg, #f5f0ff, #ede9fe); border-radius: 10px;
        padding: 0.85rem 1.1rem; border-left: 4px solid #6366f1; margin-bottom: 0.5rem;
        font-size: 0.9rem; line-height: 1.6;
    }
    .search-result {
        background: #fff; border-radius: 8px; padding: 0.75rem 1rem;
        border-left: 3px solid #6366f1; margin-bottom: 0.5rem;
        box-shadow: 0 1px 3px rgba(0,0,0,0.06); font-size: 0.85rem;
    }
    .sql-box {
        background: #1e1e2e; color: #cdd6f4; border-radius: 8px; padding: 0.85rem 1rem;
        font-family: monospace; font-size: 0.78rem; overflow-x: auto; margin: 0.5rem 0;
    }
    .badge { display: inline-block; border-radius: 4px; padding: 2px 8px;
             font-size: 0.7rem; font-weight: 600; margin-bottom: 4px; margin-right: 4px; }
    .badge-blue   { background: #29B5E8; color: #fff; }
    .badge-purple { background: #6366f1; color: #fff; }
    .badge-gray   { background: #e5e7eb; color: #374151; }
    .route-indicator {
        font-size: 0.78rem; color: #6b7280; margin-bottom: 0.5rem;
        display: flex; align-items: center; gap: 6px;
    }
</style>
""", unsafe_allow_html=True)

st.markdown("""
<div class="hero">
    <h1>Retail Sales AI Assistant</h1>
    <p>Ask anything — structured sales data or unstructured call transcripts. Cortex routes to the right backend automatically.</p>
</div>
""", unsafe_allow_html=True)

session = st.connection("snowflake").session()

if "messages" not in st.session_state:
    st.session_state.messages = []
if "show_sql" not in st.session_state:
    st.session_state.show_sql = True


# ── Routing classifier ────────────────────────────────────────
def classify_question(question: str) -> str:
    """
    Returns 'search', 'analyst', or 'both'.
    'both' triggers when a question clearly combines structured
    metrics with unstructured context (e.g. margin + complaints).
    """
    q = question.lower()
    has_search  = any(kw in q for kw in SEARCH_KEYWORDS)
    # Structured signals: numbers, metrics, comparisons, time periods
    has_analyst = any(kw in q for kw in [
        "revenue", "sales", "margin", "profit", "aov", "average order",
        "channel", "region", "store", "product", "category", "quarter",
        "month", "year", "trend", "compare", "top", "bottom", "highest",
        "lowest", "how much", "how many", "total", "units sold",
    ])
    if has_search and has_analyst:
        return "both"
    if has_search:
        return "search"
    return "analyst"   # default to structured


# ── Cortex Analyst ────────────────────────────────────────────
def call_cortex_analyst(question: str, history: list) -> dict:
    conn  = session.connection
    token = conn.rest.token
    url   = f"https://{conn.host}/api/v2/cortex/analyst/message"

    messages = []
    for msg in history[-6:]:
        role = msg.get("role","")
        if role == "assistant":
            role = "analyst"
        text = msg.get("content","") or ""
        if not text.strip():
            continue
        if messages and messages[-1]["role"] == role:
            continue
        messages.append({"role": role, "content": [{"type": "text", "text": text}]})

    if messages and messages[-1]["role"] == "user":
        messages.pop()
    messages.append({"role": "user", "content": [{"type": "text", "text": question}]})

    response = requests.post(
        url,
        json={"messages": messages, "semantic_view": SEMANTIC_VIEW},
        headers={"Authorization": f'Snowflake Token="{token}"',
                 "Content-Type": "application/json", "Accept": "application/json"},
        timeout=60
    )
    response.raise_for_status()
    return response.json()


# ── Cortex Search ─────────────────────────────────────────────
def call_cortex_search(question: str, limit: int = 3) -> list[dict]:
    """Returns a list of matching transcript snippets."""
    payload = json.dumps({
        "query": question,
        "columns": ["CALL_DATE", "CALL_TYPE", "AGENT_NAME", "STORE_ID", "BODY_TEXT"],
        "limit": limit
    })
    raw = session.sql(f"""
        SELECT PARSE_JSON(
            SNOWFLAKE.CORTEX.SEARCH_PREVIEW('{SEARCH_SERVICE}', $${payload}$$)
        ) AS RESULTS
    """).collect()

    if not raw:
        return []
    results_json = raw[0]["RESULTS"]
    if results_json is None:
        return []
    results = json.loads(str(results_json))
    return results.get("results", [])


# ── Synthesise search results with LLM ───────────────────────
def synthesise_search(question: str, results: list[dict]) -> str:
    """Use COMPLETE to generate a grounded answer from search hits."""
    if not results:
        return "No relevant call transcripts found."
    excerpts = " | ".join([r.get("BODY_TEXT","")[:300] for r in results])
    sql = f"""
        SELECT SNOWFLAKE.CORTEX.COMPLETE(
            'mistral-large',
            CONCAT(
                'You are a retail customer experience analyst. Answer this question: {question} ',
                'Use only the following call transcript excerpts as your source. ',
                'Be concise and factual. Excerpts: {excerpts}'
            )
        ) AS ANSWER
    """
    try:
        row = session.sql(sql).collect()
        return row[0]["ANSWER"] if row else "Unable to synthesise answer."
    except Exception:
        return "Unable to synthesise answer from transcripts."


# ── SQL runner ────────────────────────────────────────────────
def run_sql(sql: str) -> pd.DataFrame:
    sql = sql.strip().rstrip(";")
    if ";" in sql:
        sql = sql.split(";")[-1].strip()
    return session.sql(sql).limit(MAX_CHART_ROWS).to_pandas()


# ── Auto-chart ────────────────────────────────────────────────
def auto_chart(df: pd.DataFrame) -> None:
    if df.empty or len(df.columns) < 2:
        st.dataframe(df, width="stretch")
        return
    cols      = df.columns.tolist()
    num_cols  = [c for c in cols if pd.api.types.is_numeric_dtype(df[c])]
    cat_cols  = [c for c in cols if not pd.api.types.is_numeric_dtype(df[c])]
    date_cols = [c for c in cat_cols if any(k in c.lower() for k in ["date","month","quarter","year"])]
    if not num_cols:
        st.dataframe(df, width="stretch")
        return
    metric = num_cols[0]
    scale  = alt.Scale(range=CHART_PALETTE)

    if date_cols:
        x_col = date_cols[0]
        df[x_col] = pd.to_datetime(df[x_col])
        non_date = [c for c in cat_cols if c != x_col]
        if len(num_cols) > 1 and not non_date:
            melted = df.melt(id_vars=[x_col], value_vars=num_cols, var_name="Metric", value_name="Value")
            chart = alt.Chart(melted).mark_line(strokeWidth=2.5, point=True).encode(
                x=alt.X(f"{x_col}:T", axis=alt.Axis(grid=False)),
                y=alt.Y("Value:Q", axis=alt.Axis(gridDash=[3,3])),
                color=alt.Color("Metric:N", scale=scale, legend=alt.Legend(orient="top")),
                tooltip=[x_col,"Metric","Value"]
            ).properties(height=340).configure_view(strokeWidth=0)
        elif non_date:
            chart = alt.Chart(df).mark_line(strokeWidth=2.5, point=True).encode(
                x=alt.X(f"{x_col}:T", axis=alt.Axis(grid=False)),
                y=alt.Y(f"{metric}:Q", axis=alt.Axis(gridDash=[3,3])),
                color=alt.Color(f"{non_date[0]}:N", scale=scale, legend=alt.Legend(orient="top")),
                tooltip=cols
            ).properties(height=340).configure_view(strokeWidth=0)
        else:
            chart = alt.Chart(df).mark_area(
                opacity=0.3, line={"color": CHART_PALETTE[0], "strokeWidth": 2.5}
            ).encode(
                x=alt.X(f"{x_col}:T", axis=alt.Axis(grid=False)),
                y=alt.Y(f"{metric}:Q", axis=alt.Axis(gridDash=[3,3])),
                color=alt.value(CHART_PALETTE[0]), tooltip=cols
            ).properties(height=340).configure_view(strokeWidth=0)
        st.altair_chart(chart, width="stretch")
        if len(df) <= 20 and cat_cols:
            mcols = st.columns(min(len(df), 4))
            for i, (_, row) in enumerate(df.head(4).iterrows()):
                with mcols[i]:
                    val = row[metric]
                    st.markdown(
                        f'<div class="metric-card">'
                        f'<div class="label">{str(row[cat_cols[0]])}</div>'
                        f'<div class="value">{"$" if val > 100 else ""}{val:,.0f}</div>'
                        f'</div>', unsafe_allow_html=True)
        return

    if cat_cols:
        bars = alt.Chart(df).mark_bar(cornerRadiusEnd=4).encode(
            x=alt.X(f"{metric}:Q", axis=alt.Axis(gridDash=[3,3])),
            y=alt.Y(f"{cat_cols[0]}:N", sort="-x"),
            color=alt.Color(f"{cat_cols[0]}:N", scale=scale, legend=None),
            tooltip=cols
        ).properties(height=max(220, len(df) * 36))
        text = bars.mark_text(align="left", dx=4, fontSize=11, fontWeight=600).encode(
            text=alt.Text(f"{metric}:Q", format=",.0f"), color=alt.value("#333"))
        st.altair_chart((bars + text).configure_view(strokeWidth=0), width="stretch")
        return

    st.dataframe(df, width="stretch")


# ── Render a stored message ───────────────────────────────────
def render_message(msg: dict) -> None:
    route = msg.get("route", "analyst")

    if route in ("analyst", "both") and msg.get("answer"):
        st.markdown(
            f'<div class="route-indicator">'
            f'<span class="badge badge-blue">Cortex Analyst</span> structured data</div>',
            unsafe_allow_html=True)
        st.markdown(f'<div class="answer-bubble">{msg["answer"]}</div>', unsafe_allow_html=True)
        if msg.get("sql") and st.session_state.show_sql:
            st.markdown('<span class="badge badge-gray">Generated SQL</span>', unsafe_allow_html=True)
            st.markdown(f'<div class="sql-box"><pre>{msg["sql"]}</pre></div>', unsafe_allow_html=True)
        if msg.get("dataframe") is not None:
            _df = pd.DataFrame(msg["dataframe"])
            if not _df.empty:
                auto_chart(_df)

    if route in ("search", "both") and msg.get("search_answer"):
        st.markdown(
            f'<div class="route-indicator" style="margin-top:0.75rem;">'
            f'<span class="badge badge-purple">Cortex Search</span> call transcripts</div>',
            unsafe_allow_html=True)
        st.markdown(f'<div class="search-bubble">{msg["search_answer"]}</div>', unsafe_allow_html=True)
        for hit in msg.get("search_hits", []):
            body = hit.get("BODY_TEXT","")[:280]
            call_type = hit.get("CALL_TYPE","")
            agent     = hit.get("AGENT_NAME","")
            call_date = hit.get("CALL_DATE","")
            st.markdown(
                f'<div class="search-result">'
                f'<strong>{call_type}</strong> · {agent} · {call_date}<br>'
                f'{body}{"…" if len(hit.get("BODY_TEXT","")) > 280 else ""}'
                f'</div>', unsafe_allow_html=True)


# ── Sidebar ───────────────────────────────────────────────────
with st.sidebar:
    st.markdown("**Settings**")
    st.session_state.show_sql = st.toggle("Show generated SQL", value=True)

    st.markdown("---")
    st.markdown("**Structured questions (Cortex Analyst):**")
    analyst_qs = [
        "Total revenue by channel in Q4 2024",
        "Top 5 products by margin %",
        "West vs East revenue by month in 2024",
        "Which stores had the most transactions?",
        "Loyalty vs New customer AOV in 2024",
    ]
    for q in analyst_qs:
        if st.button(q, width="stretch", key=f"a_{q[:18]}"):
            st.session_state.pending_question = q

    st.markdown("**Unstructured questions (Cortex Search):**")
    search_qs = [
        "Any complaints about product defects?",
        "What compliments have customers given?",
        "Any calls about the mobile app crashing?",
        "What issues did agents escalate last quarter?",
    ]
    for q in search_qs:
        if st.button(q, width="stretch", key=f"s_{q[:18]}"):
            st.session_state.pending_question = q

    st.markdown("**Questions that use both:**")
    both_qs = [
        "Which categories have low margin and what do call transcripts say about them?",
        "Compare West region revenue and any related complaints",
    ]
    for q in both_qs:
        if st.button(q, width="stretch", key=f"b_{q[:18]}"):
            st.session_state.pending_question = q

    st.markdown("---")
    if st.button("Clear conversation", width="stretch"):
        st.session_state.messages = []
        st.rerun()

    st.markdown("---")
    st.markdown(
        '<p style="font-size:0.75rem;color:#888;">'
        'Structured: RETAIL_DEMO.SALES<br>'
        'Unstructured: CALL_TRANSCRIPTS<br>'
        'Stays inside Snowflake ✓</p>',
        unsafe_allow_html=True)


# ── Chat history ──────────────────────────────────────────────
for msg in st.session_state.messages:
    with st.chat_message(msg["role"]):
        if msg["role"] == "user":
            st.write(msg["content"])
        else:
            render_message(msg)


# ── Input ─────────────────────────────────────────────────────
user_input = st.session_state.pop("pending_question", None) or \
             st.chat_input("Ask about sales data or call transcripts...")


# ── Main logic ────────────────────────────────────────────────
if user_input:
    with st.chat_message("user"):
        st.write(user_input)

    with st.chat_message("assistant"):
        route = classify_question(user_input)

        # Show routing indicator live so audience sees what's happening
        route_labels = {
            "analyst": '<span class="badge badge-blue">Cortex Analyst</span> routing to structured data',
            "search":  '<span class="badge badge-purple">Cortex Search</span> routing to call transcripts',
            "both":    '<span class="badge badge-blue">Cortex Analyst</span> + <span class="badge badge-purple">Cortex Search</span> querying both',
        }
        st.markdown(f'<div class="route-indicator">{route_labels[route]}</div>', unsafe_allow_html=True)

        answer_text  = ""
        sql_text     = ""
        df           = None
        search_hits  = []
        search_answer= ""

        # ── Cortex Analyst path
        if route in ("analyst", "both"):
            with st.spinner("Querying structured data..."):
                try:
                    result = call_cortex_analyst(user_input, st.session_state.messages)
                    blocks = result.get("message", {}).get("content", [])
                    answer_text = next((b.get("text","") for b in blocks if b.get("type")=="text"), "")
                    sql_text    = next((b.get("statement","") for b in blocks if b.get("type")=="sql"), "")

                    if answer_text:
                        st.markdown(f'<div class="answer-bubble">{answer_text}</div>', unsafe_allow_html=True)
                    if sql_text and st.session_state.show_sql:
                        st.markdown('<span class="badge badge-gray">Generated SQL</span>', unsafe_allow_html=True)
                        st.markdown(f'<div class="sql-box"><pre>{sql_text}</pre></div>', unsafe_allow_html=True)
                    if sql_text:
                        df = run_sql(sql_text)
                        if not df.empty:
                            auto_chart(df)
                        else:
                            st.info("Query returned no results.")
                except requests.HTTPError as e:
                    st.warning(f"Cortex Analyst: {e.response.text}")
                except Exception as e:
                    st.warning(f"Cortex Analyst error: {str(e)}")

        # ── Cortex Search path
        if route in ("search", "both"):
            with st.spinner("Searching call transcripts..."):
                try:
                    search_hits = call_cortex_search(user_input)
                    if search_hits:
                        search_answer = synthesise_search(user_input, search_hits)
                        st.markdown(
                            f'<div class="route-indicator" style="margin-top:0.75rem;">'
                            f'<span class="badge badge-purple">Cortex Search</span> call transcripts</div>',
                            unsafe_allow_html=True)
                        st.markdown(f'<div class="search-bubble">{search_answer}</div>', unsafe_allow_html=True)
                        for hit in search_hits:
                            body      = hit.get("BODY_TEXT","")[:280]
                            call_type = hit.get("CALL_TYPE","")
                            agent     = hit.get("AGENT_NAME","")
                            call_date = hit.get("CALL_DATE","")
                            st.markdown(
                                f'<div class="search-result">'
                                f'<strong>{call_type}</strong> · {agent} · {call_date}<br>'
                                f'{body}{"…" if len(hit.get("BODY_TEXT","")) > 280 else ""}'
                                f'</div>', unsafe_allow_html=True)
                    else:
                        st.info("No matching transcripts found.")
                except Exception as e:
                    st.warning(f"Cortex Search error: {str(e)}")

        # Store in history
        st.session_state.messages.append({"role": "user", "content": user_input})
        st.session_state.messages.append({
            "role":          "assistant",
            "content":       answer_text or sql_text or search_answer or "Here are the results.",
            "route":         route,
            "answer":        answer_text,
            "sql":           sql_text,
            "dataframe":     df.to_dict("list") if df is not None else None,
            "search_hits":   search_hits,
            "search_answer": search_answer,
        })

