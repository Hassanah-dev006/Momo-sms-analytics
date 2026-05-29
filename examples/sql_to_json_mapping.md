# SQL-to-JSON Mapping Documentation

This document explains how the relational schema in `database/database_setup.sql`
is serialized into the JSON structures in this folder.

## Mapping Philosophy

The relational schema and the JSON API surface are designed for different
purposes. The schema optimizes for storage efficiency, referential integrity,
and query flexibility — hence the normalized design with junction tables and
foreign keys. The JSON representations optimize for client consumption —
hence denormalization, nested related entities, and the elimination of
junction tables from the response shape.

We provide two layers of JSON:

1. **Per-entity JSON** (`user.json`, `transaction.json`, etc.) — mirrors
   the SQL row structure. Used internally by the ETL pipeline and for simple
   single-resource API endpoints like `GET /users/{id}`.

2. **Composite JSON** (`transaction_full.json`, `dashboard_aggregate.json`) —
   denormalized API responses for clients that need related data in a single
   request. These would be served by endpoints like `GET /transactions/{id}?include=full`
   or read from the pre-computed `data/processed/dashboard.json` by the frontend.

## Field-Level Mapping

### `users` table → `user.json`

| SQL Column | JSON Field | Type Transformation |
|---|---|---|
| `user_id` (INT) | `user_id` (number) | direct |
| `phone_number` (VARCHAR(20)) | `phone_number` (string) | direct, E.164 format preserved |
| `display_name` (VARCHAR(100)) | `display_name` (string \| null) | NULL → JSON null |
| `first_seen_at` (DATETIME) | `first_seen_at` (string) | formatted as ISO 8601 with Z suffix |
| `is_business` (TINYINT(1)) | `is_business` (boolean) | 0/1 → false/true |

### `transactions` table → `transaction.json` (flat)

| SQL Column | JSON Field | Notes |
|---|---|---|
| `transaction_id` (BIGINT) | `transaction_id` (number) | direct |
| `external_ref` (VARCHAR(100)) | `external_ref` (string) | MoMo transaction ID from SMS |
| `sender_id` (INT, FK) | `sender_id` (number \| null) | retained in flat form for internal use |
| `receiver_id` (INT, FK) | `receiver_id` (number \| null) | retained in flat form for internal use |
| `category_id` (INT, FK) | `category_id` (number) | retained in flat form |
| `amount` (DECIMAL(15,2)) | `amount` (number) | JSON number; clients should parse as fixed-decimal |
| `fee` (DECIMAL(15,2)) | `fee` (number) | same |
| `balance_after` (DECIMAL(15,2)) | `balance_after` (number \| null) | same |
| `transaction_date` (DATETIME) | `transaction_date` (string) | ISO 8601 |
| `raw_message` (TEXT) | `raw_message` (string) | original SMS body |

### `transactions` table → `transaction_full.json` (composite)

| Source | JSON Path | Transformation |
|---|---|---|
| `transactions.*` | top-level fields | direct |
| `users` JOIN on `sender_id` | `sender` object | nested object |
| `users` JOIN on `receiver_id` | `receiver` object | nested object |
| `transaction_categories` JOIN on `category_id` | `category` object | nested object |
| `tags` JOIN through `transaction_tags` | `tags` array | array of objects, junction table flattened |
| `system_logs` WHERE `transaction_id` matches | `processing.logs` array | nested under `processing` |
| (computed) | `_links` object | hypermedia for client navigation |
| (constant) | `currency` field | added at serialization; not stored per-row since system is single-currency |

### Junction Table Handling

`transaction_tags` does not appear in any JSON output as a standalone entity.
This is intentional. Junction tables are an implementation detail of the
relational model and should not leak into the API surface. In `transaction_full.json`,
the M:N relationship is expressed as `transaction.tags[]` — a flat array of
tag objects. The `tagged_at` timestamp from the junction row is dropped in
the API representation; if needed, it could be added as a property on each
tag object within the array.

### Null Handling

SQL `NULL` maps to JSON `null` in all cases. We do not omit null fields from
JSON output, because clients should not have to distinguish between "field
absent" and "field is null" — this avoids a class of front-end bugs.

### Decimal Precision

Monetary fields stored as `DECIMAL(15,2)` in SQL are serialized as JSON
numbers. We acknowledge this is technically lossy — JSON numbers are IEEE 754
doubles and cannot exactly represent all decimal values. For the scale of
amounts in this system (RWF, max ~10^13), precision is preserved. A production
system at higher scale should serialize money as strings (e.g., `"25000.00"`)
to avoid floating-point representation entirely. We chose numeric for
readability and frontend simplicity.