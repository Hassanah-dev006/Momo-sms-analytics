"""
auth.py
HTTP Basic Authentication for the API.

Basic Auth sends 'Authorization: Basic <base64(user:pass)>' on every request.
We decode it and compare against configured credentials. This is deliberately
simple — see the report for why Basic Auth is weak and what to use instead
(JWT, OAuth2) in production.
"""

import base64
import binascii
import hmac

# Demo credentials. In a real system these would come from env vars / a secrets
# manager and the password would be a HASH, never plaintext.
VALID_USERNAME = "admin"
VALID_PASSWORD = "password123"


def _constant_time_equals(a, b):
    """Compare two strings without leaking length/contents via timing."""
    return hmac.compare_digest(a.encode("utf-8"), b.encode("utf-8"))


def is_authorized(auth_header):
    """
    Validate an Authorization header value.
    Returns True only for a correct 'Basic base64(user:pass)' header.
    """
    if not auth_header:
        return False

    parts = auth_header.split(" ", 1)
    if len(parts) != 2 or parts[0].lower() != "basic":
        return False

    try:
        decoded = base64.b64decode(parts[1], validate=True).decode("utf-8")
    except (binascii.Error, UnicodeDecodeError):
        return False

    if ":" not in decoded:
        return False

    username, password = decoded.split(":", 1)
    # Check BOTH even if username is wrong, to keep timing constant.
    user_ok = _constant_time_equals(username, VALID_USERNAME)
    pass_ok = _constant_time_equals(password, VALID_PASSWORD)
    return user_ok and pass_ok