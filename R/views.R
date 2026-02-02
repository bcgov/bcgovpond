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
