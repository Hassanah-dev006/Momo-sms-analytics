# MoMo SMS Data Processing — C1 Enterprise Web Dev Team 5

An enterprise fullstack application that ingests Mobile Money SMS data in XML, cleans and categorizes it using rule-based regex matching, persists it to MySQL, exposes it through a secured REST API, and visualizes the results in a static dashboard.

## Team Members

- **Hassanat Bello** — Team lead — GitHub: Hassanah-dev006
- **Panom Achok** — GitHub: Achok-kot
- **Pegdwende Savadogo** — GitHub: Pjael

## Links

- **Architecture diagram:** [`docs/architecture.svg`](docs/architecture.svg)
- **Entity Relationship Diagram:** [`docs/erd.png`](docs/erd.png)
- **API documentation:** [`docs/api_docs.md`](docs/api_docs.md)
- **Scrum board (GitHub Projects):** https://github.com/users/Hassanah-dev006/projects/1
- **Full design rationale:** https://docs.google.com/document/d/1A-k8qb-JMTOKtzK_CQtCwIetedUqeH9p2O098XtPXPU/edit?usp=sharing

## Project overview

The system ingests MoMo SMS notifications exported as XML, parses each message into structured fields, classifies the transaction by type (transfer, airtime, bill payment, deposit, payment), and stores normalized records in a MySQL database. Two consumption surfaces sit on top of that store:

1. **A static dashboard** (`index.html` + `web/`) that reads pre-aggregated metrics from `data/processed/dashboard.json` — fast, deployment-free, suitable for read-only analytics.
2. **A REST API** (`api/`) built on Python's standard-library `http.server`, secured with HTTP Basic Authentication, exposing CRUD operations over transaction records for programmatic clients (mobile apps, partner integrations).

Records that fail parsing or categorization are written to `data/logs/dead_letter/` rather than dropped silently, so data quality issues stay visible.

## Architecture at a Glance

```
XML input  ->  ETL pipeline  ->  MySQL database  ->  ┬─>  JSON export  ->  Static dashboard
(raw SMS)      (parse, clean,     (normalized        │    (aggregates       (HTML/CSS/JS)
               categorize, load)   transactions)     │     for frontend)
                                                     │
                                                     └─>  REST API (http.server)
                                                          with Basic Auth
                                                          (CRUD endpoints)
```

The ETL runs in batch. The dashboard reads a pre-computed `data/processed/dashboard.json`. The REST API serves in-memory transaction records loaded from the parsed XML at startup, secured with Basic Authentication on every endpoint.

## Project structure

```
.
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
│   ├── processed/                    # Dashboard JSON output, parsed transactions
│   └── logs/
│       ├── etl.log
│       └── dead_letter/              # Unparsed XML records
├── etl/
│   ├── parse_xml.py                  # XML parsing with classify-then-extract
│   ├── clean_normalize.py            # Amount, date, phone normalization
│   ├── categorize.py                 # Transaction type rules
│   ├── load_db.py                    # Database insert with idempotency
│   └── run.py                        # End-to-end pipeline entry point
├── api/                              # REST API (Week 3)
│   ├── server.py                     # http.server entry point
│   ├── handlers.py                   # CRUD route handlers
│   ├── auth.py                       # Basic Auth enforcement
│   └── data_store.py                 # In-memory transaction store
├── dsa/                              # Data structure comparison (Week 3)
│   ├── search_comparison.py          # Linear search vs. dict lookup
│   └── benchmark_results.md          # Timing results and reflection
├── database/
│   └── database_setup.sql            # Schema DDL + sample DML
├── docs/
│   ├── erd_diagram.png               # Entity relationship diagram
│   ├── design_rationale.md           # Database design justification
│   ├── data_dictionary.md            # Column-level documentation
│   └── api_docs.md                   # REST API endpoint reference
├── examples/
│   └── json_schemas/                 # JSON serialization examples
├── screenshots/                      # API test evidence (Week 3)
├── scripts/
│   ├── run_etl.sh
│   ├── export_json.sh
│   ├── serve_frontend.sh
│   └── run_api.sh
└── tests/
    ├── test_parse_xml.py
    ├── test_clean_normalize.py
    └── test_categorize.py
```

## Database Design

### Entity Overview

The database is built around six entities:

- **users** — Customer accounts identified by phone number
- **transactions** — System of record for all MoMo transactions
- **transaction_categories** — Transaction type classification (transfer, airtime, etc.)
- **tags** — Analytical labels applied to transactions
- **transaction_tags** — Junction table resolving the many-to-many between transactions and tags
- **system_logs** — ETL pipeline event log with optional reference to specific transactions

### Key Design Decisions

1. **Money is stored as `DECIMAL(15,2)`, never `FLOAT`.** Financial aggregations must reconcile to the cent; floating-point accumulates rounding errors.
2. **`sender_id` and `receiver_id` are nullable foreign keys.** Some MoMo activities (airtime, balance checks, service fees) have no second party; nullability reflects the domain rather than forcing phantom records.
3. **`external_ref` is UNIQUE on the transactions table.** This is the MoMo transaction ID extracted from each SMS and acts as the ETL idempotency key — re-running the parser on the same XML cannot create duplicates.
4. **The M:N relationship is between transactions and tags**, resolved through the `transaction_tags` junction. Categories are 1:M (each transaction has exactly one category), but tags are analytical and a transaction can carry multiple ("high-value," "recurring," "flagged-for-review").
5. **Indexes on `transaction_date` and `category_id`** support the dashboard's most frequent query patterns: time-windowed aggregation and category-level breakdowns.
6. **`CHECK (amount >= 0)` and NOT NULL constraints** enforce domain invariants at the database layer rather than relying on application code.

## REST API

The API is implemented in plain Python using `http.server` from the standard library (no Flask, FastAPI, or other framework). It exposes CRUD operations over transaction records and enforces HTTP Basic Authentication on every endpoint.

### Endpoints

| Method | Path | Purpose | Success status |
|--------|------|---------|----------------|
| GET    | `/transactions`      | List all transactions       | 200 |
| GET    | `/transactions/{id}` | Retrieve one transaction    | 200 |
| POST   | `/transactions`      | Create a new transaction    | 201 |
| PUT    | `/transactions/{id}` | Update an existing record   | 200 |
| DELETE | `/transactions/{id}` | Delete a record             | 200 |

All endpoints return `401 Unauthorized` with a `WWW-Authenticate: Basic` header for missing or invalid credentials. Nonexistent IDs return `404 Not Found`. Malformed request bodies return `400 Bad Request`.

Full request/response examples and error codes are documented in [`docs/api_docs.md`](docs/api_docs.md). Test evidence (curl screenshots) lives in [`screenshots/`](screenshots/).

### Running the API

```bash
python3 api/server.py
```

The server binds to `http://localhost:8000` and loads transactions into memory from the parsed XML at startup. State changes (POST/PUT/DELETE) persist only for the lifetime of the process — persistent storage is the database layer's responsibility and is out of scope for the API task.

### Authentication

The API uses HTTP Basic Authentication. Credentials are hardcoded for the assignment (`api/auth.py`); in production these would come from environment variables and the password would be stored as a salted hash. See the project report for a full discussion of Basic Auth's limitations and recommended alternatives (JWT, OAuth 2.0).

## Data Structures & Algorithms

The `dsa/` folder contains a comparison between linear search and dictionary lookup for retrieving transactions by ID, benchmarked across multiple dataset sizes. See [`dsa/benchmark_results.md`](dsa/benchmark_results.md) for the timing results and analysis of why hash-based lookup outperforms linear scan, including discussion of alternative data structures (binary search trees, B-trees) appropriate for different access patterns.

## Setup and Run

### Prerequisites

- Python 3.10+
- MySQL 8.0+ (CHECK constraints are not enforced in older versions)
- A modern browser for the dashboard

### Installation

```bash
git clone <github-repo-url>
cd <repo-name>
python -m venv venv
source venv/bin/activate          # On Windows: venv\Scripts\activate
pip install -r requirements.txt
cp .env.example .env              # Then edit .env with your DB credentials
```

### Database initialization

```bash
mysql -u <user> -p < database/database_setup.sql
```

This creates all tables, indexes, constraints, and inserts sample data (5+ records per main table).

### Running the ETL pipeline

```bash
bash scripts/run_etl.sh
```

This parses `data/raw/momo.xml`, cleans and categorizes records, loads them into the database, and exports `data/processed/dashboard.json`.

### Serving the dashboard

```bash
bash scripts/serve_frontend.sh
```

Then open `http://localhost:8000` in a browser.

### Running the REST API

```bash
bash scripts/run_api.sh
# or directly:
python3 api/server.py
```

Then test with curl:

```bash
curl -i -u admin:password123 http://localhost:8000/transactions
```

### Tests

```bash
pytest tests/ -v
```

Unit tests cover XML parsing, normalization (amounts, dates, phone numbers), and categorization rules. Tests use small inline XML fixtures rather than the full dataset.

## Architectural decisions

These are the choices that aren't obvious from the directory layout:

- **MySQL with InnoDB.** The assignment requires MySQL 8.0+ for enforced CHECK constraints and ENUM types — both used in our schema for domain invariants (non-negative amounts, log levels). InnoDB gives us row-level locking and proper foreign key enforcement, which matters for the ETL's concurrent inserts and referential integrity guarantees.
- **Two consumption paths, not one.** The static dashboard and the REST API serve different audiences. The dashboard reads a pre-aggregated JSON file because it only needs read-only analytics and benefits from zero deployment surface. The API exists for programmatic clients that need CRUD semantics, fresh data, and authentication. Keeping them separate avoids forcing one layer to compromise for the other's needs.
- **`http.server` over Flask/FastAPI for the API.** Chosen to satisfy the assignment constraint, but the tradeoff is real: writing routing and auth by hand surfaces what a framework abstracts away. Production deployment would use FastAPI or similar.
- **Rule-based regex categorization.** SMS bodies follow predictable provider-issued templates, so deterministic regex rules are more accurate and debuggable than ML classification at this scale. Rules live in `etl/parse_xml.py` and `etl/categorize.py` and are covered by unit tests so changes don't silently misclassify past data.
- **Dead-letter queue instead of silent drops.** Any record that fails parsing or categorization is written to `data/logs/dead_letter/` with the original snippet preserved. This makes data-quality failures auditable rather than invisible.
- **In-memory state for the API.** The API holds transaction state in memory during runtime. POST/PUT/DELETE changes do not survive a restart. This matches the assignment scope; production persistence would route mutations through the database layer designed in Week 2.

## Workflow

- One feature per branch; PR into `main`.
- At least one teammate reviews before merge.
- Issues on the GitHub Projects board are the source of truth for ownership; if it's not on the board, no one's working on it.
- `main` should always be in a runnable state — broken code lives on feature branches.

## Deliverables Status

### Week 1
- [x] Team GitHub repository with collaborators
- [x] Project directory structure
- [x] High-level system architecture diagram
- [x] Scrum board with initial tasks

### Week 2
- [x] Entity Relationship Diagram in `docs/`
- [x] Database setup SQL script in `database/`
- [x] JSON schema examples in `examples/`
- [x] Updated README with database design
- [x] Database design PDF document

### Week 3
- [x] XML parser converting SMS records to JSON dictionaries
- [x] REST API in `http.server` with full CRUD endpoints
- [x] HTTP Basic Authentication with `401` responses
- [x] API documentation in `docs/api_docs.md`
- [x] DSA comparison (linear search vs. dictionary lookup) in `dsa/`
- [x] Test evidence screenshots in `screenshots/`
- [x] Project report PDF (in progress)