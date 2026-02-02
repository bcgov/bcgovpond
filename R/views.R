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
    sha256        = sha256 %||% NULL,
    updated       = now_stamp()
  )

  # Drop NULL fields for cleaner YAML
  v <- v[!vapply(v, is.null, logical(1))]

  yaml::write_yaml(v, file.path(view_dir, paste0(semantic_name, ".yml")))
  invisible(TRUE)
}

#' Read a view definition
#'
#' Reads a YAML view file for a given semantic dataset name.
#' Returns NULL if the view does not exist or cannot be read.
#'
#' @param view_dir Directory containing view files
#' @param semantic_name Stable semantic dataset name
#'
#' @return A named list representing the view definition, or NULL
#'
#' @export
read_view <- function(view_dir, semantic_name) {
  p <- file.path(view_dir, paste0(semantic_name, ".yml"))
  if (!file.exists(p)) return(NULL)
  yml <- yaml::read_yaml(p)
  if (!is.list(yml)) return(NULL)
  yml
}


#' Resolve the current file path for a dataset
#'
#' Given a semantic dataset name, resolves the preferred concrete
#' file path (raw or parquet) based on the view definition.
#'
#' @param name Semantic dataset name
#'
#' @return Normalized file path to the current dataset representation
#'
#' @export
resolve_current <- function(name) {
  view_dir <- file.path("data_index", "views")
  yml <- yaml::read_yaml(file.path(view_dir, paste0(name, ".yml")))

  stopifnot(is.list(yml))
  if (is.null(yml$raw) || !nzchar(yml$raw)) {
    stop("View is missing required field 'raw' for: ", name)
  }

  preferred <- yml$preferred %||% "raw"

  if (preferred == "parquet" && !is.null(yml$parquet) && nzchar(yml$parquet)) {
    return(normalizePath(file.path("data_store", "data_parquet", yml$parquet), mustWork = FALSE))
  }

  normalizePath(file.path("data_store", "data_pond", yml$raw), mustWork = FALSE)
}

#' Rebuild view definitions from metadata
#'
#' Scans metadata files and reconstructs view definitions,
#' preferring Parquet representations when available.
#'
#' @param views_dir Directory where view files are written
#' @param meta_dir Directory containing metadata files
#' @param pond_dir Directory containing raw data files
#' @param pq_dir Directory containing parquet data files
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
    if (!is.list(meta) || is.null(meta$file)) next

    raw_file <- basename(meta$file)
    semantic_name <- meta$semantic_name %||% raw_file

    parquet_file <- sub("\\.csv$", ".parquet", raw_file, ignore.case = TRUE)
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







