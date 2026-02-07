#' Derive a semantic dataset name from a raw filename
#'
#' @description
#' **Internal helper.** Derives a semantic dataset name from a raw data
#' filename according to package-specific naming conventions.
#'
#' This function is used internally when constructing views and other
#' metadata. Naming conventions may evolve over time and should not be
#' relied upon directly by user code.
#'
#' @param fname Character scalar. Name of a raw data file.
#'
#' @return Character scalar giving the derived semantic dataset name.
#'
#' @keywords internal
.semantic_name <- function(fname) {
  sub("^[^_]*_", "", fname)
}

# Prefix used when unzipping: take everything before first underscore
zip_prepend <- function(fname) {
  sub("_.*$", "", fname)
}

# Normalize any input to a bare filename.
# Used to ensure views never contain absolute or relative paths.
# NULL and empty values are preserved as NULL.
as_filename <- function(x) {
  if (is.null(x)) return(NULL)
  x <- as.character(x)
  if (!nzchar(x)) return(NULL)
  basename(x)
}

now_stamp <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%S")

# Read the first line of a CSV file to infer column names.
# Reads only a small prefix of the file; returns NULL if no header is found.
get_csv_header <- function(path) {
  con <- file(path, open = "rb")
  on.exit(close(con), add = TRUE)

  raw <- readBin(con, what = "raw", n = 4096)
  if (length(raw) == 0) return(NULL)

  txt <- rawToChar(raw)
  txt <- sub("^\ufeff", "", txt)   # strip UTF-8 BOM
  line <- strsplit(txt, "\n", fixed = TRUE)[[1]][1]

  hdr <- strsplit(line, ",", fixed = TRUE)[[1]]
  if (length(hdr) < 2) return(NULL)

  make.unique(trimws(hdr), sep = "_")
}




