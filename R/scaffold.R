#' Create a BC Gov data pond project
#'
#' Sets up an R project with the standard BC Gov data pond
#' directory structure, licensing, and ingestion scripts.
#'
#' @param path Path where the project should be created
#' @param licence Licence type ("apache2" or "cc-by")
#' @param coc_email Optional Code of Conduct contact email
#' @param rstudio Whether to create an RStudio project
#' @param open Whether to open the project after creation
#' @param overwrite Whether to overwrite existing pond structures
#'
#' @export
create_bcgov_pond_project <- function(
    path = ".",
    licence = "apache2",
    coc_email = NULL,
    rstudio = rstudioapi::isAvailable(),
    open = TRUE,
    overwrite = FALSE
) {

  # ------------------------------------------------------------
  # Normalize path
  # ------------------------------------------------------------
  path_norm <- normalizePath(path, mustWork = FALSE)

  message("Setting up BC Gov data-pond project: ", basename(path_norm))

  # ------------------------------------------------------------
  # Guardrails: allow GitHub-first repos, block existing ponds
  # ------------------------------------------------------------
  protected_paths <- c(
    "data_store",
    "data_index",
    "01_ingest_data.R"
  )

  existing_targets <- file.path(path_norm, protected_paths)
  existing_targets <- existing_targets[file.exists(existing_targets)]

  if (length(existing_targets) > 0 && !overwrite) {
    stop(
      "Refusing to create BC Gov pond project here.\n\n",
      "The following paths already exist:\n",
      paste("  -", existing_targets, collapse = "\n"),
      "\n\nSet overwrite = TRUE to replace them.",
      call. = FALSE
    )
  }

  # ------------------------------------------------------------
  # Create project (version-safe)
  # ------------------------------------------------------------
  create_args <- list(
    path    = path,
    rstudio = rstudio,
    open    = FALSE
  )

  # only pass force=TRUE if supported by this usethis version
  if ("force" %in% names(formals(usethis::create_project))) {
    create_args$force <- TRUE
  }

  do.call(usethis::create_project, create_args)

  # Activate the newly created project for downstream usethis/bcgovr calls
  usethis::proj_set(path_norm, force = TRUE)

  # ------------------------------------------------------------
  # BC Gov required files
  # ------------------------------------------------------------
  bcgovr::use_bcgov_req(
    licence    = licence,
    rmarkdown = FALSE,
    coc_email = coc_email
  )

  # ------------------------------------------------------------
  # Directory structure
  # ------------------------------------------------------------
  dirs <- c(
    "data_store/add_to_pond",
    "data_store/data_pond",
    "data_store/data_parquet",
    "data_index/meta",
    "data_index/views",
    "R"
  )

  message("Creating data pond / index structure")

  lapply(
    file.path(path_norm, dirs),
    dir.create,
    recursive = TRUE,
    showWarnings = FALSE
  )


  # ------------------------------------------------------------
  # 01_ingest_data.R
  # ------------------------------------------------------------
  ingest_script <- file.path(path_norm, "01_ingest_data.R")

  if (!file.exists(ingest_script) || overwrite) {
    writeLines(
      c(
        'library(bcgovpond)',
        "",
        "# =========================================================",
        "# Data ingestion workflow",
        "# =========================================================",
        "",
        "# 1. Ingest raw files dropped into data_store/add_to_pond",
        "ingest_pond()",
        "",
        "# 2. Convert large CSVs to Parquet (optional)",
        "parquet_large_csvs(",
        "  min_size_mb  = 250,",
        "  chunk_size   = 1000000  # reduce if running out of RAM",
        ")",
        "",
        "# 3. Resolve current pointers",
        "resolve_current(",
        " test.csv",
        ")",
        ""
      ),
      ingest_script
    )
  }

  message("Created 01_ingest_data.R")

  usethis::use_git_ignore(c(
    "data_store/",
    "*.parquet",
    "*.parquet.ok"
  ))

  message("BC Gov data-pond project ready")

  if (open) {
    usethis::proj_activate(path_norm)
  }

  invisible(TRUE)
}
