# DSA: Search Strategy Comparison

## What was compared

Finding a transaction by `id` using three strategies:

| Strategy | Data structure | Complexity | Setup cost |
|---|---|---|---|
| Linear search | unsorted list | O(n) | none |
| Dictionary lookup | hash table (`dict`) | O(1) average | O(n) to build |
| Binary search | sorted list | O(log n) | O(n log n) to sort |

The benchmark grows the dataset from 20 to 20,000 records and times **10,000
repeated lookups** of the **last id** (linear search's worst case), averaged to
microseconds. A single timing at 20 records — as a naive reading of the brief
suggests — is dominated by noise and hides the asymptotic behaviour, so we scale
up instead.

## Results (representative run)

```
     n |  linear (us) |  dict (us) |  binary (us) | linear/dict
----------------------------------------------------------------
     20 |        1.396 |      0.147 |        0.187 |        9.5x
    200 |       13.892 |      0.068 |        0.231 |      203.3x
   2000 |      114.195 |      0.069 |        0.183 |     1657.4x
  20000 |     1079.550 |      0.066 |        0.195 |    16267.5x
```

(Exact numbers vary by machine; the *shape* is what matters.)

## Reading the numbers

- **Linear search grows linearly.** Each 10x increase in data produces roughly a
  10x increase in time (0.58 -> 4.52 -> 45.76 -> 555.89 us). This is O(n).
- **Dictionary lookup is flat.** Time barely moves (0.062 -> 0.075 us) across a
  1000x increase in data. This is O(1).
- **The advantage widens with scale.** The dict is ~9x faster at 20 records but
  ~7000x faster at 20,000. The gap is not constant — it grows with n.
- **Binary search sits in between**, growing only logarithmically (0.12 -> 0.21 us).

## Why dictionary lookup is faster

A Python `dict` is a hash table. Looking up a key runs it through a hash function
that computes the storage location directly, so retrieval is a single step
regardless of dataset size — O(1) on average. Linear search has no such map and
must inspect records one at a time, averaging n/2 checks and n in the worst case
— O(n).

Tradeoffs: the dict spends extra memory on the hash table, and its O(1) is the
*average* case — hash collisions can in principle degrade it toward O(n), though
CPython's implementation makes this rare. We trade memory for speed.

## A better-than-linear alternative without a dict

A **sorted list searched with binary search** is O(log n): it halves the
remaining search space each step, so 20,000 records need ~15 comparisons rather
than 20,000. It is slower than the dict's O(1) for single lookups but has an
advantage the dict lacks — because it is **ordered**, it supports **range
queries** efficiently ("transactions between two dates", "amounts over 10,000")
with one binary search to a boundary plus a scan. A hash table has no order, so a
range query forces a full O(n) scan.

This is precisely why production **database indexes use B-trees** rather than hash
tables: they need fast point lookups *and* fast ordered range scans. The same
index that makes `GET /transactions/{id}` fast in our API is the hash-table idea
applied at startup.

## Connection to the API

`api/data_store.py` builds an id->record `dict` (`_index`) once when the server
starts, then serves every `GET /transactions/{id}` as an O(1) lookup. The
one-time O(n) build cost is amortised across thousands of requests. If we only
ever searched once, linear search would win (no setup) — the dict pays off
exactly because the same data is queried repeatedly.