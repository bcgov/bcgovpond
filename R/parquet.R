# For dplyr non-standard evaluation (R CMD check)
utils::globalVariables(c("size_mb", "parquet_path"))

#' Convert large CSV files in the data pond to parquet format
#'
#' @description
#' **Maintenance utility.** Identifies large CSV files in the data pond and
#' converts them to parquet format for improved performance.
#'
#' This function is intended for **periodic optimization and maintenance**.
#' It is not required for normal data access and should not be used in
#' analytical scripts.
#'
#' @details
#' Parquet support is optional and requires the \pkg{arrow} package.
#' The parquet conversion strategy and thresholds may change over time.
#'
#' @param data_pond Directory containing raw CSV files.
#' @param data_parquet Directory where parquet files will be written.
#' @param views_dir Directory containing view YAML files.
#' @param min_size_mb Minimum CSV file size (in MB) required for conversion.
#' @param compression Compression codec passed to Arrow.
#' @param chunk_size Number of rows per chunk when reading CSV files.
#'
#' @return Invisibly returns TRUE.
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
  pkgs <- c("arrow", "fs", "tibble", "dplyr", "janitor", "purrr", "readr")
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) > 0) {
    stop("parquet_large_csvs() requires packages: ", paste(missing, collapse = ", "))
  }

  dir.create(data_parquet, recursive = TRUE, showWarnings = FALSE)
  dir.create(views_dir, recursive = TRUE, showWarnings = FALSE)

  csvs <- fs::dir_ls(data_pond, regexp = "\\.csv$", recurse = FALSE)

  if (length(csvs) == 0) {
    message("No CSV files found.")
    return(invisible(TRUE))
  }

  # NOTE: Semantic dataset names are derived from raw filenames using an
  # internal helper (.semantic_name). Naming conventions may evolve.

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
    return(invisible(TRUE))
  }

  for (i in seq_len(nrow(tb))) {
    csv <- tb$csv_path[i]
    pq  <- tb$parquet_path[i]

    message("Parquetifying (chunked): ", fs::path_file(csv))

    writer <- NULL
    out <- NULL
    clean_names <- NULL
    # Ensure parquet writer/output stream are closed even on error
    on.exit({
      if (!is.null(writer)) writer$Close()
      if (!is.null(out)) out$Close()
    }, add = TRUE)

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

   # Update canonical view for this semantic dataset
    sem <- tb$sem[i]
    raw_fname <- tb$raw_fname[i]
    parquet_fname <- tb$parquet_fname[i]

    old <- read_view(views_dir, sem)
    if (is.null(old)) old <- list()

    write_view(
      view_dir      = views_dir,
      semantic_name = sem,
      raw           = raw_fname,
      parquet       = parquet_fname,
      preferred     = "parquet",
      meta_file     =  if (!is.null(old$meta_file)) old$meta_file else NULL,
      sha256        = if (!is.null(old$sha256))    old$sha256    else NULL
    )
  }
  invisible(TRUE)
}

