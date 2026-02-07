#' Write a view definition
#'
#' Creates or updates a YAML view file describing the preferred data
#' representation (raw or parquet) for a semantic dataset name.
#'
#' @param view_dir Directory where view files are written
#' @param semantic_name Stable semantic dataset name
#' @param raw Filename of raw data file
#' @param preferred Preferred representation ("raw" or "parquet")
#' @param parquet Optional parquet filename
#' @param meta_file Optional metadata filename
#' @param sha256 Optional hash of underlying data
#'
#' @export
write_view <- function(
    view_dir,
    semantic_name,
    raw,
    preferred = c("raw", "parquet"),
    parquet = NULL,
    meta_file = NULL,
    sha256 = NULL
) {
  preferred <- match.arg(preferred)
  dir.create(view_dir, recursive = TRUE, showWarnings = FALSE)

  v <- list(
    semantic_name = semantic_name,
    preferred     = preferred,
    raw           = as_filename(raw),
    parquet       = as_filename(parquet),
    meta_file     = as_filename(meta_file),
    sha256        = sha256,
    updated       = now_stamp()
  )

  # Drop NULL fields for cleaner YAML
  v <- v[!vapply(v, is.null, logical(1))]

  yaml::write_yaml(v, file.path(view_dir, paste0(semantic_name, ".yml")))
  invisible(TRUE)
}

#' Resolve the current file path for a dataset
#'
#' Given a semantic dataset name, resolves the preferred concrete
#' file path (raw or parquet) based on the view definition.
#'
#' @param name Semantic dataset name
#' @param view_dir Character scalar. Directory containing view YAML files.
#' @return Normalized file path to the current dataset representation
#'
#' @export
resolve_current <- function(name, view_dir = file.path("data_index", "views")) {
  view_file <- file.path(view_dir, paste0(name, ".yml"))

  if (!file.exists(view_file)) {
    stop("No view found for dataset: ", name, call. = FALSE)
  }

  yml <- yaml::read_yaml(view_file)

  if (!is.list(yml)) {
    stop("Invalid view file for dataset: ", name, call. = FALSE)
  }

  if (is.null(yml$raw) || !nzchar(yml$raw)) {
    stop("View is missing required field 'raw' for: ", name, call. = FALSE)
  }

  preferred <- if (!is.null(yml$preferred)) yml$preferred else "raw"

  if (preferred == "parquet" &&
      !is.null(yml$parquet) &&
      nzchar(yml$parquet)) {
    return(
      normalizePath(
        file.path("data_store", "data_parquet", yml$parquet),
        mustWork = FALSE
      )
    )
  }

  normalizePath(
    file.path("data_store", "data_pond", yml$raw),
    mustWork = FALSE
  )
}


#' Read data backing a view
#'
#' Resolves the current file backing a view and reads it into R using
#' an appropriate reader based on file extension.
#'
#' @param semantic_name Character scalar. Logical name of the view.
#' @param view_dir Directory containing view YAML files.
#' @param skip Number of lines to skip when reading either csv or excel
#'
#' @return A data frame (or tibble).
#' @export
read_view <- function(semantic_name, view_dir = "data_index/views", skip=0) {
  path <- resolve_current(semantic_name, view_dir = view_dir)

  ext <- tolower(tools::file_ext(path))

  switch(
    ext,
    csv     = vroom::vroom(path, skip=skip),
    xlsx    = readxl::read_xlsx(path, skip=skip),
    parquet = arrow::read_parquet(path),
    stop("Unsupported file type: .", ext, call. = FALSE)
  )
}

#' Build or rebuild logical views for a data pond
#'
#' @description
#' **Maintenance utility.** Rebuilds logical view pointer files based on the
#' current contents of the data pond and associated metadata.
#'
#' This function is intended for **infrastructure maintenance** (for example,
#' after ingesting new raw files or modifying metadata). It is **not required
#' for routine analysis workflows**.
#'
#' @details
#' Analysts should typically use [read_view()] or [resolve_current()] rather
#' than calling this function directly. The interface and behavior of
#' `build_views()` may change as the data pond structure evolves.
#'
#' @param views_dir Character scalar. Directory where view YAML files will be
#'   written.
#' @param meta_dir Character scalar. Directory containing metadata YAML files
#'   describing raw data files in the pond.
#' @param pond_dir Character scalar. Directory containing raw data files.
#' @param pq_dir Character scalar. Directory containing parquet files, if
#'   present.
#'
#' @return Invisibly returns TRUE.
#'
#' @export
build_views <- function(
    views_dir = file.path("data_index", "views"),
    meta_dir  = file.path("data_index", "meta"),
    pond_dir  = file.path("data_store", "data_pond"),
    pq_dir    = file.path("data_store", "data_parquet")
) {
  dir.create(views_dir, recursive = TRUE, showWarnings = FALSE)

  meta_files <- list.files(meta_dir, pattern = "\\.yml$", full.names = TRUE)

  if (length(meta_files) == 0) {
    stop("No meta files found in ", meta_dir)
  }

  for (mf in meta_files) {
    meta <- yaml::read_yaml(mf)

    if (!is.list(meta) || is.null(meta$file)) {
      warning("Skipping malformed meta file: ", basename(mf))
      next
    }

    raw_file <- basename(meta$file)
    semantic_name <- if (!is.null(meta$semantic_name)) meta$semantic_name else raw_file

    parquet_file <- paste0(tools::file_path_sans_ext(raw_file), ".parquet")
    has_parquet  <- file.exists(file.path(pq_dir, parquet_file))

    view <- list(
      semantic_name = semantic_name,
      preferred     = if (has_parquet) "parquet" else "raw",
      raw           = raw_file,
      parquet       = if (has_parquet) parquet_file else NULL,
      meta_file     = basename(mf),
      updated       = format(Sys.time(), "%Y-%m-%d %H:%M:%S")
    )

    out_path <- file.path(views_dir, paste0(semantic_name, ".yml"))
    yaml::write_yaml(view, out_path)
  }

  message("Built ", length(meta_files), " view files")
  invisible(TRUE)
}







