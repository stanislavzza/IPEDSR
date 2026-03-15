#' Database Management for IPEDSR
#'
#' Functions to manage the IPEDS DuckDB database including setup,
#' updates, archiving, and connection management.

# Package-private environment
.ipeds_env <- new.env(parent = emptyenv())

# Default release asset URL
.IPEDS_DB_URL <- "https://github.com/stanislavzza/IPEDSR/releases/download/v1.0-beta.0/ipeds.duckdb.gz"

# Default database filename
.IPEDS_DB_NAME <- "ipeds.duckdb"


# ---------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------

`%||%` <- function(x, y) {
  if (is.null(x) || !nzchar(x)) y else x
}

.ipedsr_config_file <- function() {
  cfg_dir <- rappdirs::user_config_dir("IPEDSR")
  if (!dir.exists(cfg_dir)) {
    dir.create(cfg_dir, recursive = TRUE, showWarnings = FALSE)
  }
  file.path(cfg_dir, "config.yml")
}

.normalize_slashes <- function(x) {
  gsub("\\\\", "/", x)
}

.ipeds_db_dir <- function() {
  cfg_file <- .ipedsr_config_file()
  dir_path <- NULL

  if (file.exists(cfg_file)) {
    cfg <- tryCatch(
      yaml::read_yaml(cfg_file),
      error = function(e) {
        stop("Failed to read config file '", cfg_file, "': ", e$message, call. = FALSE)
      }
    )

    if (!is.null(cfg$db_path) &&
        is.character(cfg$db_path) &&
        length(cfg$db_path) == 1L &&
        nzchar(cfg$db_path)) {
      dir_path <- path.expand(cfg$db_path)
    } else if (!is.null(cfg$db_path)) {
      warning("Ignoring invalid 'db_path' entry in config; using default location.", call. = FALSE)
    }
  }

  if (is.null(dir_path)) {
    dir_path <- rappdirs::user_data_dir("database", "IPEDSR")
  }

  .normalize_slashes(dir_path)
}

.validate_writable_dir <- function(dir_path, create_if_missing = TRUE) {
  stopifnot(is.character(dir_path), length(dir_path) == 1L, nzchar(dir_path))

  if (file.exists(dir_path) && !dir.exists(dir_path)) {
    stop("Path exists but is not a directory: '", dir_path, "'.", call. = FALSE)
  }

  if (!dir.exists(dir_path)) {
    if (!create_if_missing) {
      stop("Directory does not exist: '", dir_path, "'.", call. = FALSE)
    }

    ok <- tryCatch(
      dir.create(dir_path, recursive = TRUE, showWarnings = FALSE),
      error = function(e) FALSE
    )

    if (!isTRUE(ok) && !dir.exists(dir_path)) {
      stop("Failed to create directory '", dir_path, "'. Check permissions.", call. = FALSE)
    }
  }

  probe <- file.path(
    dir_path,
    paste0(".ipedsr_write_test_", Sys.getpid(), "_", as.integer(stats::runif(1, 1, 1e9)))
  )

  ok <- tryCatch(
    file.create(probe),
    warning = function(w) FALSE,
    error = function(e) FALSE
  )

  if (!isTRUE(ok)) {
    stop("Cannot write to directory '", dir_path, "'. Check permissions.", call. = FALSE)
  }

  unlink(probe, force = TRUE)
  invisible(dir_path)
}

.file_size_bytes <- function(path) {
  if (!file.exists(path)) return(NA_real_)
  file.info(path)$size
}

.file_is_html <- function(path, max_bytes = 1024L) {
  if (!file.exists(path)) return(TRUE)
  fb <- readBin(path, what = "raw", n = max_bytes)
  if (!length(fb)) return(TRUE)
  txt <- rawToChar(fb[fb != as.raw(0)])
  grepl("<html|<!DOCTYPE|<head|<body", txt, ignore.case = TRUE)
}

.file_large_enough <- function(path, min_bytes = 5e7) {
  sz <- .file_size_bytes(path)
  !is.na(sz) && sz >= min_bytes
}

.resolve_ipeds_db_url <- function(db_url = NULL) {
  if (!is.null(db_url) && nzchar(db_url)) {
    return(db_url)
  }

  env_url <- Sys.getenv("IPEDS_DB_URL", unset = "")
  if (nzchar(env_url)) {
    return(env_url)
  }

  if (exists(".IPEDS_DB_URL", inherits = TRUE)) {
    return(get(".IPEDS_DB_URL", inherits = TRUE))
  }

  stop(
    "No database URL available. Supply `db_url=`, set env var IPEDS_DB_URL, ",
    "or define .IPEDS_DB_URL in the package.",
    call. = FALSE
  )
}

.stream_copy <- function(in_con, out_con, chunk_size = 1024L * 1024L) {
  repeat {
    buf <- readBin(in_con, what = raw(), n = chunk_size)
    if (!length(buf)) break
    writeBin(buf, out_con)
  }
  invisible(TRUE)
}

.decompress_gz_file <- function(gz_path, out_path, overwrite = TRUE) {
  gz_path <- path.expand(gz_path)
  out_path <- path.expand(out_path)

  if (!file.exists(gz_path)) {
    stop("Compressed file not found: ", gz_path, call. = FALSE)
  }

  if (file.exists(out_path) && !overwrite) {
    stop("Output file already exists: ", out_path, call. = FALSE)
  }

  dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)

  in_con <- gzfile(gz_path, open = "rb")
  out_con <- file(out_path, open = "wb")

  on.exit({
    try(close(in_con), silent = TRUE)
    try(close(out_con), silent = TRUE)
  }, add = TRUE)

  .stream_copy(in_con, out_con)

  invisible(out_path)
}

.compress_gz_file <- function(in_path, gz_path, overwrite = TRUE, compression = 6L) {
  in_path <- path.expand(in_path)
  gz_path <- path.expand(gz_path)

  if (!file.exists(in_path)) {
    stop("Input file not found: ", in_path, call. = FALSE)
  }

  if (file.exists(gz_path) && !overwrite) {
    stop("Output file already exists: ", gz_path, call. = FALSE)
  }

  if (!grepl("\\.gz$", gz_path, ignore.case = TRUE)) {
    stop("Output archive path must end in '.gz'.", call. = FALSE)
  }

  if (!is.numeric(compression) || length(compression) != 1L ||
      is.na(compression) || compression < 1L || compression > 9L) {
    stop("`compression` must be an integer between 1 and 9.", call. = FALSE)
  }

  dir.create(dirname(gz_path), recursive = TRUE, showWarnings = FALSE)

  in_con <- file(in_path, open = "rb")
  out_con <- gzfile(gz_path, open = "wb", compression = as.integer(compression))

  on.exit({
    try(close(in_con), silent = TRUE)
    try(close(out_con), silent = TRUE)
  }, add = TRUE)

  .stream_copy(in_con, out_con)

  invisible(gz_path)
}

.is_valid_duckdb_file <- function(path) {
  if (!file.exists(path)) return(FALSE)
  if (!.file_large_enough(path, min_bytes = 1e6)) return(FALSE)

  con <- NULL
  ok <- tryCatch({
    con <- DBI::dbConnect(duckdb::duckdb(), dbdir = path, read_only = TRUE)
    TRUE
  }, error = function(e) FALSE)

  if (!is.null(con)) {
    try(DBI::dbDisconnect(con, shutdown = TRUE), silent = TRUE)
  }

  ok
}

.download_with_retry <- function(url, destfile, quiet = FALSE, tries = 5L) {
  last_err <- NULL

  for (i in seq_len(tries)) {
    if (!quiet) {
      message(sprintf("Download attempt %d of %d...", i, tries))
    }

    if (file.exists(destfile)) {
      unlink(destfile)
    }

    ok <- tryCatch({
      curl::curl_download(
        url = url,
        destfile = destfile,
        mode = "wb",
        quiet = quiet
      )
      TRUE
    }, error = function(e) {
      last_err <<- e$message
      FALSE
    })

    if (ok) {
      return(invisible(TRUE))
    }

    if (i < tries) {
      Sys.sleep(2^i)
    }
  }

  stop("Download failed. ", last_err %||% "Unknown network error.", call. = FALSE)
}


# ---------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------

#' Get IPEDS database path
#'
#' @description Returns the full path to the IPEDS DuckDB file.
#'   If a user-configured directory is present in the package config file,
#'   that location is used; otherwise a persistent per-user data directory
#'   is used.
#'
#' @return Character scalar giving the full path to the DuckDB file.
#' @export
get_ipeds_db_path <- function() {
  dir_path <- .ipeds_db_dir()

  if (!dir.exists(dir_path)) {
    dir.create(dir_path, recursive = TRUE, showWarnings = FALSE)
  }

  file.path(dir_path, .IPEDS_DB_NAME)
}

#' Set the IPEDS database directory
#'
#' @description Persists the directory where the IPEDS database file should
#'   be stored. The directory will be created if needed and checked for
#'   writability.
#'
#' @param path Character scalar giving the target directory.
#'
#' @return Invisibly returns the normalized directory path.
#' @export
set_ipeds_db_path <- function(path) {
  if (missing(path) || !is.character(path) || length(path) != 1L || !nzchar(path)) {
    stop("`path` must be a single, non-empty character string.", call. = FALSE)
  }

  dir_path <- .normalize_slashes(path.expand(path))
  .validate_writable_dir(dir_path, create_if_missing = TRUE)

  cfg_file <- .ipedsr_config_file()

  tryCatch(
    yaml::write_yaml(list(db_path = dir_path), cfg_file),
    error = function(e) {
      stop("Failed to write config file '", cfg_file, "': ", e$message, call. = FALSE)
    }
  )

  message("IPEDS database directory set to: ", dir_path)
  invisible(dir_path)
}

#' Check whether the IPEDS database exists and is usable
#'
#' @description Returns TRUE if the configured database file exists and can be
#'   opened by DuckDB in read-only mode.
#'
#' @return Logical scalar.
#' @export
ipeds_database_exists <- function() {
  .is_valid_duckdb_file(get_ipeds_db_path())
}

#' Download the IPEDS database
#'
#' @description Downloads a compressed IPEDS DuckDB archive, decompresses it
#'   to the configured location, and verifies that the result is a usable
#'   DuckDB database.
#'
#' @param force Logical; if TRUE, re-download even if a valid local database exists.
#' @param quiet Logical; if TRUE, suppress progress messages.
#' @param db_url Character; direct URL to the compressed `.gz` archive.
#'   If NULL, uses `IPEDS_DB_URL` from the environment, then `.IPEDS_DB_URL`.
#'
#' @return TRUE on success.
#' @export
download_ipeds_database <- function(force = FALSE, quiet = FALSE, db_url = NULL) {
  db_path <- path.expand(get_ipeds_db_path())
  archive_url <- .resolve_ipeds_db_url(db_url)
  tmp_gz <- tempfile(pattern = "ipeds_db_", fileext = ".duckdb.gz")

  if (!force && ipeds_database_exists()) {
    if (!quiet) {
      sz <- .file_size_bytes(db_path)
      message("IPEDS database already exists at: ", db_path)
      if (!is.na(sz)) {
        message("File size: ", round(sz / 1e9, 2), " GB")
      }
    }
    return(TRUE)
  }

  if (!quiet) {
    message("Setting up IPEDS database...")
    message("This may take a while because the archive is large.")
  }

  dir.create(dirname(db_path), recursive = TRUE, showWarnings = FALSE)

  tryCatch({
    if (!quiet) {
      message("Downloading compressed IPEDS database archive...")
    }

    .download_with_retry(
      url = archive_url,
      destfile = tmp_gz,
      quiet = quiet,
      tries = 5L
    )

    if (.file_is_html(tmp_gz) || !.file_large_enough(tmp_gz)) {
      stop(
        "Downloaded file looks like HTML or is unexpectedly small. ",
        "Check that `db_url` points directly to the .gz release asset.",
        call. = FALSE
      )
    }

    if (!quiet) {
      message("Decompressing database archive...")
    }

    if (file.exists(db_path)) {
      unlink(db_path)
    }

    .decompress_gz_file(tmp_gz, db_path, overwrite = TRUE)

    if (!.is_valid_duckdb_file(db_path)) {
      stop(
        "Archive was downloaded and unpacked, but the resulting file does not appear ",
        "to be a valid DuckDB database.",
        call. = FALSE
      )
    }

    if (!quiet) {
      sz <- .file_size_bytes(db_path)
      message("IPEDS database successfully downloaded and verified.")
      message("Database location: ", db_path)
      if (!is.na(sz)) {
        message("File size: ", round(sz / 1e9, 2), " GB")
      }
    }

    TRUE
  }, error = function(e) {
    if (file.exists(db_path)) {
      unlink(db_path)
    }
    stop("Failed to set up IPEDS database: ", e$message, call. = FALSE)
  }, finally = {
    if (file.exists(tmp_gz)) {
      unlink(tmp_gz)
    }
  })
}

#' Check whether the local database may be outdated
#'
#' @description Uses the file modification time of the local database file
#'   as a proxy for age.
#'
#' @param max_age_days Numeric scalar; age threshold in days.
#'
#' @return Logical scalar. FALSE if the database file does not exist.
#' @export
database_outdated <- function(max_age_days = 120) {
  db_path <- get_ipeds_db_path()

  if (!file.exists(db_path)) {
    return(FALSE)
  }

  mod_time <- file.info(db_path)$mtime
  if (is.na(mod_time)) {
    return(FALSE)
  }

  age_days <- as.numeric(difftime(Sys.time(), mod_time, units = "days"))
  isTRUE(age_days > max_age_days)
}

#' Open a connection to the IPEDS database
#'
#' @description Opens a DuckDB connection to the configured IPEDS database.
#'
#' @param read_only Logical; if TRUE, open in read-only mode.
#'
#' @return A DBI connection.
#' @export
get_ipeds_connection <- function(read_only = TRUE) {
  if (!ipeds_database_exists()) {
    stop(
      "IPEDS database not found or invalid. Run `download_ipeds_database()` first.",
      call. = FALSE
    )
  }

  if (database_outdated()) {
    message(
      "Note: your IPEDS database is more than 120 days old. ",
      "Consider refreshing it with `download_ipeds_database(force = TRUE)`."
    )
  }

  DBI::dbConnect(
    duckdb::duckdb(),
    dbdir = get_ipeds_db_path(),
    read_only = read_only
  )
}

#' Create a compressed archive of the local IPEDS database
#'
#' @description Compresses the local IPEDS DuckDB file to a `.gz` archive
#'   suitable for distribution as a GitHub release asset.
#'
#' @param output_path Character scalar; output archive path ending in `.gz`.
#' @param overwrite Logical; if TRUE, overwrite an existing output file.
#' @param quiet Logical; if TRUE, suppress progress messages.
#' @param compression Integer from 1 to 9; larger values compress more but may be slower.
#'
#' @return Invisibly returns `output_path`.
#' @export
create_ipeds_database_archive <- function(output_path,
                                          overwrite = FALSE,
                                          quiet = FALSE,
                                          compression = 6L) {
  db_path <- path.expand(get_ipeds_db_path())
  output_path <- path.expand(output_path)

  if (!ipeds_database_exists()) {
    stop("No valid IPEDS database found at: ", db_path, call. = FALSE)
  }

  if (!quiet) {
    sz_in <- .file_size_bytes(db_path)
    message("Compressing IPEDS database...")
    message("Input:  ", db_path)
    if (!is.na(sz_in)) {
      message("Size:   ", round(sz_in / 1e9, 2), " GB")
    }
    message("Output: ", output_path)
  }

  .compress_gz_file(
    in_path = db_path,
    gz_path = output_path,
    overwrite = overwrite,
    compression = compression
  )

  if (!quiet) {
    sz_out <- .file_size_bytes(output_path)
    message("Compressed archive created successfully.")
    if (!is.na(sz_out)) {
      message("Compressed size: ", round(sz_out / 1e9, 2), " GB")
    }
  }

  invisible(output_path)
}

#' Print IPEDS database information
#' @export
print_ipeds_db_info <- function() {
  db_path <- get_ipeds_db_path()
  exists <- ipeds_database_exists()
  size <- .file_size_bytes(db_path)

  cat("IPEDS DB path: ", db_path, "\n", sep = "")
  cat("Exists/valid:  ", exists, "\n", sep = "")
  if (!is.na(size)) cat("Size (GB):    ", round(size / 1e9, 2), "\n", sep = "")
  invisible(list(path = db_path, exists = exists, size = size))
}
