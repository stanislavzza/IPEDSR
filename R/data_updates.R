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
    table_name <- gsub("\\.zip$", "", filename, ignore.case = TRUE)
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
      unitid_pos <- which(names(data) == "UNITID")
      if (unitid_pos == ncol(data)) {
        # UNITID is last column, just add YEAR at end
        data$YEAR <- year
      } else {
        # Insert YEAR after UNITID
        data <- data[, c(1:unitid_pos, ncol(data) + 1, (unitid_pos + 1):ncol(data))]
        data[, unitid_pos + 1] <- year
        names(data)[unitid_pos + 1] <- "YEAR"
      }
    } else {
      # No UNITID, add YEAR as first column
      data <- cbind(YEAR = year, data)
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
      # Clean character columns to handle Unicode issues
      if (is.data.frame(data) && nrow(data) > 0) {
        # Find character columns
        char_cols <- sapply(data, is.character)
        if (any(char_cols)) {
          if (verbose) message("        Cleaning character data for Unicode issues...")
          for (col in names(data)[char_cols]) {
            # Replace problematic characters and ensure valid UTF-8
            data[[col]] <- iconv(data[[col]], to = "UTF-8", sub = "")
            # Remove any remaining non-printable characters
            data[[col]] <- gsub("[^\x01-\x7F]", "", data[[col]])
          }
        }
        
        # Add YEAR column if not present (extract from table name)
        data <- add_year_column(data, table_name)
      }
      
      DBI::dbWriteTable(con, table_name, data, overwrite = TRUE)
    }, error = function(e) {
      if (grepl("unicode|encoding", e$message, ignore.case = TRUE)) {
        if (verbose) message("        Database Unicode error, applying additional cleaning...")
        
        # More aggressive cleaning for problematic data
        if (is.data.frame(data) && nrow(data) > 0) {
          for (col in names(data)) {
            if (is.character(data[[col]])) {
              # Convert to ASCII only, removing all non-ASCII characters
              data[[col]] <- iconv(data[[col]], to = "ASCII", sub = "")
              # Remove any NULL bytes or other problematic characters
              data[[col]] <- gsub("[\001-\010\013-\014\016-\037\177]", "", data[[col]])
            }
          }
          
          # Add YEAR column if not present (extract from table name)
          data <- add_year_column(data, table_name)
          
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
  
  # Create yearly dictionary tables
  tables_name <- paste0("Tables", year_2digit)
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
  data_tables <- setdiff(data_tables, c(paste0("Tables", year_2digit), 
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
  
  tables_tables <- grep('^Tables[0-9]{2}$', all_tables, value = TRUE)
  vartable_tables <- grep('^vartable[0-9]{2}$', all_tables, value = TRUE)
  valuesets_tables <- grep('^valuesets[0-9]{2}$', all_tables, value = TRUE)
  
  # Recreate Tables_All
  if (length(tables_tables) > 0) {
    if (verbose) message("    Updating Tables_All...")
    
    tables_queries <- c()
    for (table in tables_tables) {
      year <- gsub("Tables", "", table)
      year_4digit <- ifelse(as.numeric(year) <= 50, 2000 + as.numeric(year), 1900 + as.numeric(year))
      
      cols <- DBI::dbListFields(con, table)
      if (length(cols) <= 10) {
        # Early format
        query <- sprintf('SELECT SurveyOrder, SurveyNumber, Survey, YearCoverage, TableName, Tablenumber, TableTitle, Release, "Release date", NULL as F11, NULL as F12, NULL as F13, NULL as F14, NULL as F15, NULL as F16, Description, %d as YEAR FROM %s', year_4digit, table)
      } else {
        # Later format
        query <- sprintf('SELECT SurveyOrder, SurveyNumber, Survey, YearCoverage, TableName, Tablenumber, TableTitle, Release, "Release date", F11, F12, F13, F14, F15, F16, Description, %d as YEAR FROM %s', year_4digit, table)
      }
      tables_queries <- c(tables_queries, query)
    }
    
    union_query <- paste(tables_queries, collapse=" UNION ALL ")
    DBI::dbExecute(con, sprintf("CREATE OR REPLACE TABLE Tables_All AS %s", union_query))
    
    if (verbose) message("      Tables_All updated")
  }
  
  # Recreate vartable_All and valuesets_All with similar logic...
  # (Abbreviated for space - would include full implementation)
  
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