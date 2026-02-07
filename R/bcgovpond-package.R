#' bcgovpond: Immutable research data using a data-pond pattern
#'
#' `bcgovpond` is an opinionated R package for managing immutable research data
#' using a data-pond pattern: append-only raw files, explicit metadata, and
#' stable logical pointers ("views") that decouple analysis code from physical
#' file names.
#'
#' Most users will only ever call:
#' \itemize{
#'   \item \code{\link{create_bcgov_pond_project}} (once, per project)
#'   \item \code{\link{ingest_pond}} (when new data arrives)
#'   \item \code{\link{read_view}} (for analysis)
#' }
#'
#' For an overview of the design philosophy and recommended workflow, see the
#' README on GitHub:
#' \url{https://github.com/bcgov/bcgovpond}
#'
#' @keywords internal
"_PACKAGE"
