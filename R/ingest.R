#' Ingest a single file into the data pond
#'
#' Creates content metadata and a canonical view for a single data file.
#'
#' @param path Path to the data file to ingest
#' @param meta_dir Directory where metadata YAML files are written
#' @param view_dir Directory where view YAML files are written
#' @param provenance Optional provenance information
#'
#' @export
ingest_single <- function(path, meta_dir, view_dir, provenance = NULL) {
  fname <- basename(path)
  sem   <- semantic_name(fname)
  meta  <- content_meta(path)

  meta_out <- c(
    meta,
    list(
      semantic_name = sem,
      provenance    = provenance
    )
  )

  meta_file <- file.path(meta_dir, paste0(fname, ".yml"))
  yaml::write_yaml(meta_out, meta_file)

  # Write canonical view (portable filenames only)
  write_view(
    view_dir      = view_dir,
    semantic_name = sem,
    raw           = fname,
    preferred     = "raw",
    parquet       = NULL,
    meta_file     = basename(meta_file),
    sha256        = meta$sha256
  )

  invisible(TRUE)
}
