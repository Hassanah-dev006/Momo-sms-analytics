"""
data_store.py
Loads the parsed transactions into memory and provides CRUD operations.

State is held in a module-level list plus an id->record dict for O(1) lookup.
NOTE: mutations (POST/PUT/DELETE) are in-memory only. Restarting the server
resets state to whatever is in data/processed/transactions.json.
"""

import json
import os
import threading

# Path to the JSON produced by etl/parse_xml.py
DATA_PATH = os.environ.get(
    "TRANSACTIONS_JSON",
    os.path.join("data", "processed", "transactions.json"),
)

# A lock so concurrent requests don't corrupt the list/dict.
# http.server is single-threaded by default, but this makes intent explicit
# and keeps us safe if a threaded server is used later.
_lock = threading.Lock()

_transactions = []      # list of dicts (preserves order)
_index = {}             # id -> dict (fast lookup)
_next_id = 1


def load(path=None):
    """Load transactions from JSON into memory. Called once at startup."""
    global _transactions, _index, _next_id
    path = path or DATA_PATH
    with open(path, "r", encoding="utf-8") as f:
        records = json.load(f)
    with _lock:
        _transactions = records
        _index = {r["id"]: r for r in records}
        _next_id = (max(_index) + 1) if _index else 1
    return len(records)


def list_all():
    """Return all transactions (list of dicts)."""
    with _lock:
        return list(_transactions)


def get(txn_id):
    """Return one transaction by id, or None."""
    with _lock:
        return _index.get(txn_id)


def create(data):
    """Insert a new transaction. Assigns the next id. Returns the new record."""
    global _next_id
    with _lock:
        record = dict(data)
        record["id"] = _next_id
        _transactions.append(record)
        _index[_next_id] = record
        _next_id += 1
        return record


def update(txn_id, data):
    """Replace fields of an existing transaction. Returns updated record or None."""
    with _lock:
        record = _index.get(txn_id)
        if record is None:
            return None
        # keep the id stable; overwrite everything else provided
        for key, value in data.items():
            if key != "id":
                record[key] = value
        return record


def delete(txn_id):
    """Remove a transaction by id. Returns True if removed, False if not found."""
    with _lock:
        record = _index.pop(txn_id, None)
        if record is None:
            return False
        _transactions.remove(record)
        return True