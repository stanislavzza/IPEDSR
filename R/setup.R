#' Set up the IPEDS DuckDB database
#' @description Downloads the IPEDS database file to a standard location and sets
#' an environment variable in .Renviron so it can be accessed from any project.
#' @param url Where to get the duckdb IPEDS database
#' @return a zero upon success
setup_ipeds <- function(url = "https://yourserver.org/ipeds.duckdb") {
  dir <- file.path(Sys.getenv("HOME"), ".ipeds_data")
  db_path <- file.path(dir, "ipeds.duckdb")

  if (!dir.exists(dir)) dir.create(dir, recursive = TRUE)

  if (!file.exists(db_path)) {
    download.file(url, destfile = db_path, mode = "wb")
    message("IPEDS database downloaded.")
  } else {
    message("IPEDS database already exists.")
  }

  renv_file <- file.path(Sys.getenv("HOME"), ".Renviron")
  lines <- readLines(renv_file, warn = FALSE)
  if (!any(grepl("IPEDS_DB_PATH", lines))) {
    cat(paste0("\nIPEDS_DB_PATH=", db_path, "\n"), file = renv_file, append = TRUE)
    message("Environment variable IPEDS_DB_PATH added to .Renviron.")
  } else {
    message("Environment variable IPEDS_DB_PATH already set.")
  }

  invisible(db_path)
  return(0)
}

#' Connect to the IPEDS DuckDB database
#' @return A DBI connection object
connect_ipeds <- function() {
  path <- Sys.getenv("IPEDS_DB_PATH")
  if (path == "") stop("IPEDS_DB_PATH not set. Run setup_ipeds() first.")
  DBI::dbConnect(duckdb::duckdb(), dbdir = path)
}
