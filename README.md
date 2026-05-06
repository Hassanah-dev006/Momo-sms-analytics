# MoMo SMS Data Processing — [TEAM NAME]

An enterprise fullstack application that ingests Mobile Money SMS data in XML, cleans and categorizes it using rule-based regex matching, persists it to SQLite, and visualizes the results in a static dashboard.

## Team

- **Hassanat Bello** — Team lead
- **Panom Achok**
- **Pegdwende Savadogo**

## Links

- **Architecture diagram:** [paste draw.io]
- **Scrum board (GitHub Projects):** [(https://github.com/users/Hassanah-dev006/projects/1)]

## Project overview

The pipeline is one-way and batch-oriented: raw XML in `data/raw/momo.xml` is parsed, cleaned, categorized, and loaded into a SQLite database at `data/db.sqlite3`. A separate export step writes pre-aggregated metrics to `data/processed/dashboard.json`, which the static frontend reads directly. There is no backend server in front of the database — the dashboard is a static HTML/CSS/JS bundle served over plain HTTP.

Records that fail parsing or categorization are written to `data/logs/dead_letter/` rather than dropped silently, so data quality issues stay visible.

## Project structure

```
.
├── README.md
├── .env.example
├── requirements.txt
├── index.html                 # Dashboard entry
├── web/                       # Frontend assets (CSS, JS)
├── data/
│   ├── raw/                   # XML input (git-ignored)
│   ├── processed/             # dashboard.json (git-ignored)
│   ├── db.sqlite3             # SQLite DB (git-ignored)
│   └── logs/                  # ETL logs + dead-letter records
├── etl/                       # Parse → clean → categorize → load → export
├── scripts/                   # Shell entry points
└── tests/                     # Unit tests for ETL stages
```

## Setup

Requires Python 3.10+ and a POSIX shell (Git Bash works on Windows).

```bash
git clone [https://github.com/Hassanah-dev006/Momo-sms-analytics.git]
cd [Momo-sms-analytics]
python -m venv .venv
source .venv/bin/activate          # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env
```

Place the provided `momo.xml` into `data/raw/`. The folder is git-ignored, so the file will not be committed.

## Run

```bash
# 1. Run the ETL pipeline (parse → clean → categorize → load to SQLite)
bash scripts/run_etl.sh

# 2. Export aggregates for the dashboard
bash scripts/export_json.sh

# 3. Serve the frontend
bash scripts/serve_frontend.sh
# Open http://localhost:8000
```

Re-run `export_json.sh` whenever the underlying database changes; the dashboard reads only from the exported JSON.

## Tests

```bash
pytest tests/ -v
```

Unit tests cover XML parsing, normalization (amounts, dates, phone numbers), and categorization rules. Tests use small inline XML fixtures rather than the full dataset.

## Architectural decisions

These are the choices that aren't obvious from the directory layout:

- **SQLite over Postgres/MySQL.** Single-file, zero-config, sufficient for the assignment's data volume. Trades concurrent-write performance for simplicity, which is the right trade here.
- **Static JSON over a live API.** The frontend reads a pre-built `dashboard.json` instead of querying a server. This eliminates an entire deployment surface (CORS, server hosting, request handling) at the cost of staleness — the dashboard is only as fresh as the last `export_json.sh` run. Acceptable because the data source itself is a one-time XML dump.
- **Rule-based regex categorization.** SMS bodies follow predictable provider-issued templates, so deterministic regex rules are more accurate and debuggable than ML classification at this scale. Rules live in `etl/categorize.py` and are covered by unit tests so changes don't silently misclassify past data.
- **Dead-letter queue instead of silent drops.** Any record that fails parsing or categorization is written to `data/logs/dead_letter/` with the original snippet preserved. This makes data-quality failures auditable rather than invisible.
- **Frontend defines the JSON contract.** The shape of `dashboard.json` is driven by what the dashboard needs to render, not by what the database happens to expose. The ETL `export` step is responsible for shaping data to match the contract.

## Workflow

- One feature per branch; PR into `main`.
- At least one teammate reviews before merge.
- Issues on the GitHub Projects board are the source of truth for ownership; if it's not on the board, no one's working on it.
- `main` should always be in a runnable state — broken code lives on feature branches.

## Status

Week 1: scaffolding, architecture, and team workflow. ETL implementation begins week 2.