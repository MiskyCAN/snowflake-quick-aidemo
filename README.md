# Snowflake AI Capability Demo — Retail Sales

> **30-minute session · Retail dataset · SA audience**  
> Designed for audiences familiar with Microsoft Fabric, Power BI, and Copilot Studio.  
> Uses a synthetic Canadian multi-channel retail dataset — 8 stores, 15 products, 18 months, 3 channels.

---

## File Inventory

| File | Purpose |
|------|---------|
| `00_readme.sql` | Full README embedded as SQL comments (source of this doc) |
| `01_setup.sql` | All objects: warehouse, tables, data, view — run once |
| `02_semantic_view.sql` | Semantic view with inline synonyms — run after 01 |
| `03_cortex_llm_functions.sql` | Segment 2 demo queries |
| `04_cortex_search.sql` | Cortex Search service + demo queries |
| `05_streamlit_app.py` | 3-tab Streamlit app: Sales Analyst / VoC / Multimodal |
| `06_mcp_server.sql` | MCP server DDL + Copilot Studio config notes |

---

## Pre-Flight Checklist

- [ ] `01_setup.sql` run — verify store distribution query shows varied counts
- [ ] `02_semantic_view.sql` run — validation queries return 5 rows
- [ ] `05_streamlit_app.py` deployed and tested in Snowsight
- [ ] `04_cortex_search.sql` run — `TRANSCRIPT_SEARCH STATE = ACTIVE`
- [ ] `06_mcp_server.sql` run — endpoint URL noted
- [ ] Two browser windows open: Snowsight + Copilot Studio
- [ ] Test image ready for Multimodal tab (product photo or receipt)

---

## Prerequisites

```sql
-- Confirm Cortex is available in your region
SELECT SYSTEM$CORTEX_ENABLED_REGIONS();

-- Required role privilege for Cortex queries
GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE <your_role>;
```

---

## Demo Timing Guide

| # | Segment | Start | Duration | Asset |
|---|---------|-------|----------|-------|
| 1 | Framing | 0:00 | 2 min | Whiteboard / slide |
| 2 | Cortex LLM Functions | 2:00 | 4 min | `03_cortex_llm_functions.sql` |
| 3 | Cortex Analyst — NL to SQL | 6:00 | 6 min | `05_streamlit_app.py` — Sales Analyst tab |
| 4 | Cortex Search — RAG | 12:00 | 4 min | `04_cortex_search.sql` |
| 5 | MCP Bridge — Copilot Studio | 16:00 | 5 min | `06_mcp_server.sql` + browser |
| 6 | Snowflake Intelligence | 21:00 | 4 min | Snowsight → AI & ML → Intelligence |
| 7 | Streamlit — VoC + Multimodal | 25:00 | 2 min | `05_streamlit_app.py` — tabs 2 & 3 |
| 8 | Governance wrap | 27:00 | 3 min | Whiteboard |

> ⚠️ **Kick off `04_cortex_search.sql` during Segment 3** — takes ~2 minutes to build. Must be ACTIVE before Segment 4.

---

## Talk Track

### Segment 1 — Framing `0:00 → 2 min`
*Screen: Whiteboard or one slide: "AI where your data already lives"*

> Let me start with a question. If your data is already in Snowflake — governed, secured, current — what problem does moving it somewhere else actually solve?
>
> Today I'm going to show you that every AI capability you've been exploring — natural language queries, document intelligence, agentic workflows, even image analysis — runs natively inside Snowflake. Same RBAC. Same masking policies. No ETL, no copy, no new governance boundary.
>
> And I'll show you something specific: if your users prefer Copilot Studio, Snowflake's managed MCP server connects them directly — live data, no import. So this isn't a binary choice.

**If someone asks why not just use Fabric right now:**
- *"That's exactly what Segment 5 is about — hold the question and I'll show you the connection."*
- Don't answer it yet. Let the demo answer it.

---

### Segment 2 — Cortex LLM Functions `2:00 → 4 min`
*Screen: Snowsight → SQL Worksheet → `03_cortex_llm_functions.sql`*

> The simplest thing Cortex lets you do is call an LLM from SQL. No Python environment, no model deployment, no API key management.
>
> I have a table of customer feedback — ten rows seeded in setup. Watch what one column does.
>
> *[ Run section B — SENTIMENT query ]*
>
> `SNOWFLAKE.CORTEX.SENTIMENT` — returns a float, minus-one to plus-one. I've wrapped it in a CASE. Notice the damaged earbuds, expired serum, app crash rows landed negative without any training.
>
> *[ Run section C — SUMMARIZE + COMPLETE with JSON extraction ]*
>
> COMPLETE with a structured prompt gives me back JSON — issue category and a boolean for action required. That JSON is a first-class column. I can GROUP BY it, filter it, pipe it into a task.
>
> *[ Run section D — GROUP BY sentiment ]*
>
> AI output as an aggregate dimension. Which channel has the worst average sentiment? That's the pattern — not just generating text, but treating model output as queryable data.

| Models available | What this replaces |
|---|---|
| mistral-large, mistral-7b | Azure OpenAI calls in Fabric notebooks |
| llama3.1-8b, llama3.1-70b | Custom Python sentiment pipelines |
| claude-3-5-sonnet (Anthropic) | External API endpoints + key management |
| openai-gpt-5-2 via Cortex | Separate NLP microservices |

**Back-pocket Q&A**

**Q: Does the LLM see my raw data?**  
A: Cortex LLM functions process the column values you pass — they stay within Snowflake's governance boundary. No data leaves to an external endpoint.

**Q: Can I fine-tune on my own data?**  
A: Yes — Cortex Fine-Tuning trains a hosted base model on your Snowflake data. The resulting model lives in the Model Registry with full RBAC.

---

### Segment 3 — Cortex Analyst (NL to SQL) `6:00 → 6 min`
*Screen: Switch to Streamlit app tab — Sales Analyst tab open*

> ⚠️ **Now:** Switch to a second tab and run `CREATE CORTEX SEARCH SERVICE` in `04_cortex_search.sql`. Takes ~2 minutes to build. Must be ACTIVE before Segment 4.

> This is the centrepiece for a business user audience. A Streamlit app — running inside Snowflake, no external hosting — that wraps Cortex Analyst. Type a question in plain English, get a chart.
>
> The key is the semantic view we built in `02`. It maps business vocabulary to physical columns. 'Revenue' resolves to `NET_REVENUE`. 'Last quarter' generates the right `DATE_TRUNC`. Every metric has synonyms baked in.

**Live demo questions**

| Ask this | Point out |
|---|---|
| "Total revenue by channel in Q4 2024?" | Time-bounded NL→SQL. Toggle SQL to show `DATE_TRUNC`. |
| "Which product category has the highest margin?" | Bar chart auto-renders. No Power BI, no export. |
| "Compare West and East region revenue by month" | Multi-series line. Single question drives a store→region join. |
| "How do Loyalty customers spend vs New customers?" | Semantic model knows Loyalty is a `CUSTOMER_SEGMENT` value. |

> The SQL toggle is the bit I'd highlight for this audience. Every answer is auditable — you can see exactly what query ran, validate it, feed it into dbt. No black box.

**Back-pocket Q&A**

**Q: How is this different from Power BI Q&A?**  
A: Same NL-over-data concept, but the semantic layer is a Snowflake DDL object with full RBAC. You can surface it via REST API, Streamlit, or Copilot Studio via MCP. Segment 5 covers that last one.

**Q: How accurate is the SQL?**  
A: Snowflake quotes 90%+ on verified question sets. The synonyms and COMMENT fields in the semantic view are the lever — richer descriptions push accuracy higher.

---

### Segment 4 — Cortex Search (RAG) `12:00 → 4 min`
*Screen: Snowsight → SQL Worksheet → `04_cortex_search.sql`, section A*

> ⚠️ **Verify before switching:** `SHOW CORTEX SEARCH SERVICES IN SCHEMA RETAIL_DEMO.MODELS;` — STATE must be ACTIVE. If still BUILDING, take a question from the room.

> Shifting to unstructured. I have a table of call transcripts — CRM-style notes seeded in setup. Cortex Search indexes this content and gives you hybrid search — keyword and vector similarity combined. No vector database, no embedding pipeline, no Azure AI Search instance. A SQL DDL statement.
>
> *[ Run section B — SEARCH_PREVIEW: 'product defect damaged broken' ]*
>
> The resistance bands defect surfaces even though I didn't search those exact words — semantic similarity picked up 'snapped during first use'.
>
> *[ Run section C — COMPLETE: complaint analysis ]*
>
> RAG in one SQL statement. Pull complaint transcripts, augment the prompt, generate a grounded response. What you'd normally build with a vector database, an orchestration framework, and an LLM endpoint.

| What Cortex Search replaces | What you keep |
|---|---|
| Azure AI Search + embedding pipeline | Same RBAC that controls the source table |
| Copilot Studio knowledge base + SharePoint | Snowflake audit logs on every search query |
| Standalone vector DB (Pinecone, Weaviate) | Data in one place — no sync, no copy |
| Custom chunking and indexing scripts | Structured attribute filtering (CALL_TYPE, STORE_ID) |

**Back-pocket Q&A**

**Q: What file formats can Cortex Search index?**  
A: PDFs via `PARSE_DOCUMENT`, plain text, any VARCHAR in a Snowflake table. Demo uses inline text — production would stage PDFs and use `PARSE_DOCUMENT`.

---

### Segment 5 — MCP Bridge (Snowflake → Copilot Studio) `16:00 → 5 min`
*Screen: Split — Snowsight left (`06_mcp_server.sql`) | Copilot Studio browser right*

> Nothing I've shown requires your users to give up Copilot Studio. Snowflake's managed MCP server — GA since November — connects Copilot Studio agents directly to Snowflake as a backend. Data never moves. RBAC on the semantic view controls what the agent can see.
>
> The architecture decision isn't Snowflake or Copilot Studio. It's: where should the AI compute run, and where should the data live?
>
> *[ Show `06_mcp_server.sql` — one CREATE MCP SERVER statement with FROM SPECIFICATION block ]*
>
> One SQL statement. The YAML block registers both tools: Cortex Analyst against the semantic view, and Cortex Search against the transcript service. Copilot Studio auto-discovers them from the endpoint.
>
> *[ Switch to Copilot Studio browser tab — ask the same question from Segment 3 ]*
>
> Copilot routes through the MCP server, Cortex Analyst generates SQL, result comes back to Copilot. From the user's perspective it looks like any Copilot agent. From a governance perspective it ran inside Snowflake.

**Back-pocket Q&A**

**Q: Does Copilot Studio pass Entra identity through to Snowflake?**  
A: Yes with OAuth. Managed MCP supports OAuth 2.0 — thread Entra identity to Snowflake OAuth so row access policies apply per user. API key auth is simpler for demos.

**Q: Does the MCP server support semantic YAML files or only views?**  
A: Views only — that's why we use `02_semantic_view.sql` as the source, not the legacy YAML.

---

### Segment 6 — Snowflake Intelligence `21:00 → 4 min`
*Screen: Snowsight → AI & ML → Intelligence*

> Everything so far has been single-capability. Intelligence adds agentic orchestration on top. The agent decides whether your question needs SQL, document search, or both — executes the right tool and synthesises a response.

| Ask this | Why it works |
|---|---|
| "Which categories have the lowest margin, and are there call transcripts that explain why?" | Forces agent to use both tools and synthesise. Structured + unstructured in one response. |
| "Summarise recurring complaints from the West region and suggest one fix." | Grounded generation — agent retrieves transcripts before generating the recommendation. |

**Q: Is Intelligence generally available?**  
A: Public preview as of August 2025. Confirm it's enabled on your account before demo day — look for AI & ML → Intelligence in Snowsight.

---

### Segment 7 — Streamlit: Voice of Customer + Multimodal `25:00 → 2 min`
*Screen: `05_streamlit_app.py` → Voice of Customer tab, then Multimodal AI tab*

**Voice of Customer tab**

> The second tab brings Segment 2's LLM functions into a polished UI. Four analyses: sentiment scoring with a donut chart, transcript summarisation with agent breakdowns, CLASSIFY_TEXT and EXTRACT_ANSWER on call types, and a negative feedback deep-dive. Each one shows the SQL expander so the audience can see exactly what ran.

**Multimodal AI tab — the differentiator**

> This is the capability that often surprises people. Upload any retail image — a product photo, a shelf tag, a receipt — and Cortex COMPLETE with a vision-capable model analyses it.
>
> Two modes: Product Identifier auto-prompts for category, price range, and retail fit. Free-form lets you ask anything — 'What promotional text is visible?', 'Is this label correct?'. The image and prompt never leave Snowflake's governance boundary. The SQL shape is shown in the expander so it's fully auditable.
>
> *[ Upload a product image — use 'Product Identifier' mode first, then switch to a free-form question ]*

**Good demo images to prepare in advance:**
- A product with visible branding and a price tag
- A shelf photo with multiple products
- A printed receipt or packing slip
- A product label with ingredient/spec text

**Q: Which vision model is this?**  
A: `claude-3-5-sonnet` by default — configurable at the top of the script. `pixtral-large` is also available. Both run inside Snowflake via Cortex COMPLETE.

**Q: Can this work on documents as well as images?**  
A: Yes — `PARSE_DOCUMENT` handles PDFs and returns structured text. For image-in-document scenarios you'd combine `PARSE_DOCUMENT` with `COMPLETE`.

---

### Segment 8 — Governance Wrap `27:00 → 3 min`
*Screen: Whiteboard or summary slide — no new Snowsight tabs*

> Every query today — the sentiment scoring, the NL to SQL chat, the document search, the Copilot Studio MCP call, the image analysis — every single one ran inside Snowflake's compute boundary. The RBAC on `VW_SALES_ENRICHED` controlled what Cortex Analyst could query. Masking policies apply whether you're in a SQL worksheet, the Streamlit app, or a Copilot Studio agent through MCP. You don't configure AI governance separately from data governance. They're the same thing.
>
> Model choice is also inside the boundary. Mistral and Llama today. GPT-5.2 and Claude are also available inside Cortex. You're not sending data to external endpoints.
>
> The decision framework: where does your data live, and how much do you want to pay — in cost, complexity, and governance overhead — to move it somewhere else to do AI? If it's already in Snowflake, the answer is: you don't have to.

**Closing question**

> What would your team build in the next 90 days if the AI was already sitting next to the data?

---

## Microsoft Equivalent Map

| Snowflake | Microsoft equivalent |
|---|---|
| Cortex LLM Functions | Copilot in Fabric notebooks / Azure OpenAI |
| Cortex Analyst (NL to SQL) | Power BI Q&A / Copilot in Power BI (portable YAML semantic layer) |
| Cortex Search (RAG) | Copilot Studio knowledge base + Azure AI Search (no vector DB needed) |
| Managed MCP Server | Copilot Studio connector (RBAC passes through) |
| Snowflake Intelligence | Copilot Studio agents / M365 Copilot |
| Multimodal (COMPLETE + vision) | Azure AI Vision + OpenAI GPT-4V (all in SQL here) |
| Snowflake RBAC + masking | Microsoft Purview (one governance boundary vs two) |

---

## Demo Question Bank

**Sales Analyst tab (Streamlit)**
- "What was total revenue by channel in Q4 2024?"
- "Which product category has the highest margin?"
- "Compare West and East region revenue by month in 2024"
- "Which 3 stores had the lowest average order value?"
- "How do Loyalty customers spend compared to New customers?"

**Voice of Customer tab (Streamlit)**
1. Feedback Sentiment Analysis — shows SENTIMENT + SUMMARIZE
2. Summarize Call Transcripts — agent/type breakdown
3. Classify & Extract — CLASSIFY_TEXT + EXTRACT_ANSWER
4. Negative Feedback Deep-Dive — filtered sentiment

**Multimodal tab (Streamlit)**
- "What product is this and what category does it belong to?"
- "Identify any pricing or promotional information visible."
- "Is this consistent with our product range?"

**Cortex Search queries (`04_cortex_search.sql`)**
- `"product defect damaged broken"`
- `"excellent staff service compliment"`
- `"app crash mobile checkout"`

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| "Cortex not available" | `SELECT SYSTEM$CORTEX_ENABLED_REGIONS();` — Cortex Analyst requires AWS us-east-1/us-west-2 or Azure East US / West Europe |
| Streamlit "API error 401" | `GRANT DATABASE ROLE SNOWFLAKE.CORTEX_USER TO ROLE <role>;` |
| Streamlit "Cortex Analyst API error 390400" | Role alternation error — clear conversation and retry. If persistent, check message history in session state. |
| Cortex Search "service not found" | `SHOW CORTEX SEARCH SERVICES IN SCHEMA RETAIL_DEMO.MODELS;` — wait for `STATE = 'ACTIVE'` |
| MCP server errors | Confirm tool names use hyphens not underscores. `DESCRIBE MCP SERVER RETAIL_DEMO.MODELS.RETAIL_MCP_SERVER;` |

---

## Cost Estimate

| Activity | Estimated cost |
|---|---|
| Full setup run | ~$2–3 USD |
| Dry run + practice | ~$2–3 USD |
| Live 30-min demo | ~$1–2 USD |
| Cortex Analyst per query | ~$0.10–0.15 (serverless) |
| **Total pre-demo** | **~$5–8 USD** |

> Set `AUTO_SUSPEND = 60` on `RETAIL_DEMO_WH` to avoid idle spend.

