# AI Usage Log

This document records the team's use of AI assistants during the MoMo SMS
Database Design assignment, in accordance with the ALU AI Usage Policy.

## Summary

The team used Anthropic's Claude as a design partner and reviewer during
Week 2 of this project. AI was used for: rubric interpretation, ERD design
critique, JSON example drafting, SQL testing strategy, and documentation
review. All design decisions, code, and final deliverables were reviewed,
modified, and committed by team members. No AI output was used word for word
without team review and adaptation.

## Tools Used

| Tool | Provider | Used By | Purpose |
|---|---|---|---|
| Claude (web interface) | Anthropic | Hassanat Bello (team lead) | Design review, drafting, rubric analysis |


## Detailed Usage by Deliverable

### 1. Assignment Interpretation and Rubric Analysis

**What we did:** Asked Claude to identify gaps between the assignment brief
and the grading rubric, and to flag risks that weren't obvious from reading
the brief alone.

**What the AI contributed:** Pointed out that the rubric required a PDF
deliverable, security rules documentation, and a data dictionary that the
brief didn't mention. Identified that the "200-300 word rationale" target
in the brief was below the rubric's Excellent tier threshold of 250-300+ words.
Flagged that the M:N requirement in the brief would not be satisfied by the
naturally-occurring relationships in the data (users-categories, transactions-categories
are both 1:M) and that we needed to introduce a Tags entity.

**What we did with it:** Used these flags to set our team priorities for
the week. We added the PDF document, data dictionary, and security rules
sections to our Scrum board as explicit tasks. We accepted the Tags
recommendation after team discussion because it matched a real analytical
need for the dashboard.

### 2. ERD Design

**What we did:** After our first ERD draft, asked Claude to review against
the rubric and identify gaps.

**What the AI contributed:** Identified that our initial ERD had:
- A `user` entity that conflated user attributes with transaction attributes
- Money stored as `int` and `string` (should be `DECIMAL`)
- No many-to-many relationship (would automatically cap our ERD score)
- Missing `system_logs` entity
- Inconsistent ID strategy (mixed UUID and INT)
- `sender_phone`/`receiver_phone` as raw strings instead of foreign keys

The AI provided a corrected entity-relationship specification including
table names, column types, constraints, and cardinalities.

**What we did with it:** The team reviewed the proposed schema in a call,
accepted most recommendations, and made the following modifications:
- *[List actual changes your team made — e.g., "renamed 'descriptor' columns
  to 'description'", "added/removed specific columns based on actual XML data",
  "adjusted cardinality on X relationship after reviewing sample data"]*

The Draw.io diagram was created by Pegdwende Savadogo working from the
specification. Subsequent rounds of feedback caught a mislabeled junction
table (`Transaction_categories` should have been `transaction_tags`),
a typo in a CHECK constraint, and inconsistent relationship labels — all
fixed before commit.

### 3. JSON Data Modeling

**What we did:** Asked Claude to draft JSON examples and an SQL-to-JSON
mapping document based on the finalized ERD.

**What the AI contributed:** Drafts of per-entity JSON files, a composite
`transaction_full.json` showing denormalized API response shape, a
`dashboard_aggregate.json` example, and a mapping document explaining
the rationale for denormalization choices (e.g., why junction tables
should not appear in JSON output).

**What we did with it:** replaced fabricated phone numbers with values matching our sample SQL data",
"adjusted the currency handling section after team discussion about
single-currency vs multi-currency scope", "removed the _links hypermedia
section because it added complexity without serving our dashboard.


### 4. Documentation

**What we did:** Used Claude to draft the design rationale section
(target length 250-300 words for the rubric's Excellent tier) and to
review the README for contradictions.

**What the AI contributed:** A rationale draft covering nullability of
sender/receiver FKs, DECIMAL precision choice, idempotency via `external_ref`
UNIQUE constraint, choice of M:N location (transactions↔tags), and indexing
strategy.

**What we did with it:** Added a sentence acknowledging a design limitation we accepted", "removed reference to FLOAT/DOUBLE
alternatives because it added word count without adding insight.

## Where We Disagreed With or Overrode the AI

This section records cases where the team did NOT follow AI suggestions:

- * AI initially recommended placing the M:N relationship
  between Users and Categories. After reviewing actual MoMo SMS samples,
  the team determined this didn't reflect real data and chose Transactions↔Tags
  instead.
- * The AI suggested including hypermedia `_links` in the JSON
  output. The team removed this because it added complexity without serving
  our static dashboard.


## What the AI Did NOT Do


- The AI did not write `database_setup.sql`. The DDL was written by
  *Hassanat bello* based on the ERD specification.
- The AI did not create the Draw.io diagram. The diagram was drawn by
  *[Pegdwende Savadogo]*.
- The AI did not run any tests against the database. All test execution
  and screenshot capture was performed by team members.
- The AI did not write the PDF document. The PDF was assembled by
  *[Panom Kot]* from the team's existing documentation.
- The AI did not commit anything to the repository. All commits are
  attributable to individual team members via Git history.

## Reflection on Policy Compliance

We treated the AI as a senior reviewer — useful for catching gaps,
challenging assumptions, and drafting boilerplate documentation, rather
than as a substitute for the team's own work. Every AI-generated artifact
was reviewed, modified where appropriate, and committed by a human team
member who understood it well enough to defend it in a code review.

The team can explain every design decision in this project, including
the ones that originated as AI suggestions, in our own words and with
our own reasoning.

---

*Log maintained by: Hassanat Bello*
*Last updated: [15/05/2026]*