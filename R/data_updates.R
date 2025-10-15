#' IPEDS Data Update Management
#' 
#' Functions for detecting, downloading, and integrating new IPEDS data releases

#' Check for new IPEDS data releases
#' @param years Vector of years to check, defaults to current year
#' @param verbose Whether to print detailed information
#' @return A data frame with information about available data files
#' @export
check_ipeds_updates <- function(years = NULL, verbose = TRUE) {
  if (is.null(years)) {
    years <- as.numeric(format(Sys.Date(), "%Y"))
  }
  
  all_releases <- data.frame()
  
  for (year in years) {
    if (verbose) {
      message("Checking IPEDS releases for ", year, "...")
    }
    
    year_data <- scrape_ipeds_releases(year, verbose = verbose)
    if (nrow(year_data) > 0) {
      all_releases <- rbind(all_releases, year_data)
    }
  }
  
  return(all_releases)
}

#' Scrape IPEDS data file information from NCES website
#' @param year The year to scrape data for
#' @param verbose Whether to print progress messages
#' @return A data frame with file information
scrape_ipeds_releases <- function(year, verbose = FALSE) {
  
  # Construct the URL for the specific year
  url <- paste0("https://nces.ed.gov/ipeds/datacenter/DataFiles.aspx?year=", year)
  
  if (verbose) {
    message("Fetching data from: ", url)
  }
  
  # Try to fetch the webpage
  tryCatch({
    response <- httr::GET(url)
    
    if (httr::status_code(response) != 200) {
      warning("Failed to fetch data for year ", year, ". Status: ", httr::status_code(response))
      return(data.frame())
    }
    
    # Parse the HTML content
    content <- httr::content(response, as = "text", encoding = "UTF-8")
    
    # Extract table information using regex patterns
    files_info <- parse_ipeds_table(content, year)
    
    return(files_info)
    
  }, error = function(e) {
    warning("Error fetching data for year ", year, ": ", e$message)
    return(data.frame())
  })
}

#' Parse IPEDS data table from HTML content
#' @param html_content Raw HTML content from IPEDS page
#' @param year The year being parsed
#' @return A data frame with parsed file information
parse_ipeds_table <- function(html_content, year) {
  
  # This is a simplified parser - in production you'd want to use rvest or xml2
  # for more robust HTML parsing
  
  # Pattern to match table rows with data files
  # Looking for patterns like: | 2024 | Survey Component | Description | TableName | etc.
  
  # For now, return a placeholder structure that we'll enhance
  # In practice, you'd parse the actual HTML table
  
  data.frame(
    year = character(0),
    survey_component = character(0),
    description = character(0),
    table_name = character(0),
    csv_link = character(0),
    dictionary_link = character(0),
    file_size = character(0),
    last_modified = character(0),
    stringsAsFactors = FALSE
  )
}

#' Get current database version information
#' @return A data frame with current database metadata
#' @export
get_current_database_version <- function() {
  
  # Check if database exists
  if (!ipeds_database_exists()) {
    return(data.frame(
      component = character(0),
      year = integer(0),
      table_count = integer(0),
      last_updated = character(0),
      data_source = character(0)
    ))
  }
  
  # Connect to database and get metadata
  idbc <- ensure_connection()
  
  # Get all table names and analyze them
  tables <- DBI::dbListTables(idbc)
  
  # Extract year and component information from table names
  table_info <- analyze_table_names(tables)
  
  # Get database file modification time
  db_path <- get_ipeds_db_path()
  db_modified <- file.info(db_path)$mtime
  
  # Summarize by component and year
  summary_info <- table_info %>%
    dplyr::group_by(component, year) %>%
    dplyr::summarise(
      table_count = dplyr::n(),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      last_updated = as.character(db_modified),
      data_source = "existing_database"
    )
  
  return(summary_info)
}

#' Analyze table names to extract metadata
#' @param table_names Vector of table names from database
#' @return A data frame with parsed table information
analyze_table_names <- function(table_names) {
  
  # Create patterns for different IPEDS components
  patterns <- list(
    HD = list(pattern = "^HD(\\d{4})$", component = "Institutional Characteristics"),
    IC = list(pattern = "^IC(\\d{4})(_.*)?$", component = "Institutional Characteristics"),
    EF = list(pattern = "^EF(\\d{4})[A-Z]?$", component = "Enrollment"), 
    ADM = list(pattern = "^ADM(\\d{4})$", component = "Admissions"),
    C = list(pattern = "^C(\\d{4})_[A-Z]$", component = "Completions"),
    GR = list(pattern = "^GR(\\d{4}).*$", component = "Graduation Rates"),
    F = list(pattern = "^F(\\d{4})_.*$", component = "Finance"),
    SFA = list(pattern = "^SFA(\\d{4}).*$", component = "Student Financial Aid"),
    S = list(pattern = "^S(\\d{4})_.*$", component = "Human Resources"),
    SAL = list(pattern = "^SAL(\\d{4})_.*$", component = "Faculty Salaries"),
    EAP = list(pattern = "^EAP(\\d{4})$", component = "Employees by Assignment"),
    AL = list(pattern = "^AL(\\d{4}).*$", component = "Academic Libraries"),
    VALUESETS = list(pattern = "^VALUESETS(\\d{2})$", component = "Value Sets")
  )
  
  results <- data.frame()
  
  for (table_name in table_names) {
    for (comp_name in names(patterns)) {
      pattern_info <- patterns[[comp_name]]
      match <- stringr::str_match(table_name, pattern_info$pattern)
      
      if (!is.na(match[1])) {
        year_str <- match[2]
        
        # Handle different year formats
        if (comp_name == "VALUESETS") {
          # VALUESETS uses 2-digit years, convert to 4-digit
          year <- as.numeric(paste0("20", year_str))
        } else {
          year <- as.numeric(year_str)
        }
        
        results <- rbind(results, data.frame(
          table_name = table_name,
          component = pattern_info$component,
          year = year,
          component_code = comp_name,
          stringsAsFactors = FALSE
        ))
        break
      }
    }
  }
  
  return(results)
}

#' Compare available updates with current database
#' @param available_data Data frame from check_ipeds_updates()
#' @param current_data Data frame from get_current_database_version()
#' @return A data frame showing what updates are needed
#' @export
compare_data_versions <- function(available_data = NULL, current_data = NULL) {
  
  if (is.null(available_data)) {
    available_data <- check_ipeds_updates(verbose = FALSE)
  }
  
  if (is.null(current_data)) {
    current_data <- get_current_database_version()
  }
  
  # For now, return a placeholder - this would be enhanced with actual comparison logic
  data.frame(
    component = character(0),
    year = integer(0),
    status = character(0), # "new", "updated", "current"
    action_needed = character(0),
    priority = character(0),
    stringsAsFactors = FALSE
  )
}

#' Get IPEDS release schedule and timing information
#' @return A data frame with typical release dates for each component
#' @export
get_ipeds_release_schedule <- function() {
  
  # IPEDS typical release schedule (approximate)
  schedule <- data.frame(
    component = c(
      "Institutional Characteristics",
      "12-Month Enrollment", 
      "Fall Enrollment",
      "Completions",
      "Student Financial Aid",
      "Graduation Rates",
      "Finance",
      "Human Resources",
      "Academic Libraries",
      "Admissions"
    ),
    typical_release_month = c(
      "August",
      "December", 
      "February",
      "October",
      "April",
      "February",
      "May",
      "February",
      "December",
      "October"
    ),
    data_collection_period = c(
      "Fall",
      "July-June",
      "Fall",
      "July-June", 
      "Academic Year",
      "Cohort-based",
      "Fiscal Year",
      "Fall",
      "Fiscal Year",
      "Fall"
    ),
    stringsAsFactors = FALSE
  )
  
  return(schedule)
}

#' Download and process a single IPEDS data file
#' @param file_info Single row from available data with file information
#' @param temp_dir Directory to store temporary files
#' @param verbose Whether to print progress
#' @return Path to processed file or NULL if failed
download_ipeds_file <- function(file_info, temp_dir = tempdir(), verbose = TRUE) {
  
  if (verbose) {
    message("Downloading: ", file_info$table_name)
  }
  
  # This would implement the actual download logic
  # For now, return NULL as placeholder
  return(NULL)
}

#' Update IPEDS data for specified years
#' @param years Vector of years to update (4-digit integers), defaults to current year  
#' @param force_download Logical, if TRUE will re-download even if files exist
#' @param verbose Logical, if TRUE prints detailed progress messages
#' @param backup_first Logical, if TRUE creates database backup before updates
#' @return List with summary of what was updated
#' @export
update_data <- function(years = NULL, force_download = FALSE, verbose = TRUE, backup_first = TRUE) {
  
  if (is.null(years)) {
    current_year <- as.numeric(format(Sys.Date(), "%Y"))
    years <- current_year
    if (verbose) message("No years specified, checking current year: ", current_year)
  }
  
  # Ensure years are proper 4-digit integers
  years <- as.integer(years)
  years <- years[years >= 1990 & years <= 2030]  # Reasonable bounds
  
  if (length(years) == 0) {
    stop("No valid years specified. Please provide years between 1990 and 2030.")
  }
  
  if (verbose) {
    message("Starting IPEDS data update for years: ", paste(years, collapse=", "))
    message(paste(rep("=", 60), collapse=""))
  }
  
  # Backup database if requested
  if (backup_first && ipeds_database_exists()) {
    if (verbose) message("Creating database backup...")
    backup_database()
  }
  
  # Get downloads directory
  downloads_dir <- get_ipeds_downloads_path()
  
  # Initialize summary results
  update_summary <- data.frame(
    year = integer(0),
    data_files_found = integer(0),
    data_files_downloaded = integer(0),
    data_files_imported = integer(0),
    dict_files_found = integer(0),
    dict_files_downloaded = integer(0),
    dict_files_imported = integer(0),
    errors = character(0),
    stringsAsFactors = FALSE
  )
  
  # Connect to database
  con <- get_ipeds_connection(read_only = FALSE)
  
  # Process each year
  for (year in years) {
    if (verbose) {
      message("\nProcessing year ", year, "...")
      message(paste(rep("-", 40), collapse=""))
    }
    
    year_result <- process_year_data(year, downloads_dir, con, force_download, verbose)
    update_summary <- rbind(update_summary, year_result)
  }
  
  # Update consolidated dictionary tables
  if (verbose) {
    message("\nUpdating consolidated dictionary tables...")
  }
  update_consolidated_dictionaries_new(con, verbose)
  
  DBI::dbDisconnect(con)
  
  if (verbose) {
    message("\n", paste(rep("=", 60), collapse=""))
    message("UPDATE COMPLETE!")
    message(paste(rep("=", 60), collapse=""))
    print(update_summary)
  }
  
  return(update_summary)
}

#' Process data and dictionary files for a single year
process_year_data <- function(year, downloads_dir, con, force_download, verbose) {
  
  # Convert year to 2-digit format for IPEDS URLs
  year_2digit <- sprintf("%02d", year %% 100)
  
  # Initialize result
  result <- data.frame(
    year = year,
    data_files_found = 0,
    data_files_downloaded = 0, 
    data_files_imported = 0,
    dict_files_found = 0,
    dict_files_downloaded = 0,
    dict_files_imported = 0,
    errors = "",
    stringsAsFactors = FALSE
  )
  
  tryCatch({
    
    # 1. Scrape IPEDS data page for this year
    if (verbose) message("  Scraping IPEDS data page for ", year, "...")
    ipeds_url <- paste0("https://nces.ed.gov/ipeds/datacenter/DataFiles.aspx?year=", year)
    
    response <- httr::GET(ipeds_url)
    if (httr::status_code(response) != 200) {
      result$errors <- paste("Failed to access IPEDS page for", year)
      return(result)
    }
    
    content <- httr::content(response, as = "text", encoding = "UTF-8")
    
    # 2. Extract data and dictionary file links using comprehensive regex
    data_files <- extract_data_files_comprehensive(content, year_2digit)
    dict_files <- extract_dict_files_comprehensive(content, year_2digit)
    
    result$data_files_found <- length(data_files)
    result$dict_files_found <- length(dict_files)
    
    if (verbose) {
      message("    Found ", length(data_files), " data files and ", length(dict_files), " dictionary files")
    }
    
    # 3. Download and import data files
    if (length(data_files) > 0) {
      data_results <- process_data_files_new(data_files, downloads_dir, con, force_download, verbose)
      result$data_files_downloaded <- data_results$downloaded
      result$data_files_imported <- data_results$imported
    }
    
    # 4. Download and import dictionary files  
    if (length(dict_files) > 0) {
      dict_results <- process_dict_files_new(dict_files, downloads_dir, con, year, force_download, verbose)
      result$dict_files_downloaded <- dict_results$downloaded
      result$dict_files_imported <- dict_results$imported
    }
    
  }, error = function(e) {
    result$errors <<- e$message
    if (verbose) message("    ERROR: ", e$message)
  })
  
  return(result)
}

#' Extract data file information from IPEDS HTML content using regex patterns
extract_data_files_comprehensive <- function(html_content, year_2digit) {
  
  # Use comprehensive regex to find ZIP file hrefs
  zip_pattern <- paste0('href="([^"]*', year_2digit, '[^"]*\\.zip)"')
  
  matches <- gregexpr(zip_pattern, html_content, ignore.case = TRUE)
  zip_links <- regmatches(html_content, matches)[[1]]
  
  if (length(zip_links) == 0) {
    return(character(0))
  }
  
  # Extract URLs
  urls <- gsub('href="([^"]*)"', '\\1', zip_links)
  
  # Filter out dictionary files (containing "Dict" or "_Dict")
  data_urls <- urls[!grepl("_?[Dd]ict\\.zip", urls)]
  
  # Filter out ALL statistical software formats - we only want regular CSV files
  # Exclude: _Data_Stata.zip, _SPS.zip, _SAS.zip, _Stata.zip
  data_urls <- data_urls[!grepl("_(Data_)?Stata\\.zip$", data_urls)]
  data_urls <- data_urls[!grepl("_SPS\\.zip$", data_urls)]
  data_urls <- data_urls[!grepl("_SAS\\.zip$", data_urls)]
  
  # Construct full URLs
  base_url <- "https://nces.ed.gov/ipeds/datacenter/data/"
  full_urls <- ifelse(grepl("^http", data_urls), data_urls, paste0(base_url, basename(data_urls)))
  
  return(full_urls)
}

#' Extract dictionary file information from IPEDS HTML content
extract_dict_files_comprehensive <- function(html_content, year_2digit) {
  
  # Use regex pattern from our successful scraping
  dict_pattern <- 'href="([^"]*_?[Dd]ict\\.zip)"'
  
  matches <- gregexpr(dict_pattern, html_content, ignore.case = TRUE)
  dict_links <- regmatches(html_content, matches)[[1]]
  
  if (length(dict_links) == 0) {
    return(character(0))
  }
  
  # Extract URLs
  urls <- gsub('href="([^"]*)"', '\\1', dict_links)
  
  # Construct full URLs
  base_url <- "https://nces.ed.gov/ipeds/datacenter/data/"
  full_urls <- ifelse(grepl("^http", urls), urls, paste0(base_url, basename(urls)))
  
  return(full_urls)
}

#' Process (download and import) data files
process_data_files_new <- function(data_files, downloads_dir, con, force_download, verbose) {
  
  downloaded <- 0
  imported <- 0
  
  for (data_url in data_files) {
    filename <- basename(data_url)
    local_path <- file.path(downloads_dir, filename)
    
    # Download if needed
    if (!file.exists(local_path) || force_download) {
      if (verbose) message("    Downloading data file: ", filename)
      
      response <- httr::GET(data_url, httr::write_disk(local_path, overwrite = TRUE))
      if (httr::status_code(response) == 200) {
        downloaded <- downloaded + 1
        if (verbose) message("      Downloaded successfully")
      } else {
        if (verbose) message("      Download failed (", httr::status_code(response), ")")
        next
      }
    } else {
      if (verbose) message("    Data file exists: ", filename)
    }
    
    # Import to database if not already there
    # Standardize to lowercase for consistency (older IPEDS tables are lowercase)
    table_name <- tolower(gsub("\\.zip$", "", filename, ignore.case = TRUE))
    if (!table_exists_in_db_new(con, table_name)) {
      if (verbose) message("    Importing data table: ", table_name)
      
      if (import_data_file_new(local_path, table_name, con, verbose)) {
        imported <- imported + 1
        if (verbose) message("      Imported successfully")
      } else {
        if (verbose) message("      Import failed")
      }
    } else {
      if (verbose) message("    Data table already exists: ", table_name)
    }
  }
  
  return(list(downloaded = downloaded, imported = imported))
}

#' Process (download and import) dictionary files
process_dict_files_new <- function(dict_files, downloads_dir, con, year, force_download, verbose) {
  
  downloaded <- 0
  imported <- 0
  
  # Download dictionary files
  for (dict_url in dict_files) {
    filename <- basename(dict_url)
    local_path <- file.path(downloads_dir, filename)
    
    if (!file.exists(local_path) || force_download) {
      if (verbose) message("    Downloading dictionary: ", filename)
      
      response <- httr::GET(dict_url, httr::write_disk(local_path, overwrite = TRUE))
      if (httr::status_code(response) == 200) {
        downloaded <- downloaded + 1
        if (verbose) message("      Downloaded successfully")
      } else {
        if (verbose) message("      Download failed (", httr::status_code(response), ")")
        next
      }
    }
  }
  
  # Process dictionary files if any were available
  if (length(dict_files) > 0) {
    dict_imported <- import_year_dictionaries_new(downloads_dir, con, year, verbose)
    if (dict_imported) {
      imported <- 1
    }
  }
  
  return(list(downloaded = downloaded, imported = imported))
}

#' Helper functions for the new update system
table_exists_in_db_new <- function(con, table_name) {
  tables <- DBI::dbListTables(con)
  return(table_name %in% tables)
}

#' Extract year from IPEDS table name
#' @param table_name Name of the table
#' @return Integer year or NA if no year found
extract_year_from_table_name <- function(table_name) {
  # Common IPEDS year patterns:
  # - Full year: ADM2022, C2023_A
  # - Two-digit year range: sfa1819_p1, ef2010d
  # - Four-digit year: EFFY2022
  
  # Try to find 4-digit year (2000-2099)
  year_match <- regmatches(table_name, regexpr("20[0-9]{2}", table_name))
  if (length(year_match) > 0) {
    return(as.integer(year_match[1]))
  }
  
  # Try two-digit year patterns like "1819" or "ef19" (19 = 2019)
  # Look for patterns where two consecutive 2-digit numbers appear
  two_digit_match <- regmatches(table_name, regexpr("([0-9]{2})([0-9]{2})", table_name))
  if (length(two_digit_match) > 0) {
    # Extract the second year from range like "1819" -> 19
    year_str <- substr(two_digit_match[1], 3, 4)
    year_num <- as.integer(year_str)
    # Convert 2-digit year to 4-digit (assume 2000s)
    return(2000 + year_num)
  }
  
  # Try single two-digit year at end like "ef19"
  single_two_digit <- regmatches(table_name, regexpr("[0-9]{2}$", table_name))
  if (length(single_two_digit) > 0) {
    year_num <- as.integer(single_two_digit[1])
    # Convert 2-digit year to 4-digit (assume 2000s)
    return(2000 + year_num)
  }
  
  return(NA_integer_)
}

#' Add year column to data frame if not present
#' @param data Data frame
#' @param table_name Name of the table
#' @return Data frame with YEAR column added
add_year_column <- function(data, table_name) {
  # Check if data already has a year column (case-insensitive)
  year_cols <- grep("^year$", names(data), ignore.case = TRUE, value = TRUE)
  
  if (length(year_cols) > 0) {
    # Standardize to uppercase YEAR
    if (year_cols[1] != "YEAR") {
      names(data)[names(data) == year_cols[1]] <- "YEAR"
    }
    return(data)
  }
  
  # Extract year from table name
  year <- extract_year_from_table_name(table_name)
  
  if (!is.na(year)) {
    # Add YEAR as the second column (after UNITID if it exists)
    if ("UNITID" %in% names(data)) {
      # Insert YEAR after UNITID
      unitid_pos <- which(names(data) == "UNITID")[1]
      
      if (unitid_pos < ncol(data)) {
        # UNITID is not the last column - insert YEAR after it
        first_cols <- data[, 1:unitid_pos, drop = FALSE]
        rest_cols <- data[, (unitid_pos + 1):ncol(data), drop = FALSE]
        
        data <- cbind(
          first_cols,
          YEAR = year,
          rest_cols,
          stringsAsFactors = FALSE
        )
      } else {
        # UNITID is last column, just add YEAR at end
        data$YEAR <- year
      }
    } else {
      # No UNITID, add YEAR as first column
      data <- cbind(YEAR = year, data, stringsAsFactors = FALSE)
    }
  }
  
  return(data)
}

#' Import a data file to database
import_data_file_new <- function(file_path, table_name, con, verbose) {
  
  tryCatch({
    # Extract ZIP file
    temp_dir <- tempdir()
    extract_dir <- file.path(temp_dir, paste0("extract_", table_name))
    dir.create(extract_dir, showWarnings = FALSE)
    
    unzip(file_path, exdir = extract_dir)
    
    # Find CSV file
    csv_files <- list.files(extract_dir, pattern = "\\.csv$", full.names = TRUE, ignore.case = TRUE)
    
    if (length(csv_files) == 0) {
      if (verbose) message("        No CSV file found in ", basename(file_path))
      return(FALSE)
    }
    
    csv_file <- csv_files[1]
    
    # Read CSV with duplicate row handling and encoding issues
    data <- tryCatch({
      # First try normal read
      read.csv(csv_file, stringsAsFactors = FALSE)
    }, error = function(e) {
      if (grepl("duplicate.*row.*names", e$message, ignore.case = TRUE)) {
        if (verbose) message("        Detected duplicate row names, handling...")
        
        # Read without row names to avoid the duplicate issue
        data_no_rownames <- read.csv(csv_file, stringsAsFactors = FALSE, row.names = NULL)
        
        # Remove any duplicate rows based on all columns
        if (nrow(data_no_rownames) > 0) {
          original_rows <- nrow(data_no_rownames)
          data_no_rownames <- data_no_rownames[!duplicated(data_no_rownames), ]
          removed_rows <- original_rows - nrow(data_no_rownames)
          if (verbose && removed_rows > 0) {
            message("        Removed ", removed_rows, " duplicate rows")
          }
        }
        
        return(data_no_rownames)
      } else {
        # Try with different encoding if it's an encoding issue
        if (grepl("encoding|unicode|byte", e$message, ignore.case = TRUE)) {
          if (verbose) message("        Detected encoding issue, trying different encodings...")
          
          # Try common encodings
          for (encoding in c("UTF-8", "latin1", "CP1252")) {
            tryCatch({
              data_encoded <- read.csv(csv_file, stringsAsFactors = FALSE, 
                                     row.names = NULL, encoding = encoding)
              if (verbose) message("        Successfully read with encoding: ", encoding)
              
              # Remove duplicates if any
              if (nrow(data_encoded) > 0) {
                original_rows <- nrow(data_encoded)
                data_encoded <- data_encoded[!duplicated(data_encoded), ]
                removed_rows <- original_rows - nrow(data_encoded)
                if (verbose && removed_rows > 0) {
                  message("        Removed ", removed_rows, " duplicate rows")
                }
              }
              
              return(data_encoded)
            }, error = function(e2) {
              # Continue to next encoding
            })
          }
        }
        
        # Re-throw other errors
        stop(e)
      }
    })
    
    # Clean data and write to database with error handling
    tryCatch({
      # Clean character columns to handle Unicode issues - be aggressive upfront
      if (is.data.frame(data) && nrow(data) > 0) {
        # Find character columns
        char_cols <- sapply(data, is.character)
        if (any(char_cols)) {
          if (verbose) message("        Cleaning character data for Unicode issues...")
          for (col in names(data)[char_cols]) {
            # Use ASCII conversion to avoid Unicode issues in DuckDB
            # This is more reliable than UTF-8 for IPEDS data
            data[[col]] <- iconv(data[[col]], to = "ASCII", sub = " ")
            # Remove control characters and NULL bytes
            data[[col]] <- gsub("[\001-\010\013-\014\016-\037\177]", "", data[[col]])
            # Trim whitespace
            data[[col]] <- trimws(data[[col]])
          }
        }
        
        # Add YEAR column if not present (extract from table name)
        data <- add_year_column(data, table_name)
      }
      
      DBI::dbWriteTable(con, table_name, data, overwrite = TRUE)
    }, error = function(e) {
      if (grepl("unicode|encoding", e$message, ignore.case = TRUE)) {
        if (verbose) message("        Still getting Unicode error, applying extreme cleaning...")
        
        # Ultra-aggressive cleaning for extremely problematic data
        if (is.data.frame(data) && nrow(data) > 0) {
          for (col in names(data)) {
            if (is.character(data[[col]])) {
              # Keep only printable ASCII characters
              data[[col]] <- gsub("[^[:print:]]", " ", data[[col]])
              data[[col]] <- gsub("[^\\x20-\\x7E]", " ", data[[col]], perl = TRUE)
              # Remove extra whitespace
              data[[col]] <- trimws(gsub("\\s+", " ", data[[col]]))
            }
          }
          
          # YEAR column should already be added, but check
          if (!("YEAR" %in% names(data))) {
            data <- add_year_column(data, table_name)
          }
          
          # Try writing again
          DBI::dbWriteTable(con, table_name, data, overwrite = TRUE)
        } else {
          stop(e)
        }
      } else {
        stop(e)
      }
    })
    
    # Clean up
    unlink(extract_dir, recursive = TRUE)
    
    return(TRUE)
    
  }, error = function(e) {
    if (verbose) message("        Error importing ", table_name, ": ", e$message)
    return(FALSE)
  })
}

#' Import dictionary files for a specific year
import_year_dictionaries_new <- function(downloads_dir, con, year, verbose) {
  
  year_2digit <- sprintf("%02d", year %% 100)
  
  # Find dictionary files for this year
  dict_pattern <- paste0(".*", year_2digit, ".*[Dd]ict\\.zip$")
  dict_files <- list.files(downloads_dir, pattern = dict_pattern, full.names = TRUE)
  
  if (length(dict_files) == 0) {
    if (verbose) message("    No dictionary files found for ", year)
    return(FALSE)
  }
  
  if (verbose) message("    Processing ", length(dict_files), " dictionary files...")
  
  # Collect data for each type
  all_vartable_data <- list()
  all_valuesets_data <- list()
  
  for (dict_file in dict_files) {
    if (verbose) message("      Processing: ", basename(dict_file))
    
    # Extract and process Excel workbook
    data <- process_dict_zip_new(dict_file, verbose)
    
    if (!is.null(data)) {
      file_prefix <- gsub("_?[Dd]ict\\.zip$", "", basename(dict_file))
      
      if (!is.null(data$vartable)) {
        data$vartable$source_file <- file_prefix
        all_vartable_data[[file_prefix]] <- data$vartable
      }
      if (!is.null(data$valuesets)) {
        data$valuesets$source_file <- file_prefix  
        all_valuesets_data[[file_prefix]] <- data$valuesets
      }
    }
  }
  
  # Create yearly dictionary tables (lowercase to match standardization)
  tables_name <- paste0("tables", year_2digit)
  vartable_name <- paste0("vartable", year_2digit)
  valuesets_name <- paste0("valuesets", year_2digit)
  
  # Create Tables table
  if (!table_exists_in_db_new(con, tables_name)) {
    create_tables_for_year_new(con, year, tables_name, verbose)
  }
  
  # Create vartable table
  if (length(all_vartable_data) > 0 && !table_exists_in_db_new(con, vartable_name)) {
    combined_vartable <- do.call(rbind, all_vartable_data)
    DBI::dbWriteTable(con, vartable_name, combined_vartable, overwrite = TRUE)
    if (verbose) message("      Created ", vartable_name, " with ", nrow(combined_vartable), " rows")
  }
  
  # Create valuesets table  
  if (length(all_valuesets_data) > 0 && !table_exists_in_db_new(con, valuesets_name)) {
    combined_valuesets <- do.call(rbind, all_valuesets_data)
    DBI::dbWriteTable(con, valuesets_name, combined_valuesets, overwrite = TRUE)
    if (verbose) message("      Created ", valuesets_name, " with ", nrow(combined_valuesets), " rows")
  }
  
  return(TRUE)
}

#' Process dictionary ZIP file  
process_dict_zip_new <- function(zip_path, verbose = FALSE) {
  if (!file.exists(zip_path)) return(NULL)
  
  # Extract ZIP file
  temp_dir <- tempdir()
  extract_dir <- file.path(temp_dir, gsub("\\.zip$", "", basename(zip_path)))
  dir.create(extract_dir, recursive = TRUE, showWarnings = FALSE)
  
  unzip(zip_path, exdir = extract_dir)
  
  # Find Excel file
  excel_files <- list.files(extract_dir, pattern = "\\.xlsx$", full.names = TRUE)
  if (length(excel_files) == 0) return(NULL)
  
  excel_file <- excel_files[1]
  sheet_names <- readxl::excel_sheets(excel_file)
  
  result <- list()
  
  # Look for Varlist worksheet (maps to vartable)
  if ("Varlist" %in% sheet_names) {
    result$vartable <- readxl::read_excel(excel_file, sheet = "Varlist")
  }
  
  # Look for Description worksheet (maps to valuesets)  
  if ("Description" %in% sheet_names) {
    result$valuesets <- readxl::read_excel(excel_file, sheet = "Description")
  } else if ("Frequencies" %in% sheet_names) {
    result$valuesets <- readxl::read_excel(excel_file, sheet = "Frequencies")
  }
  
  # Clean up
  unlink(extract_dir, recursive = TRUE)
  
  return(result)
}

#' Create Tables table for a specific year
create_tables_for_year_new <- function(con, year, table_name, verbose) {
  
  # Get list of data tables for this year
  year_2digit <- sprintf("%02d", year %% 100)
  all_tables <- DBI::dbListTables(con)
  data_tables <- grep(paste0(".*", year_2digit, "$"), all_tables, value = TRUE)
  # Exclude metadata tables (case-insensitive since we now use lowercase)
  data_tables <- setdiff(data_tables, c(paste0("tables", year_2digit),
                                       paste0("Tables", year_2digit),  # legacy uppercase
                                       paste0("vartable", year_2digit),
                                       paste0("valuesets", year_2digit)))
  
  if (length(data_tables) == 0) {
    if (verbose) message("      No data tables found for ", year, " to catalog")
    return(FALSE)
  }
  
  # Create Tables data
  tables_data <- data.frame(
    SurveyOrder = seq_along(data_tables),
    SurveyNumber = 1,
    Survey = "IPEDS Survey",
    YearCoverage = paste("Academic year", year, "-", sprintf("%02d", (year + 1) %% 100)),
    TableName = data_tables,
    Tablenumber = seq_along(data_tables),
    TableTitle = paste("Data table", data_tables),
    Release = "Provisional",
    "Release date" = paste("Generated", Sys.Date()),
    F11 = NA, F12 = NA, F13 = NA, F14 = NA, F15 = NA, F16 = NA,
    Description = paste("Data table", data_tables, "for year", year),
    stringsAsFactors = FALSE,
    check.names = FALSE
  )
  
  DBI::dbWriteTable(con, table_name, tables_data, overwrite = TRUE)
  if (verbose) message("      Created ", table_name, " with ", nrow(tables_data), " tables cataloged")
  
  return(TRUE)
}

#' Update the consolidated dictionary tables with new year data
update_consolidated_dictionaries_new <- function(con, verbose) {
  
  if (verbose) message("  Regenerating consolidated dictionary tables...")
  
  # Get all Tables, vartable, and valuesets tables
  all_tables <- DBI::dbListTables(con)
  
  # Use case-insensitive search since we now standardize to lowercase
  tables_tables <- grep('^tables[0-9]{2}$', all_tables, value = TRUE, ignore.case = TRUE)
  vartable_tables <- grep('^vartable[0-9]{2}$', all_tables, value = TRUE, ignore.case = TRUE)
  valuesets_tables <- grep('^valuesets[0-9]{2}$', all_tables, value = TRUE, ignore.case = TRUE)
  
  # Recreate tables_all (lowercase to match standardization)
  if (length(tables_tables) > 0) {
    if (verbose) message("    Updating tables_all...")
    
    tables_queries <- c()
    for (table in tables_tables) {
      year <- gsub("tables", "", table, ignore.case = TRUE)
      year_4digit <- ifelse(as.numeric(year) <= 50, 2000 + as.numeric(year), 1900 + as.numeric(year))
      
      # Get actual column names for this table
      cols <- DBI::dbListFields(con, table)
      cols_lower <- tolower(cols)
      
      # Check which optional columns exist
      has_release_date <- any(grepl("^release.?date$", cols, ignore.case = TRUE))
      has_f_cols <- any(grepl("^f[0-9]{2}$", cols, ignore.case = TRUE))
      
      # Build SELECT clause based on available columns
      # Core columns (should always exist)
      select_parts <- c(
        "SurveyOrder", "SurveyNumber", "Survey", "YearCoverage",
        "TableName", "Tablenumber", "TableTitle", "Release"
      )
      
      # Add "Release date" if it exists, otherwise NULL
      if (has_release_date) {
        # Find exact column name (might be "Release date", "ReleaseDate", etc.)
        release_date_col <- cols[grepl("^release.?date$", cols, ignore.case = TRUE)][1]
        select_parts <- c(select_parts, sprintf('"%s"', release_date_col))
      } else {
        select_parts <- c(select_parts, "NULL as \"Release date\"")
      }
      
      # Add F11-F16 if they exist, otherwise NULL
      if (has_f_cols) {
        select_parts <- c(select_parts, "F11", "F12", "F13", "F14", "F15", "F16")
      } else {
        select_parts <- c(select_parts, 
                         "NULL as F11", "NULL as F12", "NULL as F13", 
                         "NULL as F14", "NULL as F15", "NULL as F16")
      }
      
      # Add Description and YEAR
      select_parts <- c(select_parts, "Description", sprintf("%d as YEAR", year_4digit))
      
      # Build query
      query <- sprintf('SELECT %s FROM %s', 
                      paste(select_parts, collapse = ", "), 
                      table)
      
      tables_queries <- c(tables_queries, query)
    }
    
    union_query <- paste(tables_queries, collapse=" UNION ALL ")
    DBI::dbExecute(con, sprintf("CREATE OR REPLACE TABLE tables_all AS %s", union_query))
    
    if (verbose) message("      tables_all updated")
  }
  
  # Recreate vartable_all (lowercase to match standardization)
  if (length(vartable_tables) > 0) {
    if (verbose) message("    Updating vartable_all...")
    
    # First pass: collect all unique column names across all vartable tables
    all_vartable_columns <- list()
    for (table in vartable_tables) {
      all_vartable_columns[[table]] <- DBI::dbListFields(con, table)
    }
    all_unique_vartable_cols <- unique(unlist(all_vartable_columns))
    
    # Second pass: build queries with NULL placeholders for missing columns
    vartable_queries <- c()
    for (table in vartable_tables) {
      year <- gsub("vartable", "", table, ignore.case = TRUE)
      year_4digit <- ifelse(as.numeric(year) <= 50, 2000 + as.numeric(year), 1900 + as.numeric(year))
      
      cols <- all_vartable_columns[[table]]
      
      # Build SELECT list with all columns, using NULL where missing
      select_parts <- c()
      for (col in all_unique_vartable_cols) {
        if (col %in% cols) {
          select_parts <- c(select_parts, col)
        } else {
          select_parts <- c(select_parts, sprintf("NULL as %s", col))
        }
      }
      select_parts <- c(select_parts, sprintf("%d as YEAR", year_4digit))
      
      query <- sprintf('SELECT %s FROM %s', paste(select_parts, collapse=", "), table)
      vartable_queries <- c(vartable_queries, query)
    }
    
    union_query <- paste(vartable_queries, collapse=" UNION ALL ")
    DBI::dbExecute(con, sprintf("CREATE OR REPLACE TABLE vartable_all AS %s", union_query))
    
    if (verbose) message("      vartable_all updated")
  }
  
  # Recreate valuesets_all (lowercase to match standardization)
  if (length(valuesets_tables) > 0) {
    if (verbose) message("    Updating valuesets_all...")
    
    # First pass: collect all unique column names across all valuesets tables
    all_valuesets_columns <- list()
    for (table in valuesets_tables) {
      all_valuesets_columns[[table]] <- DBI::dbListFields(con, table)
    }
    all_unique_valuesets_cols <- unique(unlist(all_valuesets_columns))
    
    # Second pass: build queries with NULL placeholders for missing columns
    valuesets_queries <- c()
    for (table in valuesets_tables) {
      year <- gsub("valuesets", "", table, ignore.case = TRUE)
      year_4digit <- ifelse(as.numeric(year) <= 50, 2000 + as.numeric(year), 1900 + as.numeric(year))
      
      cols <- all_valuesets_columns[[table]]
      
      # Build SELECT list with all columns, using NULL where missing
      select_parts <- c()
      for (col in all_unique_valuesets_cols) {
        if (col %in% cols) {
          select_parts <- c(select_parts, col)
        } else {
          select_parts <- c(select_parts, sprintf("NULL as %s", col))
        }
      }
      select_parts <- c(select_parts, sprintf("%d as YEAR", year_4digit))
      
      query <- sprintf('SELECT %s FROM %s', paste(select_parts, collapse=", "), table)
      valuesets_queries <- c(valuesets_queries, query)
    }
    
    union_query <- paste(valuesets_queries, collapse=" UNION ALL ")
    DBI::dbExecute(con, sprintf("CREATE OR REPLACE TABLE valuesets_all AS %s", union_query))
    
    if (verbose) message("      valuesets_all updated")
  }
  
  if (verbose) message("    Consolidated dictionary tables updated successfully")
}

#' Backup current database
#' @param backup_dir Directory to store backup, defaults to user data dir
#' @return Path to backup file
backup_database <- function(backup_dir = NULL) {
  
  if (is.null(backup_dir)) {
    backup_dir <- file.path(rappdirs::user_data_dir("IPEDSR"), "backups")
  }
  
  if (!dir.exists(backup_dir)) {
    dir.create(backup_dir, recursive = TRUE)
  }
  
  # Create timestamped backup filename
  timestamp <- format(Sys.time(), "%Y%m%d_%H%M%S")
  backup_filename <- paste0("ipeds_backup_", timestamp, ".duckdb")
  backup_path <- file.path(backup_dir, backup_filename)
  
  # Copy current database
  current_db_path <- get_ipeds_db_path()
  if (file.exists(current_db_path)) {
    file.copy(current_db_path, backup_path)
    message("Database backed up to: ", backup_path)
    return(backup_path)
  } else {
    warning("No current database found to backup")
    return(NULL)
  }
}

#' List available database backups
#' @param backup_dir Directory containing backups
#' @return Data frame with backup information
#' @export
list_database_backups <- function(backup_dir = NULL) {
  
  if (is.null(backup_dir)) {
    backup_dir <- file.path(rappdirs::user_data_dir("IPEDSR"), "backups")
  }
  
  if (!dir.exists(backup_dir)) {
    return(data.frame(
      filename = character(0),
      path = character(0),
      size_mb = numeric(0),
      created = character(0),
      stringsAsFactors = FALSE
    ))
  }
  
  backup_files <- list.files(backup_dir, pattern = "^ipeds_backup_.*\\.duckdb$", 
                            full.names = TRUE)
  
  if (length(backup_files) == 0) {
    return(data.frame(
      filename = character(0),
      path = character(0), 
      size_mb = numeric(0),
      created = character(0),
      stringsAsFactors = FALSE
    ))
  }
  
  file_info <- file.info(backup_files)
  
  data.frame(
    filename = basename(backup_files),
    path = backup_files,
    size_mb = round(file_info$size / 1024 / 1024, 2),
    created = as.character(file_info$mtime),
    stringsAsFactors = FALSE
  )
}

#' Restore database from backup
#' @param backup_path Path to backup file to restore
#' @param confirm Whether to require confirmation before restoring
#' @export
restore_database_backup <- function(backup_path, confirm = TRUE) {
  
  if (!file.exists(backup_path)) {
    stop("Backup file not found: ", backup_path)
  }
  
  if (confirm) {
    response <- readline(paste0("This will replace your current database with the backup from ",
                               basename(backup_path), ". Continue? (yes/no): "))
    if (tolower(response) != "yes") {
      message("Restore cancelled.")
      return(invisible(FALSE))
    }
  }
  
  # Close any existing connections
  disconnect_ipeds()
  
  # Replace current database with backup
  current_db_path <- get_ipeds_db_path()
  file.copy(backup_path, current_db_path, overwrite = TRUE)
  
  message("Database restored from backup: ", basename(backup_path))
  return(invisible(TRUE))
}

#' Add YEAR columns to existing database tables
#' 
#' This function scans all tables in the database and adds a YEAR column
#' where one is missing, extracting the year from the table name.
#' Useful for upgrading existing databases to have consistent YEAR columns.
#' 
#' @param tables Optional vector of specific table names to update. If NULL, updates all tables.
#' @param verbose Whether to print progress messages
#' @return Invisibly returns a list with counts of tables processed, updated, and skipped
#' @export
#' @examples
#' \dontrun{
#' # Add YEAR columns to all tables
#' add_year_columns_to_database()
#' 
#' # Add YEAR columns to specific tables
#' add_year_columns_to_database(tables = c("ADM2022", "ADM2023"))
#' }
add_year_columns_to_database <- function(tables = NULL, verbose = TRUE) {
  
  con <- ensure_connection()
  
  # Get list of tables to process
  if (is.null(tables)) {
    all_tables <- DBI::dbListTables(con)
    # Exclude metadata tables (case-insensitive since we now use lowercase)
    tables <- all_tables[!grepl("^(ipeds_|sqlite_|tables|vartable|valuesets)", all_tables, ignore.case = TRUE)]
  }
  
  if (verbose) {
    message("Checking ", length(tables), " tables for YEAR columns...")
  }
  
  updated <- 0
  skipped <- 0
  errors <- 0
  
  for (i in seq_along(tables)) {
    table_name <- tables[i]
    
    if (verbose && (i == 1 || i == length(tables) || i %% 50 == 0)) {
      message("Processing table ", i, "/", length(tables), ": ", table_name)
    }
    
    tryCatch({
      # Check if table already has a YEAR column
      schema_query <- paste("PRAGMA table_info(", table_name, ")")
      schema <- DBI::dbGetQuery(con, schema_query)
      year_cols <- grep("^year$", schema$name, ignore.case = TRUE, value = TRUE)
      
      if (length(year_cols) > 0) {
        # Already has YEAR column
        skipped <- skipped + 1
        next
      }
      
      # Extract year from table name
      year <- extract_year_from_table_name(table_name)
      
      if (is.na(year)) {
        # No year found in table name
        skipped <- skipped + 1
        next
      }
      
      # Add YEAR column - read table, add column, write back
      # (DuckDB doesn't support ALTER TABLE ADD COLUMN at specific position)
      data <- DBI::dbReadTable(con, table_name)
      
      # Skip empty tables
      if (nrow(data) == 0) {
        if (verbose) {
          message("  Skipping empty table: ", table_name)
        }
        skipped <- skipped + 1
        next
      }
      
      # Check if we should add after UNITID or at the beginning
      has_unitid <- "UNITID" %in% names(data)
      
      if (has_unitid) {
        # Insert YEAR after UNITID
        unitid_pos <- which(names(data) == "UNITID")[1]
        
        if (unitid_pos < ncol(data)) {
          # Insert YEAR column after UNITID - preserve column names properly
          first_cols <- data[, 1:unitid_pos, drop = FALSE]
          rest_cols <- data[, (unitid_pos + 1):ncol(data), drop = FALSE]
          
          data <- cbind(
            first_cols,
            YEAR = year,
            rest_cols,
            stringsAsFactors = FALSE
          )
        } else {
          # UNITID is last column, just add YEAR at end
          data$YEAR <- year
        }
      } else {
        # No UNITID, add YEAR as first column
        data <- cbind(YEAR = year, data, stringsAsFactors = FALSE)
      }
      
      DBI::dbWriteTable(con, table_name, data, overwrite = TRUE)
      
      updated <- updated + 1
      
    }, error = function(e) {
      if (verbose) {
        message("  Error processing ", table_name, ": ", e$message)
      }
      errors <<- errors + 1  # Use <<- to assign to parent scope
    })
  }
  
  if (verbose) {
    message("\nYEAR column addition complete:")
    message("  Tables updated: ", updated)
    message("  Tables skipped: ", skipped, " (already have YEAR or no year in name)")
    message("  Errors: ", errors)
  }
  
  invisible(list(
    total = length(tables),
    updated = updated,
    skipped = skipped,
    errors = errors
  ))
}

#' Convert YEAR columns from DOUBLE to INTEGER type
#'
#' This function scans all tables in the IPEDS database and converts any YEAR
#' columns that are stored as DOUBLE to INTEGER type. This is a cosmetic fix
#' that makes the data types semantically correct (years should be integers)
#' and eliminates validation warnings.
#'
#' @param tables Character vector of table names to process. If NULL (default),
#'   processes all tables in the database.
#' @param verbose Logical indicating whether to print progress messages.
#'   Default is TRUE.
#'
#' @return Invisibly returns a list with components:
#'   \item{total}{Total number of tables checked}
#'   \item{converted}{Number of tables where YEAR was converted to INTEGER}
#'   \item{already_integer}{Number of tables where YEAR was already INTEGER}
#'   \item{no_year}{Number of tables without a YEAR column}
#'   \item{errors}{Number of tables that encountered errors}
#'
#' @details
#' The function uses DuckDB's ALTER TABLE to change the column type in place,
#' which is efficient and doesn't require rewriting the entire table. The
#' conversion is safe because:
#' \itemize{
#'   \item Years are always whole numbers (2019, 2020, etc.)
#'   \item No precision is lost when converting DOUBLE to INTEGER
#'   \item The operation is idempotent (can be run multiple times safely)
#' }
#'
#' Before running this function on a production database, it's recommended
#' to create a backup using \code{ipeds_data_manager("backup")}.
#'
#' @examples
#' \dontrun{
#' # Convert YEAR to INTEGER in all tables
#' convert_year_to_integer()
#'
#' # Convert only specific tables
#' convert_year_to_integer(tables = c("ADM2022", "ADM2023"))
#'
#' # Run without progress messages
#' convert_year_to_integer(verbose = FALSE)
#' }
#'
#' @export
convert_year_to_integer <- function(tables = NULL, verbose = TRUE) {
  
  con <- ensure_connection()
  
  # Get list of tables to process
  if (is.null(tables)) {
    tables <- DBI::dbListTables(con)
  }
  
  if (verbose) {
    message("Checking ", length(tables), " tables for YEAR column type...")
  }
  
  converted <- 0
  already_integer <- 0
  no_year <- 0
  errors <- 0
  
  for (i in seq_along(tables)) {
    table_name <- tables[i]
    
    if (verbose && (i == 1 || i == length(tables) || i %% 50 == 0)) {
      message("Processing table ", i, "/", length(tables), ": ", table_name)
    }
    
    tryCatch({
      # Check table schema
      schema_query <- paste("PRAGMA table_info(", table_name, ")")
      schema <- DBI::dbGetQuery(con, schema_query)
      
      # Find YEAR column (case-insensitive)
      year_idx <- grep("^year$", schema$name, ignore.case = TRUE)
      
      if (length(year_idx) == 0) {
        # No YEAR column in this table
        no_year <- no_year + 1
        next
      }
      
      year_col_info <- schema[year_idx[1], ]
      current_type <- toupper(year_col_info$type)
      
      if (current_type == "INTEGER") {
        # Already INTEGER, nothing to do
        already_integer <- already_integer + 1
        next
      }
      
      if (current_type == "DOUBLE" || current_type == "REAL" || 
          current_type == "FLOAT" || current_type == "NUMERIC") {
        # Need to convert to INTEGER
        
        # DuckDB ALTER TABLE syntax to change column type
        alter_query <- sprintf(
          "ALTER TABLE %s ALTER COLUMN YEAR TYPE INTEGER",
          table_name
        )
        
        DBI::dbExecute(con, alter_query)
        
        converted <- converted + 1
        
        if (verbose && converted <= 5) {
          message("  ✓ Converted ", table_name, ": ", current_type, " → INTEGER")
        }
      } else {
        # Unexpected type
        if (verbose) {
          message("  ⚠ Unexpected YEAR type in ", table_name, ": ", current_type)
        }
      }
      
    }, error = function(e) {
      if (verbose) {
        message("  Error processing ", table_name, ": ", e$message)
      }
      errors <<- errors + 1
    })
  }
  
  if (verbose) {
    message("\nYEAR column type conversion complete:")
    message("  Tables converted (DOUBLE → INTEGER): ", converted)
    message("  Tables already INTEGER: ", already_integer)
    message("  Tables without YEAR column: ", no_year)
    message("  Errors: ", errors)
  }
  
  invisible(list(
    total = length(tables),
    converted = converted,
    already_integer = already_integer,
    no_year = no_year,
    errors = errors
  ))
}

#' Standardize table names to lowercase
#'
#' This function renames all uppercase or mixed-case table names to lowercase
#' to maintain consistency across the database. Historically, IPEDS tables
#' used lowercase names, but recent years have used uppercase. This function
#' standardizes everything to lowercase.
#'
#' @param tables Character vector of table names to process. If NULL (default),
#'   processes all tables in the database that contain uppercase letters.
#' @param verbose Logical indicating whether to print progress messages.
#'   Default is TRUE.
#'
#' @return Invisibly returns a list with components:
#'   \item{total}{Total number of tables checked}
#'   \item{renamed}{Number of tables that were renamed to lowercase}
#'   \item{already_lowercase}{Number of tables already in lowercase}
#'   \item{errors}{Number of tables that encountered errors}
#'
#' @details
#' The function uses DuckDB's table renaming to change table names in place.
#' This is safe and efficient. The operation is idempotent (can be run multiple
#' times safely) as it only processes tables that contain uppercase letters.
#'
#' Common tables that will be affected:
#' \itemize{
#'   \item HD2023, HD2024 → hd2023, hd2024
#'   \item IC2023_* tables → ic2023_* tables
#'   \item Any recently imported tables with uppercase letters
#' }
#'
#' Before running this function on a production database, it's recommended
#' to create a backup using \code{ipeds_data_manager("backup")}.
#'
#' @examples
#' \dontrun{
#' # Standardize all table names to lowercase
#' standardize_table_names_to_lowercase()
#'
#' # Standardize only specific tables
#' standardize_table_names_to_lowercase(tables = c("HD2023", "HD2024"))
#'
#' # Run without progress messages
#' standardize_table_names_to_lowercase(verbose = FALSE)
#' }
#'
#' @export
standardize_table_names_to_lowercase <- function(tables = NULL, verbose = TRUE) {
  
  con <- ensure_connection()
  
  # Get list of tables to process
  if (is.null(tables)) {
    all_tables <- DBI::dbListTables(con)
    # Only process tables that have uppercase letters
    tables <- all_tables[grepl("[A-Z]", all_tables)]
  }
  
  if (length(tables) == 0) {
    if (verbose) {
      message("No tables with uppercase letters found. Database already standardized!")
    }
    return(invisible(list(
      total = 0,
      renamed = 0,
      already_lowercase = 0,
      errors = 0
    )))
  }
  
  if (verbose) {
    message("Standardizing ", length(tables), " table names to lowercase...")
  }
  
  renamed <- 0
  already_lowercase <- 0
  errors <- 0
  
  for (i in seq_along(tables)) {
    table_name <- tables[i]
    
    if (verbose && (i == 1 || i == length(tables) || i %% 25 == 0)) {
      message("Processing table ", i, "/", length(tables), ": ", table_name)
    }
    
    tryCatch({
      # Check if table name has any uppercase letters
      if (!grepl("[A-Z]", table_name)) {
        already_lowercase <- already_lowercase + 1
        next
      }
      
      # Generate lowercase name
      new_name <- tolower(table_name)
      
      # Check if a table with the lowercase name already exists
      all_current_tables <- DBI::dbListTables(con)
      if (new_name %in% all_current_tables && new_name != table_name) {
        if (verbose) {
          message("  ⚠ Cannot rename ", table_name, " → ", new_name, 
                  " (target already exists)")
        }
        errors <- errors + 1
        next
      }
      
      # Rename the table
      rename_query <- sprintf(
        "ALTER TABLE %s RENAME TO %s",
        table_name,
        new_name
      )
      
      DBI::dbExecute(con, rename_query)
      
      renamed <- renamed + 1
      
      if (verbose && renamed <= 10) {
        message("  ✓ Renamed: ", table_name, " → ", new_name)
      }
      
    }, error = function(e) {
      if (verbose) {
        message("  Error renaming ", table_name, ": ", e$message)
      }
      errors <<- errors + 1
    })
  }
  
  if (verbose) {
    message("\nTable name standardization complete:")
    message("  Tables renamed to lowercase: ", renamed)
    message("  Tables already lowercase: ", already_lowercase)
    message("  Errors: ", errors)
    
    if (renamed > 0) {
      message("\n✓ Database now uses consistent lowercase table names!")
      message("  Functions like get_characteristics() should now work correctly.")
    }
  }
  
  invisible(list(
    total = length(tables),
    renamed = renamed,
    already_lowercase = already_lowercase,
    errors = errors
  ))
}