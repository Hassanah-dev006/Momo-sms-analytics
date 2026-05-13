# MoMo SMS Data Processing — [C1 Enterprise Web Dev TEAM 5]

An enterprise fullstack application that ingests Mobile Money SMS data in XML, cleans and categorizes it using rule-based regex matching, persists it to SQLite, and visualizes the results in a static dashboard.

## Team Members

- **Hassanat Bello** — Team lead
- **Panom Achok**-Github username: Achok-kot
- **Pegdwende Savadogo**- Github username: Pjael

## Links

- **Architecture diagram:** [https://drive.google.com/file/d/1XBmV7prtwkCVz4PaZ_4CRRtMkf4WicOS/view?usp=drive_link]
- **Scrum board (GitHub Projects):** [(https://github.com/users/Hassanah-dev006/projects/1)]

## Project overview

The pipeline is one-way and batch-oriented: raw XML in `data/raw/momo.xml` is parsed, cleaned, categorized, and loaded into a SQLite database at `data/db.sqlite3`. A separate export step writes pre-aggregated metrics to `data/processed/dashboard.json`, which the static frontend reads directly. There is no backend server in front of the database — the dashboard is a static HTML/CSS/JS bundle served over plain HTTP.

Records that fail parsing or categorization are written to `data/logs/dead_letter/` rather than dropped silently, so data quality issues stay visible.

## Project structure

```
..
├── README.md
├── .env.example                      # Database connection template
├── .gitignore                        # Excludes raw data, DB files, secrets
├── requirements.txt                  # Python dependencies
├── index.html                        # Dashboard entry point
├── web/
│   ├── styles.css
│   ├── chart_handler.js
│   └── assets/
├── data/
│   ├── raw/                          # Input XML (git-ignored)
│   ├── processed/                    # Dashboard JSON output
│   ├── db.sqlite3 / momo.sql         # Database file or dump
│   └── logs/
│       ├── etl.log
│       └── dead_letter/              # Unparsed XML records
├── etl/
│   ├── parse_xml.py                  # XML parsing
│   ├── clean_normalize.py            # Amount, date, phone normalization
│   ├── categorize.py                 # Transaction type rules
│   ├── load_db.py                    # Database insert with idempotency
│   └── run.py                        # End-to-end pipeline entry point
├── api/                              # Optional FastAPI service
├── database/
│   └── database_setup.sql            # Schema DDL + sample DML
├── docs/
│   ├── erd_diagram.png               # Entity relationship diagram
│   ├── design_rationale.md           # Database design justification
│   └── data_dictionary.md            # Column-level documentation
├── examples/
│   └── json_schemas/                 # JSON serialization examples
├── scripts/
│   ├── run_etl.sh
│   ├── export_json.sh
│   └── serve_frontend.sh
└── tests/  



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



## Database Design

Entity Overview
The database is built around six entities:

users — Customer accounts identified by phone number
transactions — System of record for all MoMo transactions
transaction_categories — Transaction type classification (transfer, airtime, etc.)
tags — Analytical labels applied to transactions
transaction_tags — Junction table resolving the many-to-many between transactions and tags
system_logs — ETL pipeline event log with optional reference to specific transactions.



## Key Design Decisions

#1 Money is stored as DECIMAL(15,2), never FLOAT. Financial aggregations must reconcile to the cent; floating-point accumulates rounding errors.

#2 sender_id and receiver_id are nullable foreign keys. Some MoMo activities (airtime, balance checks, service fees) have no second party; nullability reflects the domain rather than forcing phantom records.

#3 external_ref is UNIQUE on the transactions table. This is the MoMo transaction ID extracted from each SMS and acts as the ETL idempotency key — re-running the parser on the same XML cannot create duplicates.

#4 The M:N relationship is between transactions and tags, resolved through the transaction_tags junction. Categories are 1:M (each transaction has exactly one category), but tags are analytical and a transaction can carry multiple ("high-value," "recurring," "flagged-for-review").

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
