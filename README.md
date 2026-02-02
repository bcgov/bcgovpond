# bcgovpond

`bcgovpond` is an opinionated R package for managing **immutable research data** using a
*data-pond* pattern: append-only raw files, explicit metadata, and stable logical
pointers (“views”) that decouple analysis code from physical file names.

This package was built for **real research workflows**, not for abstract elegance.
It assumes that people:

* dump CSV/XLSX files into folders,
* forget what version they used six months ago,
* want reproducibility without constant babysitting,
* and mostly work in R on Linux.

If that sounds familiar, this package is for you.

---

## What problem does this solve?

Most research projects fail at one (or more) of the following:

* Raw data silently changes
* Files are overwritten without record
* Analysis scripts hard-code file paths
* “Final” datasets cannot be reconstructed
* Metadata lives in people’s heads

`bcgovpond` addresses these problems by enforcing a few simple rules:

1. **Raw data is immutable**
2. **Every file has metadata**
3. **Analysis code never points directly to raw files**
4. **Logical names (“views”) can be updated, but history is preserved**

---

## Core concepts

### 1. Data pond (append-only storage)

The *pond* is where canonical raw data lives.

* Files are moved into the pond
* Files are never edited in place
* New versions are added, not overwritten
* (Optionally) files can be made immutable at the filesystem level

Think of this as *“cold storage for raw inputs”*.

---

### 2. Metadata (`data_index/meta/`)

Every file in the pond has a corresponding YAML metadata file describing:

* source
* contents
* structure
* relevant identifiers (as available)

Metadata files are **tracked in git**.
Data files usually are not.

---

### 3. Views (`data_index/views/`)

A *view* is a small YAML pointer that maps a **stable logical name** to a **specific physical file**.

Example (simplified):

```yaml
logical_name: census_population_bc
path: data_store/data_pond/2021_census_population_bc.csv
hash: 3f2a9c...
```

Analysis scripts load data via views, not raw file paths.

When a new version of a dataset arrives:

* the old file stays in the pond
* the view is updated to point to the new file
* old analyses can still be reproduced

---

### 4. Incoming data (`data_store/add_to_pond/`)

New files land here first.

`bcgovpond` functions:

* inspect the file
* generate metadata
* move it into the pond
* update or create the appropriate view

This keeps the ingestion process boring and repeatable.

---

## Directory structure

```
data_store/
├── add_to_pond/          # incoming raw files
├── data_pond/            # immutable canonical raw data (not tracked in git)
└── data_parquet/         # derived parquet / Arrow outputs (not tracked)

data_index/
├── meta/                 # YAML metadata (tracked in git)
└── views/                # logical pointers (tracked in git)
```

You **commit `data_index/`**, not the raw or derived data in `data_store/`.

---

## A note on Parquet

Parquet files are treated as **derived artifacts**, not primary data.

* They exist for performance and convenience
* They may be deleted and regenerated at any time
* They are *not* authoritative
* Views should **never** point to Parquet files

> **Parquet is a cache, not a source of truth.**

The source of truth is always the immutable files in `data_store/data_pond/`,
as described by `data_index/meta/` and referenced via `data_index/views/`.

---

## What this package is *not*

`bcgovpond` is intentionally **not**:

* A general-purpose data lake framework
* A CRAN-polished, pure-function package
* A tidyverse-style abstraction layer
* A database replacement
* A Parquet-first system

It **does** touch your filesystem.
It **does** have side effects.

That is the point.

---

## Design philosophy

* **Safety over elegance**
* **Reproducibility over convenience**
* **Filesystem semantics are real APIs**
* **Boring > clever**
* **Humans make mistakes; systems should assume that**

If these assumptions bother you, this package will bother you.

---

## Typical workflow

1. Drop a new CSV or XLSX file into `data_store/add_to_pond/`
2. Run the ingestion function
3. A metadata file is created
4. The file is moved into `data_store/data_pond/`
5. A view is created or updated
6. Analysis scripts continue to work unchanged

---

## Supported file types

Currently designed for:

* CSV
* XLSX

Parquet is supported *optionally* and intentionally kept **outside the core ingestion path**
to avoid memory issues and API instability.

---

## Platform assumptions

* Linux (strongly preferred)
* R ≥ 4.x
* Users comfortable with:

  * git
  * directories
  * not editing raw data files by hand

Windows network drives and shared folders may work, but immutability guarantees are weaker.

---

## Status

This package is:

* stable enough for daily use
* intentionally opinionated
* evolving slowly and conservatively

APIs may change, but the **conceptual model will not**.

---

## Why “pond” and not “lake”?

A pond is:

* smaller
* shallower
* easier to reason about
* appropriate for research teams

You don’t need a data lake to keep your data from lying to you.

---

## Governance

`bcgovpond` works best when:

* one person “owns” ingestion
* everyone else consumes via views
* raw data is treated as read-only
* mistakes are fixed by adding data, not editing history

---

## Final warning

If you are looking for:

* maximum flexibility,
* silent overwrites,
* or “just load the latest file” shortcuts,

this package will feel annoying.

That annoyance is doing useful work.
