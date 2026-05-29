"""
server.py
A REST API for MoMo SMS transactions built with ONLY the Python standard
library (http.server) — no Flask, no FastAPI.

Endpoints (all require HTTP Basic Auth):
  GET    /transactions          list all transactions
  GET    /transactions/{id}     get one transaction
  POST   /transactions          create a transaction (JSON body)
  PUT    /transactions/{id}     update a transaction (JSON body)
  DELETE /transactions/{id}     delete a transaction

Run:
  python3 api/server.py
Then (in another terminal):
  curl -u admin:password123 http://localhost:8000/transactions
"""

import json
import re
import sys
import os
from http.server import BaseHTTPRequestHandler, HTTPServer

# Make sibling modules importable whether run from repo root or api/.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import data_store
import auth

HOST = "0.0.0.0"
PORT = int(os.environ.get("PORT", 8000))

# Matches /transactions/123 and captures the id.
ID_ROUTE = re.compile(r"^/transactions/(\d+)/?$")
COLLECTION_ROUTE = re.compile(r"^/transactions/?$")


class TransactionHandler(BaseHTTPRequestHandler):

    # ---- small response helpers ------------------------------------------

    def _send_json(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False, indent=2).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_401(self):
        # WWW-Authenticate triggers the browser's login prompt and tells
        # clients which scheme to use. Required for correct Basic Auth.
        self.send_response(401)
        self.send_header("WWW-Authenticate", 'Basic realm="MoMo API"')
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.end_headers()
        self.wfile.write(json.dumps({"error": "Unauthorized"}).encode("utf-8"))

    def _read_json_body(self):
        """Read and parse a JSON request body. Returns (data, error_string)."""
        length = int(self.headers.get("Content-Length", 0))
        if length == 0:
            return None, "Request body is empty"
        raw = self.rfile.read(length)
        try:
            return json.loads(raw.decode("utf-8")), None
        except (json.JSONDecodeError, UnicodeDecodeError):
            return None, "Request body is not valid JSON"

    def _authed(self):
        """Gate every request behind Basic Auth. Sends 401 if it fails."""
        if auth.is_authorized(self.headers.get("Authorization")):
            return True
        self._send_401()
        return False

    @staticmethod
    def _validate_transaction(data):
        """Minimal validation for POST/PUT bodies. Returns error string or None."""
        if not isinstance(data, dict):
            return "Body must be a JSON object"
        if "amount" in data:
            try:
                float(data["amount"])
            except (TypeError, ValueError):
                return "Field 'amount' must be a number"
        if "transaction_type" in data and not isinstance(data["transaction_type"], str):
            return "Field 'transaction_type' must be a string"
        return None

    # ---- HTTP method dispatch --------------------------------------------

    def do_GET(self):
        if not self._authed():
            return

        if COLLECTION_ROUTE.match(self.path):
            self._send_json(200, data_store.list_all())
            return

        m = ID_ROUTE.match(self.path)
        if m:
            txn = data_store.get(int(m.group(1)))
            if txn is None:
                self._send_json(404, {"error": "Transaction not found"})
            else:
                self._send_json(200, txn)
            return

        self._send_json(404, {"error": "Route not found"})

    def do_POST(self):
        if not self._authed():
            return

        if not COLLECTION_ROUTE.match(self.path):
            self._send_json(404, {"error": "Route not found"})
            return

        data, err = self._read_json_body()
        if err:
            self._send_json(400, {"error": err})
            return

        verr = self._validate_transaction(data)
        if verr:
            self._send_json(400, {"error": verr})
            return

        created = data_store.create(data)
        self._send_json(201, created)

    def do_PUT(self):
        if not self._authed():
            return

        m = ID_ROUTE.match(self.path)
        if not m:
            self._send_json(404, {"error": "Route not found"})
            return

        data, err = self._read_json_body()
        if err:
            self._send_json(400, {"error": err})
            return

        verr = self._validate_transaction(data)
        if verr:
            self._send_json(400, {"error": verr})
            return

        updated = data_store.update(int(m.group(1)), data)
        if updated is None:
            self._send_json(404, {"error": "Transaction not found"})
        else:
            self._send_json(200, updated)

    def do_DELETE(self):
        if not self._authed():
            return

        m = ID_ROUTE.match(self.path)
        if not m:
            self._send_json(404, {"error": "Route not found"})
            return

        if data_store.delete(int(m.group(1))):
            self._send_json(200, {"message": "Transaction deleted"})
        else:
            self._send_json(404, {"error": "Transaction not found"})

    # Quieter logging (optional). Comment out to see default request logs.
    def log_message(self, fmt, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))


def main():
    count = data_store.load()
    print(f"Loaded {count} transactions into memory.")
    server = HTTPServer((HOST, PORT), TransactionHandler)
    print(f"Serving on http://localhost:{PORT}  (Ctrl+C to stop)")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.server_close()


if __name__ == "__main__":
    main()