#' Extract semantic portion of a filename
#'
#' Removes everything up to and including the first underscore (`_`).
#' This is used to strip versioning or source prefixes from filenames,
#' leaving the stable semantic name.
semantic_name <- function(fname) {
  sub("^[^_]*_", "", fname)
}

# Internal helper:
# Returns RHS only when LHS is literally NULL
# (0, FALSE, "", NA are all preserved)
`%||%` <- function(x, y) if (is.null(x)) y else x

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




