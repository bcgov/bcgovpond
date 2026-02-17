#' Fetch a StatCan table ZIP into the pond inbox
#'
#' Downloads a Statistics Canada table ZIP and places it into
#' data_store/add_to_pond for ingestion by ingest_pond().
#'
#' Each call records an observation event (timestamped filename).
#' Identity and deduplication are handled during ingestion.
#'
#' @param url A StatCan CSV/ZIP download URL
#'
#' @return Invisible path to delivered file
#' @export
fetch_statcan_zip <- function(url) {

  add_dir <- file.path("data_store", "add_to_pond")
  dir.create(add_dir, recursive = TRUE, showWarnings = FALSE)

  # extract table id safely (works for eng/fra and any digit length)
  table_id <- sub(".*?/([0-9]+)-(eng|fra)\\.zip.*", "\\1", url)

  if (identical(table_id, url))
    stop("Could not extract StatCan table id from URL")

  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")

  dest <- file.path(
    add_dir,
    paste0("statcan_", table_id, "_", timestamp, ".zip")
  )

  # --- atomic download ---
  tmp <- tempfile(fileext = ".zip")
  on.exit(unlink(tmp), add = TRUE)

  utils::download.file(
    url,
    destfile = tmp,
    mode = "wb",
    method = "curl",
    quiet = FALSE
  )

  # --- basic validation ---
  size <- file.size(tmp)

  if (is.na(size) || size < 5000)
    stop("Download failed or returned HTML instead of ZIP")

  # verify ZIP magic number (PK header)
  con <- file(tmp, "rb")
  sig <- readBin(con, "raw", 4)
  close(con)

  if (!identical(sig, charToRaw("PK\003\004")))
    stop("Downloaded file is not a valid ZIP archive")

  # move into pond inbox
  ok <- file.rename(tmp, dest)
  if (!ok) file.copy(tmp, dest)

  message("Delivered to pond inbox: ", basename(dest))

  invisible(dest)
}
