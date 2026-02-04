# Getting Started with bcgovpond
*A practical guide to reproducible data projects*

## Overview

This vignette walks through a complete, realistic workflow using **bcgovpond**:

1. Create a new project on GitHub  
2. Open the project in RStudio  
3. Initialize a bcgovpond data-pond structure  
4. Ingest raw data files  
5. Use stable logical “views” in analysis code  
6. Inspect and debug views using `resolve_current()`

By the end, you will have a project that:
- Preserves immutable raw data
- Separates data storage from analysis
- Can be audited or reconstructed months (or years) later

---

## 1. Create a new GitHub repository

Start by creating an **empty repository** on GitHub.

Recommended settings:
- **Repository name**: project-specific (e.g. `lmo_employment_forecast`)
- **Initialize with README**: yes
- **.gitignore**: none
- **License**: optional (MIT is common)

Copy the repository URL.

---

## 2. Create a new RStudio project from GitHub

In RStudio:

1. File → New Project  
2. Version Control  
3. Git  
4. Paste the repository URL  
5. Choose a local directory  
6. Click **Create Project**

You now have:
- A local Git repository
- An RStudio Project
- A clean starting point

---

## 3. Install and load bcgovpond

Install from GitHub using `pak`:

```r
install.packages("pak")
pak::pak("bcgov/bcgovpond")
```

Load the package:

```r
library(bcgovpond)
```

---

## 4. Initialize a bcgovpond project

From the **root of your RStudio project**, run:

```r
bcgovpond::create_bcgov_pond_project()
```

This creates the standard data-pond layout:

```
data_store/
  add_to_pond/
  data_pond/
  data_parquet/

data_index/
  meta/
  views/
```

Key principles:
- Raw data is never tracked in Git
- Metadata and views are tracked in Git
- Analysis code never points directly to raw files

Commit the structure:

```bash
git add .
git commit -m "Initialize bcgovpond project structure"
```

---

## 5. Add raw data

Drop new raw files into:

```
data_store/add_to_pond/
```

For example:

```
data_store/add_to_pond/
  2025_lfs_employment_bc.csv
  2024_industry_mapping.xlsx
```

IMPORTANT!!!  File names are assume to follow the structure 

`specific file information no underscores`_`logical_name`.`extension`

e.g.

2021_census_industry.xlsx or

RTRA3605542_agenaics.csv

In the first case the specific file info is the census year, and the logical name is census_industry.xlsx.
In the second case the specific file info is the RTRA identifier, and the logical name is agenaics.csv

Do not overwrite or rename older files.  
bcgovpond assumes new data arrives as new files.

---

## 6. Ingest raw data into the pond

Run:

```r
ingest_pond()
```

For each file, bcgovpond will:

1. Move it into `data_pond/` (append-only)
2. Generate a metadata YAML file
3. Create or update a logical view
4. Preserve older versions automatically

Commit the index:

```bash
git add data_index
git commit -m "Ingest initial raw data"
```

---

## 7. Use views in analysis code

Always load data using **views**, never file paths.

```r
employment <- read_view("lfs_employment_bc")
```

Why this matters:
- The view name stays stable
- The underlying file can change
- Old results remain reproducible

Your analysis code never needs to change when data updates.

---

## 8. Inspect and debug views with `resolve_current()`

`resolve_current()` shows you **what file a view currently points to**.

This is useful for:
- Verifying which version of a dataset is active
- Debugging unexpected results
- Auditing which raw file produced an output

Example:

```r
resolve_current("lfs_employment_bc")
```

This function is intentionally explicit and verbose.  
It is designed for **humans**, not pipelines.

---

## 9. Updating data (normal workflow)

When new data arrives:

1. Drop it into `add_to_pond/`
2. Run `ingest_pond()`
3. Commit `data_index/`

Views are updated automatically, but history is preserved.

---

## 10. Reproducing an old result

To recreate an earlier output:

1. Check out the corresponding Git commit
2. Run the analysis scripts
3. Views resolve to the correct historical data automatically

No manual file juggling required.

---

## Summary

bcgovpond enforces a few simple rules:

- Raw data is immutable
- Metadata is explicit
- Analysis code uses logical names
- History is preserved by default

The result is a workflow that scales from solo analysis to team-wide, auditable research without constant manual discipline.
