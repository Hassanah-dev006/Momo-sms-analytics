"""
search_comparison.py
Compare two strategies for finding a transaction by id:

  1. Linear search  - scan a list until the id matches.        O(n)
  2. Dictionary lookup - hash-table lookup by key.             O(1) average

We also include binary search on a sorted list (O(log n)) as the
"can we do better than linear without a dict?" answer to the reflection.

The benchmark grows the dataset (20 -> 20000 records) and times MANY
repeated lookups of the WORST-CASE key (the last id), averaged, so the
asymptotic difference is visible instead of buried in timing noise.
"""

import json
import os
import timeit
from bisect import bisect_left


# ---- the three search strategies -------------------------------------------

def linear_search(transactions, target_id):
    """O(n): scan every record until the id matches."""
    for txn in transactions:
        if txn["id"] == target_id:
            return txn
    return None


def dict_lookup(index, target_id):
    """O(1) average: hash-table lookup."""
    return index.get(target_id)


def binary_search(sorted_ids, sorted_txns, target_id):
    """O(log n): requires the list to be sorted by id first."""
    pos = bisect_left(sorted_ids, target_id)
    if pos < len(sorted_ids) and sorted_ids[pos] == target_id:
        return sorted_txns[pos]
    return None


# ---- data loading + synthetic scaling --------------------------------------

def load_base():
    path = os.path.join("data", "processed", "transactions.json")
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def make_dataset(base, n):
    """Return a list of n records with ids 1..n (repeating base data)."""
    out = []
    for i in range(n):
        rec = dict(base[i % len(base)])
        rec["id"] = i + 1
        out.append(rec)
    return out


# ---- benchmark --------------------------------------------------------------

def benchmark(sizes, repeats=10000):
    base = load_base()
    print(f"Base dataset: {len(base)} real transactions\n")
    header = f"{'n':>7} | {'linear (us)':>12} | {'dict (us)':>10} | {'binary (us)':>12} | {'linear/dict':>11}"
    print(header)
    print("-" * len(header))

    results = []
    for n in sizes:
        data = make_dataset(base, n)
        index = {r["id"]: r for r in data}
        sorted_txns = sorted(data, key=lambda r: r["id"])
        sorted_ids = [r["id"] for r in sorted_txns]
        target = n  # WORST CASE for linear: the last id

        # average microseconds per lookup
        lin = timeit.timeit(lambda: linear_search(data, target), number=repeats) / repeats * 1e6
        dct = timeit.timeit(lambda: dict_lookup(index, target), number=repeats) / repeats * 1e6
        bnry = timeit.timeit(lambda: binary_search(sorted_ids, sorted_txns, target), number=repeats) / repeats * 1e6

        ratio = lin / dct if dct else float("inf")
        print(f"{n:>7} | {lin:>12.3f} | {dct:>10.3f} | {bnry:>12.3f} | {ratio:>10.1f}x")
        results.append({"n": n, "linear_us": lin, "dict_us": dct, "binary_us": bnry, "ratio": ratio})

    return results


if __name__ == "__main__":
    benchmark([20, 200, 2000, 20000])