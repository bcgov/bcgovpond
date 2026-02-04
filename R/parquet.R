#' Convert large CSV files in the pond to Parquet
#'
#' Scans the data pond for large CSV files, converts them to Parquet
#' using chunked reads, and updates views to prefer the Parquet
#' representation when available.
#'
#' @param data_pond Directory containing raw CSV files
#' @param data_parquet Directory to write Parquet files
#' @param views_dir Directory containing view definitions
#' @param min_size_mb Minimum CSV size (MB) to trigger conversion
#' @param compression Parquet compression codec
#' @param chunk_size Number of rows per read chunk
#'
#' @export
parquet_large_csvs <- function(
    data_pond   = file.path("data_store", "data_pond"),
    data_parquet= file.path("data_store", "data_parquet"),
    views_dir   = file.path("data_index", "views"),
    min_size_mb = 200,
    compression = "zstd",
    chunk_size  = 100000 # if RAM constrained, reduce
) {
  # Soft-check dependencies
  pkgs <- c("arrow", "fs", "tibble", "dplyr", "janitor", "purrr")
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    stop("parquet_large_csvs() requires packages: ", paste(missing, collapse = ", "))
  }

  dir.create(data_parquet, recursive = TRUE, showWarnings = FALSE)
  dir.create(views_dir, recursive = TRUE, showWarnings = FALSE)

  csvs <- fs::dir_ls(data_pond, regexp = "\\.csv$", recurse = FALSE)

  if (length(csvs) == 0) {
    message("No CSV files found.")
    return(invisible(NULL))
  }

  tb <- tibble::tibble(
    csv_path     = csvs,
    size_mb      = fs::file_info(csvs)$size / 1024^2,
    raw_fname    = fs::path_file(csvs),
    sem          = vapply(fs::path_file(csvs), .semantic_name, character(1)),
    parquet_fname= paste0(fs::path_ext_remove(fs::path_file(csvs)), ".parquet"),
    parquet_path = file.path(data_parquet, paste0(fs::path_ext_remove(fs::path_file(csvs)), ".parquet"))
  ) |>
    dplyr::filter(
      size_mb >= min_size_mb,
      !fs::file_exists(parquet_path)
    )

  if (nrow(tb) == 0) {
    message("No large, new CSVs to parquet.")
    return(invisible(NULL))
  }

  for (i in seq_len(nrow(tb))) {
    csv <- tb$csv_path[i]
    pq  <- tb$parquet_path[i]

    message("Parquetifying (chunked): ", fs::path_file(csv))

    writer <- NULL
    out <- NULL
    clean_names <- NULL

    callback <- readr::SideEffectChunkCallback$new(function(chunk, pos) {

      if (is.null(clean_names)) {
        clean_names <<- janitor::make_clean_names(names(chunk))
        names(chunk) <- clean_names

        fields <- purrr::imap(
          chunk,
          ~ arrow::field(.y, arrow::infer_type(.x))
        )
        schema <- arrow::schema(fields)

        props <- arrow::ParquetWriterProperties$create(
          column_names = clean_names,
          compression = compression
        )

        out <<- arrow::FileOutputStream$create(pq)

        writer <<- arrow::ParquetFileWriter$create(
          schema,
          out,
          properties = props
        )
      } else {
        names(chunk) <- clean_names
      }

      writer$WriteTable(
        arrow::Table$create(chunk),
        chunk_size = nrow(chunk)
      )
    })

    suppressWarnings(
      readr::read_csv_chunked(
        csv,
        callback = callback,
        chunk_size = chunk_size,
        show_col_types = FALSE,
        progress = FALSE
      )
    )

    # Close writer/stream
    if (!is.null(writer)) writer$Close()
    if (!is.null(out)) out$Close()

    # Update canonical view for this semantic dataset
    sem <- tb$sem[i]
    raw_fname <- tb$raw_fname[i]
    parquet_fname <- tb$parquet_fname[i]

    old <- read_view(views_dir, sem) %||% list()

    write_view(
      view_dir      = views_dir,
      semantic_name = sem,
      raw           = raw_fname,
      parquet       = parquet_fname,
      preferred     = "parquet",
      meta_file     = old$meta_file %||% NULL,
      sha256        = old$sha256 %||% NULL
    )
  }

  invisible(tb)
}

