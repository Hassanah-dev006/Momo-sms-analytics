# MoMo SMS Transactions API — Documentation

A REST API over parsed MoMo SMS transaction data, built with the Python
standard library (`http.server`) — no external web framework.

- **Base URL:** `http://localhost:8000`
- **Content type:** `application/json` (request and response)
- **Authentication:** HTTP Basic Auth on **every** endpoint

## Authentication

All endpoints require HTTP Basic Authentication. Send an `Authorization` header
of the form `Basic <base64(username:password)>`. With `curl`, the `-u` flag does
this for you.

Demo credentials (configured in `api/auth.py`):

| Field | Value |
|---|---|
| username | `admin` |
| password | `password123` |

A request with a missing or incorrect credential receives `401 Unauthorized`
with a `WWW-Authenticate: Basic realm="MoMo API"` response header.

> These credentials are hardcoded for demonstration only. See the security
> report for why this — and Basic Auth generally — is unsuitable for production.

## Data model

A transaction object has the following fields:

| Field | Type | Notes |
|---|---|---|
| `id` | integer | Server-assigned, unique, stable within a server run |
| `transaction_type` | string | e.g. `RECEIVE`, `PAYMENT`, `TRANSFER`, `DEPOSIT`, `WITHDRAWAL` |
| `amount` | number | Transaction amount in RWF |
| `fee` | number | Fee charged, in RWF (0 if none) |
| `sender` | string \| null | Sending party, where identified |
| `receiver` | string \| null | Receiving party, where identified |
| `balance_after` | number \| null | Account balance after the transaction |
| `external_ref` | string \| null | MoMo Financial Transaction Id, where present |
| `timestamp` | string | ISO-style datetime |
| `is_transaction` | boolean | `false` for non-balance events (FAILED, REVERSAL) |
| `raw_body` | string | Original SMS text (provenance) |

---

## Endpoints

### GET /transactions

List all transactions.

**Request**
```bash
curl -u admin:password123 http://localhost:8000/transactions
```
