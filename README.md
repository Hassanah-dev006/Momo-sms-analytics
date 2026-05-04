# Momo-sms-analytics
# [C1 Enterprise Web Development Team 5]

## Project Description
An enterprise-level fullstack application that processes MoMo (Mobile Money) SMS transaction data from XML, cleans and categorizes it into a relational database, and exposes the data through a web dashboard for analysis and visualization.

The system has three layers:
- **ETL pipeline** (Python): parses XML, normalizes amounts and dates, classifies transactions by type, and loads them into SQLite.
- **Data store** (SQLite): relational schema for transactions, categories, and raw message provenance.
- **Frontend dashboard** (HTML/CSS/JS): reads aggregated data and renders charts, tables, and filters for transaction analysis.

## Team Members
- [Hassanat Ajoke Bello] — [Hassanah-dev006] — [role: ETL Pipeline & database]
- [Full Name 2] — [GitHub username] — [role:  Categorization & Data Quality]
- [Full Name 3] — [GitHub username] — [role: Frontend & JSON Contract]

## Project Status
Week 1 — setup and planning. Architecture and Scrum board links to be added.

## Architecture Diagram
*To be added.*

## Scrum Board
*To be added.*

## Tech Stack
- **Backend / ETL**: Python 3, ElementTree (or lxml), SQLite
- **Frontend**: HTML, CSS, vanilla JavaScript
- **Tooling**: Git, GitHub Projects