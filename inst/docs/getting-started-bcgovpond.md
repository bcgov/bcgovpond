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
  2021_census_industry.xlsx
  RTRA3605542_agenaics.csv
```

IMPORTANT!!!  File names MUST have the following structure 

`specific info with no underscores`_`general_info`

- bcgovpond uses the first underscore _ in a file name to split the file name into specific info vs. general info.
- Specific info is the part of the file name that changes over time e.g. census year, RTRA identifier.
- General info pertains to what type of information the file ALWAYS contains e.g. census_industry.xlsx, agenaics.csv.

Do not attempt to overwrite files already in the pond. (e.g. once 2021_census_industry.xlsx is in the pond, do not try to add another file to the pond with the same name.  Rather, add file 2021(v2)_census_industry.xlsx to the pond, and the read_view("census_industry.xlsx") will use the revised version.

In Windoz you must remember to never touch files in the pond! 

In Linux you can protect your raw data in two steps:

1) chmod 755 data_pond 

2) sudo chattr +i data_pond/*

For the contents of the data_pond, you

    ❌ cannot edit

    ❌ cannot delete

    ❌ cannot rename

    ❌ cannot overwrite

    ❌ even root can’t modify without removing the flag

Which is exactly what you want for canonical raw data.

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
agenaics <- read_view("agenaics.csv")
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
resolve_current("agenaics.csv")
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

## A note on shinyapps.io

- bcgovpond is meant for preprocessing, not for app deployment.
- your app should NOT read data from the data pond.
- all the data your app requires should be created by a preprocessing script and saved as .rds files in a separate folder e.g. app_data.
- your app should only read these .rds files.  

## Summary

bcgovpond enforces a few simple rules:

- Raw data is immutable
- Metadata is explicit
- Analysis code uses logical names
- History is preserved by default

The result is a workflow that scales from solo analysis to team-wide, auditable research without constant manual discipline.
