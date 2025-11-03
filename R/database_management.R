#' Database Management for IPEDSR
#'
#' Functions to manage the IPEDS database including setup, updates, and connection management.

# Global variables for package
.ipeds_env <- new.env(parent = emptyenv())

# Database configuration
.IPEDS_DB_URL <- "https://www.dropbox.com/scl/fi/rrevsok6nmabcjoz4b9gp/ipeds_2004-2023.duckdb?rlkey=brdhb0bxjbwhva9jm1a7j89kh&dl=0"
.IPEDS_DB_NAME <- "ipeds.duckdb"

#' Get IPEDS database path
#' @description Returns the path where the IPEDS database should be stored.
#' Always uses the user's persistent data directory to avoid re-downloading.
#' @return Character string with the database path
#' @export
get_ipeds_db_path <- function() {
  # Use user's data directory - this is persistent across package reloads
  data_dir <- rappdirs::user_data_dir("database","IPEDSR" )
  if (!dir.exists(data_dir)) {
    dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
  }
  # normalize file path with slashes
  data_dir <- str_replace_all(data_dir, "\\\\", "/")
  file.path(data_dir, .IPEDS_DB_NAME)
}

#' Check if IPEDS database exists and is valid
#' @description Checks if the database file exists and has a reasonable size
#' @return Logical indicating if database is ready to use
#' @export
ipeds_database_exists <- function() {
  db_path <- get_ipeds_db_path()

  if (!file.exists(db_path)) return(FALSE)

  return(TRUE)
}

#' Download IPEDS database (from Dropbox)
#' @description Downloads the IPEDS database from a Dropbox shared link and sets it up for use
#' @param force Logical, if TRUE will re-download even if database exists
#' @param quiet Logical, if TRUE suppresses progress messages
#' @param dropbox_url Character. Public Dropbox link to the DB file. If NULL, uses .IPEDS_DB_URL or env var IPEDS_DB_DROPBOX_URL.
#' @return Logical indicating success
#' @export
download_ipeds_database <- function(force = FALSE, quiet = FALSE, dropbox_url = NULL) {
  # ---- helpers ---------------------------------------------------------------
  normalize_dropbox_direct_url <- function(u) {
    if (is.null(u) || !nzchar(u)) return(u)
    # Accept both old /s/ and new /scl/fi/ links. Force direct download.
    # If there's already a query, replace/append dl=1; otherwise add ?dl=1
    if (!grepl("dropbox\\.com", u, ignore.case = TRUE)) return(u)
    # Strip any dl param and force dl=1
    if (grepl("\\?", u)) {
      u <- sub("(?:[&?])dl=0", "", u)
      u <- sub("(?:[&?])dl=1", "", u)
      paste0(u, "&dl=1")
    } else {
      paste0(u, "?dl=1")
    }
  }

  is_html_file <- function(path, max_bytes = 1024L) {
    if (!file.exists(path)) return(TRUE)
    fb <- readBin(path, what = "raw", n = max_bytes)
    if (!length(fb)) return(TRUE)
    txt <- rawToChar(fb[fb != as.raw(0)])
    grepl("<html|<!DOCTYPE|<head|<body", txt, ignore.case = TRUE)
  }

  file_large_enough <- function(path, min_bytes = 5e7) {  # 50MB sanity check
    fi <- file.info(path)
    !is.na(fi$size) && fi$size >= min_bytes
  }

  db_path <- get_ipeds_db_path()
  db_path <- path.expand(db_path)

  # Bail early if present and big enough (unless force)
  if (!force) {
    if (file.exists(db_path)) {
      file_size <- file.info(db_path)$size
      if (!is.na(file_size) && file_size > 1e9) {  # > 1 GB likely valid
        if (!quiet) {
          message("IPEDS database already exists at: ", db_path)
          message("File size: ", round(file_size / 1e9, 2), " GB")
        }
        return(TRUE)
      }
    }
    if (ipeds_database_exists()) {
      if (!quiet) message("IPEDS database already exists and is valid at: ", db_path)
      return(TRUE)
    }
  }

  if (!quiet) {
    message("Setting up IPEDS database from Dropbox...")
    message("This is a large file and may take a while to download.")
  }

  # Resolve Dropbox URL (parameter wins; else env; else package option/variable)
  if (is.null(dropbox_url) || !nzchar(dropbox_url)) {
    dropbox_url <- Sys.getenv("IPEDS_DB_DROPBOX_URL", unset = NA_character_)
    if (is.na(dropbox_url) || !nzchar(dropbox_url)) {
      # fall back to legacy package-level constant if you keep the same name
      if (exists(".IPEDS_DB_URL", inherits = TRUE)) {
        dropbox_url <- get(".IPEDS_DB_URL", inherits = TRUE)
      } else {
        stop("No Dropbox URL provided. Set `dropbox_url=`, or env var IPEDS_DB_DROPBOX_URL, or define .IPEDS_DB_URL.")
      }
    }
  }

  direct_url <- normalize_dropbox_direct_url(dropbox_url)

  # Download (use curl for robust streaming of large files)
  # Retry a few times for transient network hiccups
  tryCatch({
    if (!quiet) message("Downloading IPEDS database from Dropbox...")

    # Ensure target dir exists
    dir.create(dirname(db_path), recursive = TRUE, showWarnings = FALSE)

    # Use curl with manual retry loop
    tries <- 5L
    ok <- FALSE
    last_err <- NULL
    for (i in seq_len(tries)) {
      if (!quiet) message(sprintf("Attempt %d of %d...", i, tries))
      # Remove partial file before retry to avoid confusion
      if (file.exists(db_path)) unlink(db_path)

      # Quiet=TRUE silences progress; FALSE shows progress bar
      # mode='wb' to avoid Windows newline weirdness
      try({
        curl::curl_download(url = direct_url, destfile = db_path, mode = "wb", quiet = quiet)
        ok <- TRUE
      }, silent = TRUE)

      if (ok) {
        # Quick sanity checks
        if (is_html_file(db_path) || !file_large_enough(db_path)) {
          ok <- FALSE
          last_err <- "Downloaded file looks like HTML or is unexpectedly small. Check that the Dropbox link is public and ends with ?dl=1."
          # Back off slightly before retry
          Sys.sleep(if (i < tries) 2^i else 0)
        } else {
          break
        }
      } else {
        last_err <- "Network error during download."
        Sys.sleep(if (i < tries) 2^i else 0)
      }
    }

    if (!ok) stop(last_err %||% "Failed to download file.")

    # Final verify using your existing checker
    if (!ipeds_database_exists()) {
      stop(
        paste0(
          "Downloaded file appears invalid. ",
          "Ensure the Dropbox link points directly to the database file (use a public shared link with ?dl=1)."
        )
      )
    }

    # Store metadata about the download
    # store_database_metadata(source = "dropbox", url = dropbox_url)

    if (!quiet) {
      sz <- file.info(db_path)$size
      message("IPEDS database successfully downloaded and verified!")
      message("Database location: ", db_path)
      if (!is.na(sz)) message("File size: ", round(sz / 1e9, 2), " GB")
    }

    TRUE
  }, error = function(e) {
    if (file.exists(db_path)) file.remove(db_path)
    stop("Failed to setup IPEDS database: ", e$message)
  })
}

#' Check if database needs updating
#' @description Checks if the database should be updated based on age
#' @param max_age_days Maximum age of database in days before suggesting update
#' @return Logical indicating if update is recommended
#' @export
database_outdated <- function(max_age_days = 120) {

  download_date <- file.info(get_ipeds_db_path())$ctime

  days_since_download <- as.numeric(Sys.time() - download_date)/(60*60*24)
  return(days_since_download > max_age_days)
}

#' Get database connection
#' @description Internal function to get a database connection
#' @param read_only Logical, if TRUE opens connection in read-only mode
#' @return DBI connection object
#' @export
get_ipeds_connection <- function(read_only = TRUE) {
  # Check if database exists, if not, set it up
  if (!ipeds_database_exists()) {
    stop("IPEDS database not found. Use download_ipeds_database().")
  }

  # Check if database is old and suggest update
  if (database_outdated()) {
    message("Note: Your IPEDS database is more than 120 days old. Consider updating with download_ipeds_database()")
  }

  db_path <- get_ipeds_db_path()

  conn <- DBI::dbConnect(duckdb::duckdb(), db_path, read_only = read_only)

  return(conn)
}


