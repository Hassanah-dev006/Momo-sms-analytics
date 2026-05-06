MoMo SMS Data Processing — [C1 TEAM 5]
An enterprise fullstack application that ingests Mobile Money SMS data in XML, cleans and categorizes it using rule-based regex matching, persists it to SQLite, and visualizes the results in a static dashboard.



## Team Members

Hassanat Bello — Team lead
Panom Achok
Pegdwende Savadogo

## Links

Architecture diagram: [paste draw.io / Miro link here]
Scrum board (GitHub Projects): [(https://github.com/users/Hassanah-dev006/projects/1/views/1)]

## Project overview
The pipeline is one-way and batch-oriented: raw XML in data/raw/momo.xml is parsed, cleaned, categorized, and loaded into a SQLite database at data/db.sqlite3. A separate export step writes pre-aggregated metrics to data/processed/dashboard.json, which the static frontend reads directly. There is no backend server in front of the database — the dashboard is a static HTML/CSS/JS bundle served over plain HTTP.
Records that fail parsing or categorization are written to data/logs/dead_letter/ rather than dropped silently, so data quality issues stay visible.


## Project structure
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