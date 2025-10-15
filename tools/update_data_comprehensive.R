# Comprehensive IPEDS Data Update System
# This replaces and enhances the update functionality in data_updates.R

library(DBI)
library(httr)
library(readxl)
library(dplyr)
source("R/database_management.R")

#' String repetition helper function
repeat_string <- function(string, times) {
  paste(rep(string, times), collapse = "")
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
    message(repeat_string("=", 60))
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
      message(repeat_string("-", 40))
    }
    
    year_result <- process_year_data(year, downloads_dir, con, force_download, verbose)
    update_summary <- rbind(update_summary, year_result)
  }
  
  # Update consolidated dictionary tables
  if (verbose) {
    message("\nUpdating consolidated dictionary tables...")
  }
  update_consolidated_dictionaries(con, verbose)
  
  dbDisconnect(con)
  
  if (verbose) {
    message("\n", repeat_string("=", 60))
    message("UPDATE COMPLETE!")
    message(repeat_string("=", 60))
    print(update_summary)
  }
  
  return(update_summary)
}

#' Process data and dictionary files for a single year
#' @param year 4-digit year integer
#' @param downloads_dir Path to downloads directory
#' @param con Database connection
#' @param force_download Whether to re-download existing files
#' @param verbose Whether to print progress
#' @return Data frame with results for this year
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
    
    response <- GET(ipeds_url)
    if (status_code(response) != 200) {
      result$errors <- paste("Failed to access IPEDS page for", year)
      return(result)
    }
    
    content <- content(response, as = "text", encoding = "UTF-8")
    
    # 2. Extract data and dictionary file links
    data_files <- extract_data_files(content, year_2digit)
    dict_files <- extract_dict_files(content, year_2digit)
    
    result$data_files_found <- length(data_files)
    result$dict_files_found <- length(dict_files)
    
    if (verbose) {
      message("    Found ", length(data_files), " data files and ", length(dict_files), " dictionary files")
    }
    
    # 3. Download and import data files
    if (length(data_files) > 0) {
      data_results <- process_data_files(data_files, downloads_dir, con, force_download, verbose)
      result$data_files_downloaded <- data_results$downloaded
      result$data_files_imported <- data_results$imported
    }
    
    # 4. Download and import dictionary files  
    if (length(dict_files) > 0) {
      dict_results <- process_dict_files(dict_files, downloads_dir, con, year, force_download, verbose)
      result$dict_files_downloaded <- dict_results$downloaded
      result$dict_files_imported <- dict_results$imported
    }
    
  }, error = function(e) {
    result$errors <<- e$message
    if (verbose) message("    ERROR: ", e$message)
  })
  
  return(result)
}

#' Extract data file information from IPEDS HTML content
#' @param html_content HTML content from IPEDS page
#' @param year_2digit 2-digit year string (e.g., "24")
#' @return List of data file information
extract_data_files <- function(html_content, year_2digit) {
  
  # Pattern to find ZIP file links for data (not dictionaries)
  # Look for hrefs that end with .zip but don't contain "Dict"
  zip_pattern <- paste0('href="([^"]*', year_2digit, '[^"]*\\.zip)"')
  
  matches <- gregexpr(zip_pattern, html_content, ignore.case = TRUE)
  zip_links <- regmatches(html_content, matches)[[1]]
  
  if (length(zip_links) == 0) {
    return(character(0))
  }
  
  # Extract just the URLs
  urls <- gsub('href="([^"]*)"', '\\1', zip_links)
  
  # Filter out dictionary files
  data_urls <- urls[!grepl("_?[Dd]ict\\.zip", urls)]
  
  # Construct full URLs
  base_url <- "https://nces.ed.gov/ipeds/datacenter/data/"
  full_urls <- ifelse(grepl("^http", data_urls), data_urls, paste0(base_url, basename(data_urls)))
  
  return(full_urls)
}

#' Extract dictionary file information from IPEDS HTML content  
#' @param html_content HTML content from IPEDS page
#' @param year_2digit 2-digit year string (e.g., "24")
#' @return List of dictionary file information
extract_dict_files <- function(html_content, year_2digit) {
  
  # Pattern to find dictionary ZIP files
  dict_pattern <- 'href="([^"]*_?[Dd]ict\\.zip)"'
  
  matches <- gregexpr(dict_pattern, html_content, ignore.case = TRUE)
  dict_links <- regmatches(html_content, matches)[[1]]
  
  if (length(dict_links) == 0) {
    return(character(0))
  }
  
  # Extract just the URLs
  urls <- gsub('href="([^"]*)"', '\\1', dict_links)
  
  # Construct full URLs
  base_url <- "https://nces.ed.gov/ipeds/datacenter/data/"
  full_urls <- ifelse(grepl("^http", urls), urls, paste0(base_url, basename(urls)))
  
  return(full_urls)
}

#' Process (download and import) data files
#' @param data_files Vector of data file URLs
#' @param downloads_dir Downloads directory path
#' @param con Database connection
#' @param force_download Whether to re-download existing files
#' @param verbose Whether to print progress
#' @return List with download and import counts
process_data_files <- function(data_files, downloads_dir, con, force_download, verbose) {
  
  downloaded <- 0
  imported <- 0
  
  for (data_url in data_files) {
    filename <- basename(data_url)
    local_path <- file.path(downloads_dir, filename)
    
    # Download if needed
    if (!file.exists(local_path) || force_download) {
      if (verbose) message("    Downloading data file: ", filename)
      
      response <- GET(data_url, write_disk(local_path, overwrite = TRUE))
      if (status_code(response) == 200) {
        downloaded <- downloaded + 1
        if (verbose) message("      Downloaded successfully")
      } else {
        if (verbose) message("      Download failed (", status_code(response), ")")
        next
      }
    } else {
      if (verbose) message("    Data file exists: ", filename)
    }
    
    # Import to database if not already there
    table_name <- extract_table_name_from_filename(filename)
    if (!is.null(table_name) && !table_exists_in_db(con, table_name)) {
      if (verbose) message("    Importing data table: ", table_name)
      
      if (import_data_file(local_path, table_name, con, verbose)) {
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
#' @param dict_files Vector of dictionary file URLs  
#' @param downloads_dir Downloads directory path
#' @param con Database connection
#' @param year 4-digit year
#' @param force_download Whether to re-download existing files
#' @param verbose Whether to print progress
#' @return List with download and import counts
process_dict_files <- function(dict_files, downloads_dir, con, year, force_download, verbose) {
  
  downloaded <- 0
  imported <- 0
  
  # Dictionary table names for this year
  year_2digit <- sprintf("%02d", year %% 100)
  tables_name <- paste0("Tables", year_2digit)
  vartable_name <- paste0("vartable", year_2digit)  
  valuesets_name <- paste0("valuesets", year_2digit)
  
  # Check if dictionary tables already exist
  dict_tables_exist <- all(c(
    table_exists_in_db(con, tables_name),
    table_exists_in_db(con, vartable_name),
    table_exists_in_db(con, valuesets_name)
  ))
  
  if (dict_tables_exist && !force_download) {
    if (verbose) message("    Dictionary tables already exist for ", year)
    return(list(downloaded = 0, imported = 0))
  }
  
  # Download dictionary files
  for (dict_url in dict_files) {
    filename <- basename(dict_url)
    local_path <- file.path(downloads_dir, filename)
    
    if (!file.exists(local_path) || force_download) {
      if (verbose) message("    Downloading dictionary: ", filename)
      
      response <- GET(dict_url, write_disk(local_path, overwrite = TRUE))
      if (status_code(response) == 200) {
        downloaded <- downloaded + 1
        if (verbose) message("      Downloaded successfully")
      } else {
        if (verbose) message("      Download failed (", status_code(response), ")")
        next
      }
    }
  }
  
  # Process dictionary files and create yearly tables (similar to our previous scripts)
  if (length(dict_files) > 0) {
    dict_imported <- import_year_dictionaries(downloads_dir, con, year, verbose)
    if (dict_imported) {
      imported <- 1
    }
  }
  
  return(list(downloaded = downloaded, imported = imported))
}

#' Helper function to extract table name from filename
#' @param filename Data file name
#' @return Extracted table name or NULL
extract_table_name_from_filename <- function(filename) {
  # Remove .zip extension and extract table name
  base_name <- gsub("\\.zip$", "", filename, ignore.case = TRUE)
  
  # Handle various IPEDS naming patterns
  # Examples: HD2024.zip -> HD2024, C2024_A.zip -> C2024_A
  return(base_name)
}

#' Check if table exists in database
#' @param con Database connection
#' @param table_name Table name to check
#' @return Logical indicating if table exists
table_exists_in_db <- function(con, table_name) {
  tables <- dbListTables(con)
  return(table_name %in% tables)
}

#' Import a data file to database
#' @param file_path Path to ZIP file
#' @param table_name Name for database table
#' @param con Database connection
#' @param verbose Whether to print progress
#' @return Logical indicating success
import_data_file <- function(file_path, table_name, con, verbose) {
  
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
    
    # Read and import CSV
    data <- read.csv(csv_file, stringsAsFactors = FALSE)
    dbWriteTable(con, table_name, data, overwrite = TRUE)
    
    # Clean up
    unlink(extract_dir, recursive = TRUE)
    
    return(TRUE)
    
  }, error = function(e) {
    if (verbose) message("        Error importing ", table_name, ": ", e$message)
    return(FALSE)
  })
}

#' Import dictionary files for a specific year
#' @param downloads_dir Downloads directory
#' @param con Database connection  
#' @param year 4-digit year
#' @param verbose Whether to print progress
#' @return Logical indicating success
import_year_dictionaries <- function(downloads_dir, con, year, verbose) {
  
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
    data <- process_dict_zip(dict_file, verbose)
    
    if (!is.null(data)) {
      file_prefix <- gsub("_[Dd]ict\\.zip$", "", basename(dict_file))
      
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
  
  # Create Tables table (manual creation like we did for Tables24)
  if (!table_exists_in_db(con, tables_name)) {
    create_tables_for_year(con, year, tables_name, verbose)
  }
  
  # Create vartable table
  if (length(all_vartable_data) > 0 && !table_exists_in_db(con, vartable_name)) {
    combined_vartable <- do.call(rbind, all_vartable_data)
    dbWriteTable(con, vartable_name, combined_vartable, overwrite = TRUE)
    if (verbose) message("      Created ", vartable_name, " with ", nrow(combined_vartable), " rows")
  }
  
  # Create valuesets table  
  if (length(all_valuesets_data) > 0 && !table_exists_in_db(con, valuesets_name)) {
    combined_valuesets <- do.call(rbind, all_valuesets_data)
    dbWriteTable(con, valuesets_name, combined_valuesets, overwrite = TRUE)
    if (verbose) message("      Created ", valuesets_name, " with ", nrow(combined_valuesets), " rows")
  }
  
  return(TRUE)
}

#' Process dictionary ZIP file (reuse from our previous work)
#' @param zip_path Path to dictionary ZIP file
#' @param verbose Whether to print progress
#' @return List with vartable and valuesets data
process_dict_zip <- function(zip_path, verbose = FALSE) {
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
  sheet_names <- excel_sheets(excel_file)
  
  result <- list()
  
  # Look for Varlist worksheet (maps to vartable)
  if ("Varlist" %in% sheet_names) {
    result$vartable <- read_excel(excel_file, sheet = "Varlist")
  }
  
  # Look for Description worksheet (maps to valuesets)  
  if ("Description" %in% sheet_names) {
    result$valuesets <- read_excel(excel_file, sheet = "Description")
  } else if ("Frequencies" %in% sheet_names) {
    result$valuesets <- read_excel(excel_file, sheet = "Frequencies")
  }
  
  # Clean up
  unlink(extract_dir, recursive = TRUE)
  
  return(result)
}

#' Create Tables table for a specific year
#' @param con Database connection
#' @param year 4-digit year
#' @param table_name Name for the Tables table
#' @param verbose Whether to print progress
create_tables_for_year <- function(con, year, table_name, verbose) {
  
  # Get list of data tables for this year
  year_2digit <- sprintf("%02d", year %% 100)
  all_tables <- dbListTables(con)
  data_tables <- grep(paste0(".*", year_2digit, "$"), all_tables, value = TRUE)
  data_tables <- setdiff(data_tables, c(paste0("Tables", year_2digit), 
                                       paste0("vartable", year_2digit),
                                       paste0("valuesets", year_2digit)))
  
  if (length(data_tables) == 0) {
    if (verbose) message("      No data tables found for ", year, " to catalog")
    return(FALSE)
  }
  
  # Create Tables data (simplified version)
  tables_data <- data.frame(
    SurveyOrder = seq_along(data_tables),
    SurveyNumber = 1,
    Survey = "IPEDS Survey",
    YearCoverage = paste("Academic year", year, "-", (year + 1) %% 100),
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
  
  dbWriteTable(con, table_name, tables_data, overwrite = TRUE)
  if (verbose) message("      Created ", table_name, " with ", nrow(tables_data), " tables cataloged")
  
  return(TRUE)
}

#' Update the consolidated dictionary tables with new year data
#' @param con Database connection
#' @param verbose Whether to print progress
update_consolidated_dictionaries <- function(con, verbose) {
  
  if (verbose) message("  Regenerating consolidated dictionary tables...")
  
  # Get all Tables, vartable, and valuesets tables
  all_tables <- dbListTables(con)
  
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
      
      cols <- dbListFields(con, table)
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
    dbExecute(con, sprintf("CREATE OR REPLACE TABLE Tables_All AS %s", union_query))
    
    if (verbose) message("      Tables_All updated")
  }
  
  # Recreate vartable_All
  if (length(vartable_tables) > 0) {
    if (verbose) message("    Updating vartable_All...")
    
    vartable_queries <- c()
    for (table in vartable_tables) {
      year <- gsub("vartable", "", table)
      year_4digit <- ifelse(as.numeric(year) <= 50, 2000 + as.numeric(year), 1900 + as.numeric(year))
      
      cols <- dbListFields(con, table)
      if (length(cols) <= 10) {
        # 2024+ format from Excel
        query <- sprintf('SELECT NULL as SurveyOrder, NULL as SurveyNumber, NULL as Survey, NULL as Tablenumber, NULL as TableName, NULL as TableTitle, varNumber, NULL as varOrder, varName, imputationvar, varTitle, DataType, FieldWidth as fieldWidth, format, NULL as multiRecord, NULL as hasRV, NULL as fileNumber, NULL as sectionnumber, NULL as varSource, NULL as filetitle, NULL as sectionTitle, NULL as longDescription, %d as YEAR, source_file FROM %s', year_4digit, table)
      } else {
        # 2006-2023 format
        query <- sprintf('SELECT SurveyOrder, SurveyNumber, Survey, Tablenumber, TableName, TableTitle, varNumber, varOrder, varName, imputationvar, varTitle, DataType, fieldWidth, format, multiRecord, hasRV, fileNumber, sectionnumber, varSource, filetitle, sectionTitle, longDescription, %d as YEAR, NULL as source_file FROM %s', year_4digit, table)
      }
      vartable_queries <- c(vartable_queries, query)
    }
    
    union_query <- paste(vartable_queries, collapse=" UNION ALL ")
    dbExecute(con, sprintf("CREATE OR REPLACE TABLE vartable_All AS %s", union_query))
    
    if (verbose) message("      vartable_All updated")
  }
  
  # Recreate valuesets_All
  if (length(valuesets_tables) > 0) {
    if (verbose) message("    Updating valuesets_All...")
    
    valuesets_queries <- c()
    for (table in valuesets_tables) {
      year <- gsub("valuesets", "", table)
      year_4digit <- ifelse(as.numeric(year) <= 50, 2000 + as.numeric(year), 1900 + as.numeric(year))
      
      cols <- dbListFields(con, table)
      if (length(cols) <= 5) {
        # 2024+ format from Excel
        query <- sprintf('SELECT NULL as SurveyOrder, NULL as Tablenumber, NULL as TableName, varNumber, NULL as varOrder, varName, NULL as Codevalue, NULL as Frequency, NULL as Percent, NULL as valueOrder, NULL as valueLabel, NULL as varTitle, longDescription, %d as YEAR, source_file FROM %s', year_4digit, table)
      } else {
        # 2006-2023 format
        query <- sprintf('SELECT SurveyOrder, Tablenumber, TableName, varNumber, varOrder, varName, Codevalue, Frequency, Percent, valueOrder, valueLabel, varTitle, NULL as longDescription, %d as YEAR, NULL as source_file FROM %s', year_4digit, table)
      }
      valuesets_queries <- c(valuesets_queries, query)
    }
    
    union_query <- paste(valuesets_queries, collapse=" UNION ALL ")
    dbExecute(con, sprintf("CREATE OR REPLACE TABLE valuesets_All AS %s", union_query))
    
    if (verbose) message("      valuesets_All updated")
  }
  
  if (verbose) message("    Consolidated dictionary tables updated successfully")
}

#' String repetition operator for formatting
#' @param string String to repeat
#' @param times Number of times to repeat
# Removed the %r% operator definition since it was causing issues