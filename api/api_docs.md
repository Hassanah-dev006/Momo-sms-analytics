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

**Response — 200 OK**
```json
[
  {
    "id": 1,
    "transaction_type": "RECEIVE",
    "amount": 2000.0,
    "fee": 0.0,
    "sender": "Jane Smith",
    "receiver": null,
    "balance_after": 2000.0,
    "external_ref": "76662021700",
    "timestamp": "2024-05-10 16:30:51",
    "is_transaction": true,
    "raw_body": "You have received 2000 RWF from Jane Smith ..."
  }
]
```

---

### GET /transactions/{id}

Retrieve a single transaction by id.

**Request**
```bash
curl -u admin:password123 http://localhost:8000/transactions/3
```

**Response — 200 OK**
```json
{
  "id": 3,
  "transaction_type": "PAYMENT",
  "amount": 600.0,
  "fee": 0.0,
  "sender": null,
  "receiver": "Samuel Carter",
  "balance_after": 400.0,
  "external_ref": "51732411227",
  "timestamp": "2024-05-10 21:32:32",
  "is_transaction": true,
  "raw_body": "TxId: 51732411227. Your payment of 600 RWF ..."
}
```

**Response — 404 Not Found**
```json
{ "error": "Transaction not found" }
```

---

### POST /transactions

Create a new transaction. The server assigns the `id`.

**Request**
```bash
curl -u admin:password123 -X POST http://localhost:8000/transactions \
  -H "Content-Type: application/json" \
  -d '{
        "transaction_type": "PAYMENT",
        "amount": 7500,
        "receiver": "Test Vendor",
        "fee": 0,
        "timestamp": "2024-12-01 10:00:00",
        "is_transaction": true
      }'
```

**Response — 201 Created** (returns the created object with its new `id`)
```json
{
  "transaction_type": "PAYMENT",
  "amount": 7500,
  "receiver": "Test Vendor",
  "fee": 0,
  "timestamp": "2024-12-01 10:00:00",
  "is_transaction": true,
  "id": 1682
}
```

**Response — 400 Bad Request** (invalid or empty body)
```json
{ "error": "Field 'amount' must be a number" }
```

---

### PUT /transactions/{id}

Update an existing transaction. This is a **partial update**: only the fields
included in the body are changed; all others are preserved. The `id` cannot be
changed.

**Request**
```bash
curl -u admin:password123 -X PUT http://localhost:8000/transactions/1682 \
  -H "Content-Type: application/json" \
  -d '{ "amount": 9999 }'
```

**Response — 200 OK** (returns the full updated object)
```json
{
  "id": 1682,
  "transaction_type": "PAYMENT",
  "amount": 9999,
  "receiver": "Test Vendor",
  "fee": 0,
  "timestamp": "2024-12-01 10:00:00",
  "is_transaction": true
}
```

**Response — 404 Not Found**
```json
{ "error": "Transaction not found" }
```

---

### DELETE /transactions/{id}

Delete a transaction by id.

**Request**
```bash
curl -u admin:password123 -X DELETE http://localhost:8000/transactions/1682