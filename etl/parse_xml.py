"""
parse_xml.py
Parse MoMo SMS backup XML into a list of transaction dicts.

Each SMS body is first CLASSIFIED into a message type, then a targeted
extractor pulls the fields for that type. Messages we can't classify, plus
deliberate non-transactions (OTP codes), are routed to a dead-letter list
with a documented reason instead of crashing the run.

Transaction types handled:
  RECEIVE          - "You have received X RWF from ..."
  PAYMENT          - "TxId: ... Your payment of X RWF to <name> <code> ..."
  AIRTIME          - "*162*TxId:...*S*Your payment of X RWF to Airtime ..."
  TRANSFER         - "*165*S*X RWF transferred to <name> (number) ..."
  TRANSFER_OUT     - "You have transferred X RWF to <name> (number) ..."
  DEPOSIT          - "*113*R*A bank deposit of X RWF has been added ..."
  MERCHANT_PAYMENT - "*164*S*Y'ello,A transaction of X RWF by <company> ..."
  WITHDRAWAL       - "You <name> (...) have via agent: ... withdrawn X RWF ..."
  REVERSAL         - "*143*S*Your transaction to <name> ... has been reversed ..."
  FAILED           - "*143*R*... the transaction with amount X ... failed ..."
  DATA_BUNDLE      - "Yello!Umaze kugura ... igura X RWF" (Kinyarwanda)

Intentionally dropped (logged, not parsed):
  IGNORED_OTP      - "<#> Dear Customer ..." app verification codes
"""

import re
import json
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

# Shared timestamp pattern: "at 2024-05-14 21:01:00"
TS = r"at\s+(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})"


# --- helpers -----------------------------------------------------------------

def clean_amount(raw):
    """'10,900' -> 10900.0 ; '0' -> 0.0 ; '' or None -> None"""
    if raw is None:
        return None
    raw = raw.replace(",", "").strip()
    return float(raw) if raw else None


def epoch_ms_to_iso(ms):
    """Convert the SMS 'date' attribute (epoch ms) to ISO 8601."""
    if not ms:
        return None
    return datetime.fromtimestamp(int(ms) / 1000, tz=timezone.utc).isoformat()


def find(pattern, text, group=1, flags=0):
    """Regex search; return the stripped captured group, or None."""
    m = re.search(pattern, text, flags)
    return m.group(group).strip() if m else None


# --- classification ----------------------------------------------------------

def classify(body):
    """Return the message type for an SMS body."""
    if body.startswith("<#>"):
        return "IGNORED_OTP"
    if body.startswith("Yello!Umaze kugura"):
        return "DATA_BUNDLE"
    if body.startswith("You have received"):
        return "RECEIVE"
    if "withdrawn" in body:
        return "WITHDRAWAL"
    if "bank deposit" in body.lower():
        return "DEPOSIT"
    if "*164*S*Y'ello,A transaction of" in body:
        return "MERCHANT_PAYMENT"
    if "You have transferred" in body:
        return "TRANSFER_OUT"
    if "transferred to" in body:
        return "TRANSFER"
    if body.startswith("*143*S*") and "reversed" in body:
        return "REVERSAL"
    if body.startswith("*143*R*") and "failed" in body:
        return "FAILED"
    if "to Airtime" in body:
        return "AIRTIME"
    if "Your payment of" in body:
        return "PAYMENT"
    return "UNKNOWN"


# --- extractors --------------------------------------------------------------

def extract_receive(body):
    return {
        "amount": clean_amount(find(r"received\s+([\d,]+)\s*RWF", body)),
        "sender": find(r"from\s+(.+?)\s*\(", body),
        "receiver": None,
        "fee": 0.0,
        "balance_after": clean_amount(find(r"[Bb]alance\s*:?\s*([\d,]+)\s*RWF", body)),
        "external_ref": find(r"Financial Transaction Id:\s*(\d+)", body),
        "occurred_at": find(TS, body),
    }


def extract_payment(body):
    return {
        "amount": clean_amount(find(r"payment of\s+([\d,]+)\s*RWF", body)),
        "sender": None,
        "receiver": find(r"to\s+(.+?)\s+\d+\s+has been completed", body),
        "fee": clean_amount(find(r"Fee was\s+([\d,]+)\s*RWF", body)) or 0.0,
        "balance_after": clean_amount(find(r"new balance:\s*([\d,]+)\s*RWF", body, flags=re.IGNORECASE)),
        "external_ref": find(r"TxId:\s*(\d+)", body),
        "occurred_at": find(TS, body),
    }


def extract_airtime(body):
    return {
        "amount": clean_amount(find(r"payment of\s+([\d,]+)\s*RWF", body)),
        "sender": None,
        "receiver": "Airtime",
        "fee": clean_amount(find(r"Fee was\s+([\d,]+)\s*RWF", body)) or 0.0,
        "balance_after": clean_amount(find(r"new balance:\s*([\d,]+)\s*RWF", body, flags=re.IGNORECASE)),
        "external_ref": find(r"TxId:\s*(\d+)", body),
        "occurred_at": find(TS, body),
    }


def extract_transfer(body):
    return {
        "amount": clean_amount(find(r"\*S\*([\d,]+)\s*RWF transferred", body)),
        "sender": None,
        "receiver": find(r"transferred to\s+(.+?)\s*\(", body),
        "fee": clean_amount(find(r"Fee was:\s*([\d,]+)\s*RWF", body)) or 0.0,
        "balance_after": clean_amount(find(r"New balance:\s*([\d,]+)\s*RWF", body, flags=re.IGNORECASE)),
        "external_ref": None,
        "occurred_at": find(TS, body),
    }


def extract_transfer_out(body):
    # "You have transferred 50000 RWF to Linda Green (250795963036) ... balance may be empty"
    return {
        "amount": clean_amount(find(r"transferred\s+([\d,]+)\s*RWF", body)),
        "sender": None,
        "receiver": find(r"to\s+(.+?)\s*\(", body),
        "fee": 0.0,
        "balance_after": clean_amount(find(r"new balance:\s*([\d,]+)\s*RWF", body, flags=re.IGNORECASE)),
        "external_ref": find(r"Financial Transaction Id:\s*(\d+)", body),
        "occurred_at": find(TS, body),
    }


def extract_deposit(body):
    return {
        "amount": clean_amount(find(r"bank deposit of\s+([\d,]+)\s*RWF", body)),
        "sender": "Bank",
        "receiver": None,
        "fee": 0.0,
        "balance_after": clean_amount(find(r"BALANCE\s*:?\s*([\d,]+)\s*RWF", body, flags=re.IGNORECASE)),
        "external_ref": None,
        "occurred_at": find(TS, body),
    }


def extract_merchant_payment(body):
    # "*164*S*Y'ello,A transaction of 25000 RWF by DIRECT PAYMENT LTD on your MOMO account ..."
    return {
        "amount": clean_amount(find(r"transaction of\s+([\d,]+)\s*RWF", body)),
        "sender": None,
        "receiver": find(r"RWF by\s+(.+?)\s+on your MOMO", body),
        "fee": clean_amount(find(r"Fee was\s+([\d,]+)\s*RWF", body)) or 0.0,
        "balance_after": clean_amount(find(r"new balance:\s*([\d,]+)\s*RWF", body, flags=re.IGNORECASE)),
        "external_ref": find(r"Financial Transaction Id:\s*(\d+)", body),
        "occurred_at": find(TS, body),
    }


def extract_withdrawal(body):
    # "You <name> (...) have via agent: Agent Sophia (...) withdrawn 20000 RWF ..."
    return {
        "amount": clean_amount(find(r"withdrawn\s+([\d,]+)\s*RWF", body)),
        "sender": find(r"agent:\s*(.+?)\s*\(", body),       # the agent dispensing cash
        "receiver": find(r"^You\s+(.+?)\s*\(", body),         # the account owner
        "fee": clean_amount(find(r"Fee paid:\s*([\d,]+)\s*RWF", body)) or 0.0,
        "balance_after": clean_amount(find(r"new balance:\s*([\d,]+)\s*RWF", body, flags=re.IGNORECASE)),
        "external_ref": find(r"Financial Transaction Id:\s*(\d+)", body),
        "occurred_at": find(TS, body),
    }


def extract_reversal(body):
    # "*143*S*Your transaction to <name> (...) with 3000 RWF has been reversed ... new balance is X"
    return {
        "amount": clean_amount(find(r"with\s+([\d,]+)\s*RWF", body)),
        "sender": None,
        "receiver": find(r"transaction to\s+(.+?)\s*\(", body),
        "fee": 0.0,
        "balance_after": clean_amount(find(r"new balance is\s+([\d,]+)\s*RWF", body, flags=re.IGNORECASE)),
        "external_ref": None,
        "occurred_at": find(TS, body),
    }


def extract_failed(body):
    # "*143*R*... the transaction with amount 14200 RWF for ESICIA LTD ... failed ..."
    return {
        "amount": clean_amount(find(r"amount\s+([\d,]+)\s*RWF", body)),
        "sender": None,
        "receiver": find(r"for\s+(.+?)\s+with message", body),
        "fee": 0.0,
        "balance_after": None,   # failed: no balance change
        "external_ref": None,
        "occurred_at": find(TS, body),
    }


def extract_data_bundle(body):
    # "Yello!Umaze kugura <bundle details> igura 3,000 RWF"
    # Bundle detail strings have no consistent schema; capture amount only.
    return {
        "amount": clean_amount(find(r"igura\s+([\d,]+)\s*RWF", body)),
        "sender": None,
        "receiver": "Data Bundle",
        "fee": 0.0,
        "balance_after": None,
        "external_ref": None,
        "occurred_at": None,   # these messages carry no timestamp in the body
    }


EXTRACTORS = {
    "RECEIVE": extract_receive,
    "PAYMENT": extract_payment,
    "AIRTIME": extract_airtime,
    "TRANSFER": extract_transfer,
    "TRANSFER_OUT": extract_transfer_out,
    "DEPOSIT": extract_deposit,
    "MERCHANT_PAYMENT": extract_merchant_payment,
    "WITHDRAWAL": extract_withdrawal,
    "REVERSAL": extract_reversal,
    "FAILED": extract_failed,
    "DATA_BUNDLE": extract_data_bundle,
}

# Types that are real messages but not balance-affecting transactions.
# Kept in output (so they're queryable) but flagged via 'is_transaction'.
NON_BALANCE_TYPES = {"FAILED", "REVERSAL"}


# --- main parse --------------------------------------------------------------

def parse(xml_path):
    """Return (transactions, dead_letter), both lists of dicts."""
    tree = ET.parse(xml_path)
    root = tree.getroot()

    transactions = []
    dead_letter = []
    next_id = 1

    for sms in root.findall("sms"):
        body = sms.get("body", "")
        txn_type = classify(body)

        if txn_type == "IGNORED_OTP":
            dead_letter.append({"raw_body": body, "reason": "ignored_otp_notification"})
            continue

        if txn_type == "UNKNOWN":
            dead_letter.append({"raw_body": body, "reason": "unclassified"})
            continue

        fields = EXTRACTORS[txn_type](body)

        record = {
            "id": next_id,
            "transaction_type": txn_type,
            "amount": fields["amount"],
            "fee": fields["fee"],
            "sender": fields["sender"],
            "receiver": fields["receiver"],
            "balance_after": fields["balance_after"],
            "external_ref": fields["external_ref"],
            "timestamp": fields["occurred_at"] or epoch_ms_to_iso(sms.get("date")),
            "is_transaction": txn_type not in NON_BALANCE_TYPES,
            "raw_body": body,
        }

        if record["amount"] is None:
            dead_letter.append({"raw_body": body, "reason": "amount_not_found",
                                "partial": record})

        transactions.append(record)
        next_id += 1

    return transactions, dead_letter


if __name__ == "__main__":
    import sys
    from collections import Counter

    path = sys.argv[1] if len(sys.argv) > 1 else "data/raw/modified_sms_v2.xml"
    txns, dead = parse(path)

    print(f"Parsed {len(txns)} transactions, {len(dead)} dead-letter entries")
    print("By type:", dict(Counter(t["transaction_type"] for t in txns)))
    print("Dead-letter reasons:", dict(Counter(d["reason"] for d in dead)))

    # write outputs for the API + dashboard to consume
    import os
    os.makedirs("data/processed", exist_ok=True)
    with open("data/processed/transactions.json", "w", encoding="utf-8") as f:
        json.dump(txns, f, indent=2, ensure_ascii=False)
    with open("data/processed/dead_letter.json", "w", encoding="utf-8") as f:
        json.dump(dead, f, indent=2, ensure_ascii=False)
    print("Wrote data/processed/transactions.json and dead_letter.json")