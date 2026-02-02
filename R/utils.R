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







