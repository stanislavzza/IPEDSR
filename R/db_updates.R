#' This script has functions to update the IPEDS database by scraping the Data
#' Center's Complete Data Files page for a given year, extracting the table
#' names and download links, and downloading the CSV files and dictionaries.
#' The main functions are:
#' - `ipeds_dc_index()`: Scrapes the Data Center page for a specified year and
#' returns a data frame with table names, CSV URLs, and dictionary URLs.


#' IPEDS Data Center: Complete Data Files index + downloader
#'
#' Minimal, intentionally "simple & slightly fragile" helpers that:
#'  - scrape the HTML results table on DataFiles.aspx (Complete Data Files)
#'  - extract the table_name plus CSV + Dictionary links
#'  - download CSVs (and optionally dictionaries)
#'
#' Dependencies: rvest, xml2, dplyr, stringr, tibble, purrr, readr, cli (optional)

#' Index file URLs for a given year of IPEDS data
#' @param year The IPEDS data year to index (e.g. 2024 for 2024-25 data)
#' @param base_url Base URL for making absolute URLs from relative links
#' @param page The URL of the Data Center page to scrape. Defaults to the
#' standard URL for the given year.
#' @return A tibble with columns: year, survey, title, table_name, csv_url, dict_url
#' @export
ipeds_dl_index <- function(year = 2024,
                           base_url = "https://nces.ed.gov",
                           page = sprintf("https://nces.ed.gov/ipeds/datacenter/DataFiles.aspx?year=%s", year)) {
  stopifnot(is.numeric(year) || is.character(year))
  year <- as.character(year)

  # Read page HTML
  html <- rvest::read_html(page)

  # The results table in your paste is: id="contentPlaceHolder_tblResult"
  tbl <- html |>
    rvest::html_element("#contentPlaceHolder_tblResult")

  if (is.na(tbl)) {
    stop("Could not find results table #contentPlaceHolder_tblResult on the page.")
  }

  rows <- tbl |>
    rvest::html_elements("tr") |>
    # drop header row(s)
    (\(x) x[-1])()

  parse_row <- function(r) {
    tds <- rvest::html_elements(r, "td")
    if (length(tds) < 4) return(NULL)

    year_txt   <- rvest::html_text(tds[[1]], trim = TRUE)
    survey_txt <- rvest::html_text(tds[[2]], trim = TRUE)
    title_txt  <- rvest::html_text(tds[[3]], trim = TRUE)

    # Data File cell: contains the CSV link (anchor text is the table name)
    data_a <- rvest::html_element(tds[[4]], "a")
    if (is.na(data_a)) return(NULL)

    table_name <- rvest::html_text(data_a, trim = TRUE)
    csv_href   <- rvest::html_attr(data_a, "href")

    # Dictionary cell: last column, has "Dictionary" link
    dict_a   <- rvest::html_element(tds[[7]], "a")
    dict_href <- if (!is.na(dict_a)) rvest::html_attr(dict_a, "href") else NA_character_

    # Make absolute URLs (hrefs in the page are relative like "/ipeds/data-generator?...").
    csv_url  <- if (!is.na(csv_href))  xml2::url_absolute(csv_href,  base_url) else NA_character_
    dict_url <- if (!is.na(dict_href)) xml2::url_absolute(dict_href, base_url) else NA_character_

    tibble::tibble(
      year       = year_txt,
      survey     = survey_txt,
      title      = title_txt,
      table_name = table_name,
      csv_url    = csv_url,
      dict_url   = dict_url
    )
  }

  out <- purrr::map_dfr(rows, parse_row)

  # A bunch of tables (like FLAGS2024) appear multiple times across surveys on that page.
  # Keep first occurrence by default (you can change this if you ever want).
  out <- out |>
    dplyr::distinct(table_name, .keep_all = TRUE)

  out
}

#' Load IPEDS CSV/ZIP files listed in an index tibble into DuckDB
#'
#' @param index A tibble with columns: table_name, csv_url (and whatever else)
#' @param db_path Path to duckdb database. Defaults to get_ipeds_db_path()
#' @param base_url Base URL used when csv_url is relative (starts with "/")
#' @param overwrite If TRUE, replace tables when they already exist
#' @param verbose Print progress
#' @return Invisibly returns a tibble log of tables loaded and file paths used
#' @export
load_ipeds_index_to_duckdb <- function(index,
                                       db_path = get_ipeds_db_path(),
                                       base_url = "https://nces.ed.gov",
                                       overwrite = TRUE,
                                       verbose = TRUE) {
  stopifnot(is.data.frame(index))
  needed <- c("table_name", "csv_url")
  missing_cols <- setdiff(needed, names(index))
  if (length(missing_cols) > 0) {
    stop("index is missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  # dependencies used explicitly
  if (!requireNamespace("DBI", quietly = TRUE)) stop("Please install DBI")
  if (!requireNamespace("duckdb", quietly = TRUE)) stop("Please install duckdb")
  if (!requireNamespace("dplyr", quietly = TRUE)) stop("Please install dplyr")

  # helper: make absolute URL if IPEDS gave you a relative one like "/ipeds/data-generator?..."
  make_abs_url <- function(u) {
    if (is.na(u) || !nzchar(u)) return(NA_character_)
    if (grepl("^https?://", u)) return(u)
    if (startsWith(u, "/")) return(paste0(base_url, u))
    paste0(base_url, "/", u)
  }

  # helper: download to a file (keeps it simple + robust)
  download_to <- function(url, dest) {
    # use base download.file so you don’t add extra deps
    utils::download.file(url, destfile = dest, mode = "wb", quiet = TRUE)
    dest
  }

  # helper: pick the “right” csv from an unzip dir (often only one; sometimes multiple)
  choose_csv <- function(dir, table_name) {
    csvs <- list.files(dir, pattern = "\\.csv$", full.names = TRUE, ignore.case = TRUE)
    if (length(csvs) == 0) stop("Zip contained no .csv files.")

    # Prefer exact-ish match on table name (HD2024.csv, HD2024_RV.csv, etc.)
    bn <- basename(csvs)
    hits <- grep(paste0("^", table_name, "($|[^A-Za-z0-9]).*\\.csv$"),
                 bn, ignore.case = TRUE, value = FALSE)
    if (length(hits) >= 1) return(csvs[hits[1]])

    # Next best: any csv containing the table_name
    hits2 <- grep(table_name, bn, ignore.case = TRUE, value = FALSE)
    if (length(hits2) >= 1) return(csvs[hits2[1]])

    # Fallback: first csv
    csvs[1]
  }

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path, read_only = FALSE)
  on.exit({
    DBI::dbDisconnect(con, shutdown = TRUE)
  }, add = TRUE)

  log <- vector("list", nrow(index))

  for (i in seq_len(nrow(index))) {
    table_name <- as.character(index$table_name[i])
    url <- make_abs_url(as.character(index$csv_url[i]))

    if (verbose) {
      msg <- sprintf("[%d/%d] %s", i, nrow(index), table_name)
      message(msg)
    }

    tmp_download <- tempfile(fileext = ".bin")
    download_to(url, tmp_download)

    # Decide whether it’s a zip by signature rather than extension
    # Zip files start with "PK"
    sig <- tryCatch(readBin(tmp_download, "raw", n = 2), error = function(e) raw(0))
    is_zip <- length(sig) == 2 && identical(sig, charToRaw("PK"))

    if (is_zip) {
      unzip_dir <- tempfile(pattern = "ipeds_unzip_")
      dir.create(unzip_dir, recursive = TRUE)
      utils::unzip(tmp_download, exdir = unzip_dir)

      csv_path <- choose_csv(unzip_dir, table_name)
    } else {
      # sometimes IPEDS really is a plain CSV
      # ensure it has a .csv extension so DuckDB’s sniffing is happy
      csv_path <- tempfile(fileext = ".csv")
      file.copy(tmp_download, csv_path, overwrite = TRUE)
    }

    # Create/replace table using DuckDB, avoiding loading into R
    id <- DBI::dbQuoteIdentifier(con, table_name)
    path_q <- DBI::dbQuoteString(con, normalizePath(csv_path, winslash = "/", mustWork = TRUE))

    if (overwrite) {
      sql <- paste0(
        "CREATE OR REPLACE TABLE ", id, " AS ",
        "SELECT * FROM read_csv_auto(", path_q, ");"
      )
    } else {
      sql <- paste0(
        "CREATE TABLE IF NOT EXISTS ", id, " AS ",
        "SELECT * FROM read_csv_auto(", path_q, ");"
      )
    }

    DBI::dbExecute(con, sql)

    # optional: lightweight row count for the log (fast in DuckDB)
    n_rows <- DBI::dbGetQuery(con, paste0("SELECT COUNT(*) AS n FROM ", id))$n[1]

    log[[i]] <- data.frame(
      table_name = table_name,
      url = url,
      local_file = csv_path,
      is_zip = is_zip,
      n_rows = n_rows,
      stringsAsFactors = FALSE
    )
  }

  dplyr::bind_rows(log)
}

# Example usage:
# idx <- get_ipeds_index(2024)  # whatever you named your index function
# load_log <- load_ipeds_index_to_duckdb(idx)
# load_log

#' Write IPEDS "TablesYY" metadata table to DuckDB from an index tibble
#'
#' Creates a table named TablesYY (e.g., Tables24) with columns:
#'   Survey, TableName, TableTitle
#'
#' @param index Tibble/data.frame with columns: year, survey, table_name, title
#' @param db_path DuckDB path. Defaults to get_ipeds_db_path()
#' @param overwrite If TRUE, replaces existing table
#' @param year Optional override if index contains multiple years or year is missing
#' @return Invisibly returns the table name created (e.g., "Tables24")
#' @export
write_ipeds_tables_meta <- function(index,
                                    db_path = get_ipeds_db_path(),
                                    overwrite = TRUE,
                                    year = NULL) {
  stopifnot(is.data.frame(index))

  needed <- c("survey", "table_name", "title")
  missing_cols <- setdiff(needed, names(index))
  if (length(missing_cols) > 0) {
    stop("index is missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  # Determine year
  if (is.null(year)) {
    if (!("year" %in% names(index))) {
      stop("index has no 'year' column; provide year= explicitly.")
    }
    yrs <- unique(stats::na.omit(index$year))
    if (length(yrs) != 1) {
      stop("index contains multiple years (or none). Provide year= explicitly.")
    }
    year <- as.integer(yrs[[1]])
  } else {
    year <- as.integer(year)
  }

  yy <- sprintf("%02d", year %% 100)
  meta_table <- paste0("Tables", yy)

  meta <- index |>
    dplyr::transmute(
      Survey = .data$survey,
      TableName = .data$table_name,
      TableTitle = .data$title
    ) |>
    dplyr::distinct() |>
    dplyr::arrange(.data$Survey, .data$TableName)

  if (!requireNamespace("DBI", quietly = TRUE)) stop("Please install DBI")
  if (!requireNamespace("duckdb", quietly = TRUE)) stop("Please install duckdb")

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path, read_only = FALSE)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE), add = TRUE)

  if (overwrite) {
    DBI::dbExecute(con, paste0("DROP TABLE IF EXISTS ", DBI::dbQuoteIdentifier(con, meta_table)))
  }

  DBI::dbWriteTable(con, name = meta_table, value = meta, overwrite = overwrite)

  invisible(meta_table)
}

# Example:
# idx_2024 <- get_ipeds_index(2024)
# write_ipeds_tables_meta(idx_2024)  # creates Tables24 in your DuckDB
