# Construct content-derived metadata for a data file.
# Reads minimal file content where possible; row counts are deferred.
content_meta <- function(path) {
  ext  <- tolower(tools::file_ext(path))
  size <- file.info(path)$size

  if (ext == "csv") {
    cols <- get_csv_header(path)
    if (is.null(cols)) cols <- character()
    types <- rep("unknown", length(cols))

  } else if (ext %in% c("xls", "xlsx")) {
    # NOTE: this *does* read up to 1000 rows; fine for typical xlsx sizes
    dat   <- readxl::read_excel(path, n_max = 1000)
    cols  <- names(dat)
    types <- vapply(dat, \(x) class(x)[1], character(1))

  } else {
    cols  <- character()
    types <- character()
  }

  list(
    file        = basename(path),
    sha256      = digest::digest(path, algo = "sha256", file = TRUE),
    size_bytes  = size,
    n_rows      = NA_integer_,   # intentionally deferred
    n_cols      = length(cols),
    col_names   = cols,
    col_types   = types,
    created     = as.character(Sys.time())
  )
}
