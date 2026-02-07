#' Ingest a single file into the data pond
#'
#' Creates content metadata and a canonical view for a single data file.
#'
#' @param path Path to the data file to ingest
#' @param meta_dir Directory where metadata YAML files are written
#' @param view_dir Directory where view YAML files are written
#' @param provenance Optional provenance information
#'
ingest_single <- function(path, meta_dir, view_dir, provenance = NULL) {
  fname <- basename(path)
  sem   <- .semantic_name(fname)
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

#' Ingest a ZIP archive into the data pond
#'
#' Extracts files from a ZIP archive, renames them using a derived
#' prefix, copies them into the pond, and ingests each file with
#' provenance recorded.
#'
#' @param zip_path Path to ZIP archive
#' @param pond_dir Directory where files are stored in the pond
#' @param meta_dir Directory where metadata YAML files are written
#' @param view_dir Directory where view YAML files are written
#'
ingest_zip <- function(zip_path, pond_dir, meta_dir, view_dir) {
  zip_name <- basename(zip_path)
  prepend  <- zip_prepend(zip_name)

  tmp <- tempfile("unzipped_")
  dir.create(tmp)

  utils::unzip(zip_path, exdir = tmp)

  files <- list.files(
    tmp,
    full.names = TRUE,
    recursive = TRUE
  )

  for (f in files) {
    if (dir.exists(f)) next

    base     <- basename(f)
    new_name <- paste0(prepend, "_", base)
    out_path <- file.path(pond_dir, new_name)

    file.copy(f, out_path, overwrite = TRUE)

    ingest_single(
      out_path,
      meta_dir,
      view_dir,
      provenance = list(
        source_zip    = zip_name,
        original_file = base
      )
    )
  }

  invisible(TRUE)
}

#' Ingest all files from the add-to-pond directory
#'
#' Scans the add-to-pond directory, ingests supported files into the
#' data pond, and updates metadata and views.
#'
#' @export
ingest_pond <- function() {
  add_dir  <- file.path("data_store", "add_to_pond")
  pond_dir <- file.path("data_store", "data_pond")
  meta_dir <- file.path("data_index", "meta")
  view_dir <- file.path("data_index", "views")

  dir.create(add_dir,  showWarnings = FALSE, recursive = TRUE)
  dir.create(pond_dir, showWarnings = FALSE, recursive = TRUE)
  dir.create(meta_dir, showWarnings = FALSE, recursive = TRUE)
  dir.create(view_dir, showWarnings = FALSE, recursive = TRUE)

  files <- list.files(add_dir, full.names = TRUE)

  for (f in files) {
    message("Processing: ", basename(f))
    ext <- tolower(tools::file_ext(f))

    if (ext == "zip") {

      ingest_zip(f, pond_dir, meta_dir, view_dir)
      file.remove(f)

    } else if (ext %in% c("csv", "xls", "xlsx")) {

      new_path <- file.path(pond_dir, basename(f))
      ok <- file.rename(f, new_path)
      if (!ok) {
        # fallback if rename across filesystems
        file.copy(f, new_path, overwrite = TRUE)
        file.remove(f)
      }

      ingest_single(new_path, meta_dir, view_dir)

    } else {
      warning("Skipping unsupported file type: ", basename(f))
    }
  }

  invisible(TRUE)
}




