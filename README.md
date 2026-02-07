# bcgovpond <img src="man/figures/bcgovpond.png" align="right" height="139" />

`bcgovpond` is an opinionated R package for managing **immutable research data** using a
*data-pond* pattern: append-only raw files, explicit metadata, and stable logical
pointers (“views”) that decouple analysis code from physical file names.

This package was built for **real research workflows**, not for abstract elegance.
It assumes that people:

- dump CSV/XLSX files into folders,
- forget what version they used six months ago,
- want reproducibility without constant babysitting,
- and mostly work in R.

If that sounds familiar, this package is for you.

---

## What problem does this solve?

Most research projects fail at one (or more) of the following:

- Raw data silently changes  
- Files are overwritten without record  
- Analysis scripts hard-code file paths  
- “Final” datasets cannot be reconstructed  
- Metadata lives in people’s heads  

`bcgovpond` addresses these problems by enforcing a few simple rules:

1. **Raw data is immutable**
2. **Every file has metadata**
3. **Analysis code never points directly to raw files**
4. **Logical names (“views”) can be updated, but history is preserved**

Most users will only ever call **`create_bcgov_pond_project()`** (once per project) **`ingest_pond()`** (when new data arrives) and **`read_view()`** (for access to the data)

---

## Installation

Install directly from GitHub using `pak`:

```r
install.packages("pak")
pak::pak("bcgov/bcgovpond")
```

On Windows, you may be prompted to install Rtools. This is optional for this package,
but recommended if you plan to use `pak` more broadly.

---

## Core concepts

### 1. Data pond (append-only storage)

The *pond* is where canonical raw data lives.

- Files are moved into the pond
- Files are never edited in place
- New versions are added, not overwritten
- Files may optionally be made immutable at the filesystem level

Think of this as *cold storage for raw inputs*.

---

### 2. Metadata (`data_index/meta/`)

Every file in the pond has a corresponding YAML metadata file describing:

- source
- contents
- structure
- relevant identifiers (as available)

Metadata files are **tracked in git**.  
Raw data files usually are not.

---

### 3. Views (`data_index/views/`)

A *view* is a small YAML pointer that maps a **stable logical name** to a
**specific physical file**.

Analysis scripts load data via views, not raw file paths.

When a new version of a dataset arrives:

- the old file stays in the pond
- the view is updated to point to the new file
- old analyses can still be reproduced

---

### 4. Incoming data (`data_store/add_to_pond/`)

New files land here first.

`bcgovpond` ingestion functions:

- inspect the file
- generate metadata
- move it into the pond
- update or create the appropriate view

This keeps ingestion boring and repeatable.

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

## Project setup (one-time)

For a new analysis project, initialize the standard data-pond structure once:

```r
create_bcgov_pond_project()
```

This creates the required directories:

- `data_store/` (raw and derived data, not tracked in git)
- `data_index/` (metadata and views, tracked in git)

After this initial setup, most users will only need
`ingest_pond()` and `read_view()`.

---

## Typical workflow (most users)

1. Drop new CSV or XLSX files into `data_store/add_to_pond/`
2. Run:
   ```r
   ingest_pond()
   ```
3. Load data in analysis code using views:
   ```r
   tb <- read_view("census_industry")
   ```

That’s it.  
No file paths. No version handling in analysis code.

---

## File naming (important)

Raw file names must follow this pattern:

```
specific-info_general-info.ext
```

- The **first underscore** is meaningful
- `specific-info` changes over time (year, extract ID, version)
- `general-info` identifies the dataset concept

Examples:

- `2021_census_industry.xlsx`
- `RTRA3605542_agenaics.csv`

Do not overwrite files already in the pond.  
New versions must always have new filenames.

---

## Inspecting and debugging views (advanced)

If you need to see which physical file a view currently points to:

```r
resolve_current("census_industry")
```

This is useful for:

- debugging unexpected results
- auditing data provenance
- confirming which raw file is active

Most analysis code should **not** need this.

---

## A note on Parquet

Parquet files are treated as **derived artifacts**, not primary data.

- They exist for performance and convenience
- They may be deleted and regenerated at any time
- They are not authoritative
- Views should never treat Parquet as the source of truth

> **Parquet is a cache, not a source of truth.**

---

## Immutability (recommended)

Raw data in `data_store/data_pond/` should be treated as read-only.

On Linux, this can be enforced at the filesystem level.
On Windows, this relies on user discipline.

Either way: **never edit or overwrite files in the pond**.

---

## What this package is *not*

`bcgovpond` is intentionally **not**:

- a general-purpose data lake framework
- a CRAN-polished, pure-function package
- a tidyverse-style abstraction layer
- a database replacement
- a Parquet-first system

It touches the filesystem and has side effects.  
That is the point.

---

## Design philosophy

- **Safety over elegance**
- **Reproducibility over convenience**
- **Filesystem semantics are real APIs**
- **Boring > clever**
- **Humans make mistakes; systems should assume that**

If these assumptions bother you, this package will bother you.

---

## Reproducibility

Reproducibility relies on **Git + `data_index/` + `renv`**, not copying data folders.

### One-time setup

Initialize `renv` once:

```r
renv::init()
```

Track in git:

- `renv.lock`
- `renv/activate.R`
- all analysis code
- `data_index/`

### Reproducing results

1. Check out the desired git commit
2. Ensure the corresponding raw files exist in `data_store/data_pond/`
3. Restore packages:
   ```r
   renv::restore()
   ```
4. Run the analysis scripts

---

## Status

This package is:

- stable enough for daily use
- intentionally opinionated
- evolving slowly and conservatively

APIs may change, but the **conceptual model will not**.

---

## Final warning

If you are looking for:

- maximum flexibility,
- silent overwrites,
- or “just load the latest file” shortcuts,

this package will feel annoying.

That annoyance is doing useful work.
