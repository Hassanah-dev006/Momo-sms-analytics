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