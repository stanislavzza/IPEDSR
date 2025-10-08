#' IPEDS Data Download and Processing System
#' 
#' Functions for downloading, processing, and integrating IPEDS data files

#' Download a single IPEDS CSV file
#' @param file_info Single row from file listing with download information
#' @param download_dir Directory to store downloaded files (default: data/downloads)
#' @param force_redownload Whether to redownload even if file exists
#' @param verbose Whether to print progress messages
#' @return Path to downloaded CSV file or NULL if failed
#' @export
download_ipeds_csv <- function(file_info, download_dir = file.path("data", "downloads"), 
                              force_redownload = FALSE, verbose = TRUE) {
  
  # Check if we have a CSV link first, then fall back to ZIP
  use_zip <- FALSE
  download_url <- NULL
  
  if (!is.null(file_info$csv_link) && file_info$csv_link != "") {
    download_url <- file_info$csv_link
    use_zip <- FALSE
  } else if (!is.null(file_info$zip_link) && file_info$zip_link != "") {
    download_url <- file_info$zip_link
    use_zip <- TRUE
  } else {
    warning("No CSV or ZIP download link available for ", file_info$table_name)
    return(NULL)
  }
  
  # Ensure download directory exists
  if (!dir.exists(download_dir)) {
    dir.create(download_dir, recursive = TRUE)
  }
  
  # Construct local filename
  if (use_zip) {
    temp_filename <- paste0(file_info$table_name, ".zip")
    temp_path <- file.path(download_dir, temp_filename)
    final_filename <- paste0(file_info$table_name, ".csv")
    final_path <- file.path(download_dir, final_filename)
  } else {
    temp_filename <- paste0(file_info$table_name, ".csv")
    temp_path <- file.path(download_dir, temp_filename)
    final_path <- temp_path
  }
  
  # Check if final CSV file already exists (skip download unless forced)
  if (file.exists(final_path) && !force_redownload) {
    if (verbose) {
      message("File already exists, skipping download: ", final_path)
    }
    return(final_path)
  }
  
  if (verbose) {
    if (use_zip) {
      message("Downloading ", file_info$table_name, " ZIP file from IPEDS...")
    } else {
      message("Downloading ", file_info$table_name, " CSV from IPEDS...")
    }
  }
  
  tryCatch({
    # Make sure the URL is absolute
    if (!grepl("^https?://", download_url)) {
      # For relative URLs, construct proper base path
      if (grepl("^data/", download_url)) {
        # IPEDS data files are in the datacenter/data directory
        download_url <- paste0("https://nces.ed.gov/ipeds/datacenter/", download_url)
      } else {
        # General case - add base domain
        download_url <- paste0("https://nces.ed.gov", download_url)
      }
    }
    
    # Download the file
    response <- httr::GET(
      download_url,
      httr::write_disk(temp_path, overwrite = TRUE),
      httr::progress()
    )
    
    if (httr::status_code(response) != 200) {
      warning("Failed to download ", file_info$table_name, 
              ". Status: ", httr::status_code(response))
      return(NULL)
    }
    
    # If we downloaded a ZIP file, extract the CSV
    if (use_zip) {
      if (verbose) {
        message("Extracting CSV from ZIP file...")
      }
      
      # Extract ZIP file
      tryCatch({
        # List contents of ZIP file
        zip_contents <- utils::unzip(temp_path, list = TRUE)
        
        if (nrow(zip_contents) == 0) {
          warning("ZIP file is empty: ", temp_path)
          return(NULL)
        }
        
        # Look for a CSV file in the ZIP
        csv_files <- zip_contents$Name[grepl("\\.csv$", zip_contents$Name, ignore.case = TRUE)]
        
        if (length(csv_files) == 0) {
          warning("No CSV file found in ZIP: ", temp_path)
          return(NULL)
        }
        
        # Use the first CSV file found (typically there's only one)
        csv_file <- csv_files[1]
        
        # Extract the CSV file
        utils::unzip(temp_path, files = csv_file, exdir = download_dir, overwrite = TRUE)
        
        # Move the extracted file to our expected name if needed
        extracted_path <- file.path(download_dir, csv_file)
        if (extracted_path != final_path) {
          file.rename(extracted_path, final_path)
        }
        
        # Clean up ZIP file
        if (file.exists(temp_path)) {
          file.remove(temp_path)
        }
        
        # Update path for validation
        validation_path <- final_path
        
      }, error = function(e) {
        warning("Failed to extract ZIP file: ", e$message)
        return(NULL)
      })
    } else {
      # For direct CSV downloads, validation path is the temp path
      validation_path <- temp_path
      final_path <- temp_path
    }
    
    # Validate the downloaded file
    validation <- validate_downloaded_file(validation_path, file_info$table_name, verbose)
    
    if (!validation$valid) {
      warning("Downloaded file failed validation: ", 
              paste(validation$errors, collapse = "; "))
      return(NULL)
    }
    
    if (verbose) {
      message("Successfully downloaded ", file_info$table_name, 
              " (", validation$row_count, " rows, ", 
              validation$column_count, " columns)")
    }
    
    return(final_path)
    
  }, error = function(e) {
    warning("Error downloading ", file_info$table_name, ": ", e$message)
    return(NULL)
  })
}

#' Process downloaded CSV and import to DuckDB
#' @param csv_path Path to downloaded CSV file
#' @param table_name Name for the database table
#' @param db_connection DuckDB connection
#' @param replace_existing Whether to replace existing table
#' @param verbose Whether to print progress
#' @return TRUE if successful, FALSE otherwise
#' @export
import_csv_to_duckdb <- function(csv_path, table_name, db_connection = NULL, 
                                 replace_existing = TRUE, verbose = TRUE) {
  
  if (!file.exists(csv_path)) {
    warning("CSV file does not exist: ", csv_path)
    return(FALSE)
  }
  
  if (is.null(db_connection)) {
    db_connection <- ensure_connection(read_only = FALSE)
  }
  
  if (verbose) {
    message("Importing ", table_name, " to database...")
  }
  
  tryCatch({
    # Check if table already exists
    existing_tables <- DBI::dbListTables(db_connection)
    table_exists <- table_name %in% existing_tables
    
    if (table_exists && !replace_existing) {
      if (verbose) {
        message("Table ", table_name, " already exists and replace_existing=FALSE")
      }
      return(TRUE)
    }
    
    # Read CSV with appropriate data types
    csv_data <- read_csv_with_types(csv_path, table_name, verbose)
    
    if (is.null(csv_data)) {
      warning("Failed to read CSV file: ", csv_path)
      return(FALSE)
    }
    
    # Drop existing table if replacing
    if (table_exists && replace_existing) {
      DBI::dbExecute(db_connection, paste("DROP TABLE", table_name))
    }
    
    # Write to database
    DBI::dbWriteTable(
      db_connection, 
      table_name, 
      csv_data, 
      overwrite = replace_existing,
      append = FALSE
    )
    
    # Verify the import
    row_count <- DBI::dbGetQuery(
      db_connection, 
      paste("SELECT COUNT(*) as n FROM", table_name)
    )$n
    
    if (verbose) {
      message("Successfully imported ", table_name, " with ", row_count, " rows")
    }
    
    return(TRUE)
    
  }, error = function(e) {
    warning("Error importing ", table_name, " to database: ", e$message)
    return(FALSE)
  })
}

#' Read CSV with appropriate data type inference
#' @param csv_path Path to CSV file
#' @param table_name Table name for context
#' @param verbose Whether to print progress
#' @return Data frame or NULL if failed
read_csv_with_types <- function(csv_path, table_name, verbose = FALSE) {
  
  tryCatch({
    # For IPEDS data, we need to be very flexible with column types
    # since they can change between years. Read as character first,
    # then convert what we can safely convert.
    
    if (verbose) {
      message("Reading CSV with flexible column types for IPEDS data...")
    }
    
    # Read everything as character initially to handle IPEDS variability
    full_data <- utils::read.csv(
      csv_path, 
      stringsAsFactors = FALSE,
      na.strings = c("", "NA", "NULL", ".", "-", "n/a"),
      colClasses = "character"  # Read everything as character first
    )
    
    if (verbose) {
      message("Read ", nrow(full_data), " rows and ", ncol(full_data), " columns")
    }
    
    # Apply intelligent type conversion for known IPEDS patterns
    full_data <- convert_ipeds_types_safely(full_data, table_name, verbose)
    
    # Clean up the data
    full_data <- clean_ipeds_data(full_data, table_name)
    
    return(full_data)
    
  }, error = function(e) {
    warning("Error reading CSV ", csv_path, ": ", e$message)
    return(NULL)
  })
}

#' Safely convert IPEDS data types without assumptions
#' @param data Data frame with character columns
#' @param table_name Table name for context
#' @param verbose Whether to print progress
#' @return Data frame with converted types
convert_ipeds_types_safely <- function(data, table_name, verbose = FALSE) {
  
  if (verbose) {
    message("Converting IPEDS data types safely for ", table_name)
  }
  
  for (col_name in names(data)) {
    col_data <- data[[col_name]]
    
    # Remove NA values and empty strings for type inference
    non_empty_data <- col_data[!is.na(col_data) & col_data != "" & col_data != "-"]
    
    if (length(non_empty_data) == 0) {
      next  # Keep as character if all values are empty/NA
    }
    
    # UNITID should always be treated as integer if possible
    if (col_name == "UNITID") {
      numeric_values <- suppressWarnings(as.numeric(non_empty_data))
      if (!any(is.na(numeric_values))) {
        data[[col_name]] <- suppressWarnings(as.integer(data[[col_name]]))
      }
      next
    }
    
    # Try to convert to numeric if ALL non-empty values are numeric
    numeric_values <- suppressWarnings(as.numeric(non_empty_data))
    if (!any(is.na(numeric_values))) {
      # Check if all numeric values are integers
      if (all(numeric_values == as.integer(numeric_values), na.rm = TRUE)) {
        data[[col_name]] <- suppressWarnings(as.integer(data[[col_name]]))
      } else {
        data[[col_name]] <- suppressWarnings(as.numeric(data[[col_name]]))
      }
    }
    # Otherwise keep as character - IPEDS has many mixed-type columns
  }
  
  return(data)
}

#' Clean and standardize IPEDS data
#' @param data Data frame to clean
#' @param table_name Table name for context
#' @return Cleaned data frame
clean_ipeds_data <- function(data, table_name) {
  
  # Standard cleaning operations for IPEDS data
  
  # Ensure UNITID exists and is properly formatted
  if ("UNITID" %in% names(data)) {
    data$UNITID <- as.integer(data$UNITID)
  }
  
  # Convert common IPEDS codes to integers
  code_columns <- names(data)[grepl("CODE$|LEVEL$|TYPE$|CAT$", names(data))]
  for (col in code_columns) {
    if (col %in% names(data)) {
      data[[col]] <- suppressWarnings(as.integer(data[[col]]))
    }
  }
  
  # Handle common IPEDS missing value codes
  # IPEDS often uses specific codes like -1, -2 for different types of missing data
  for (col_name in names(data)) {
    if (is.numeric(data[[col_name]])) {
      # Convert negative codes to NA if they represent missing data
      # This might need refinement based on specific IPEDS coding schemes
      data[[col_name]][data[[col_name]] < 0] <- NA
    }
  }
  
  return(data)
}

#' Download and process multiple IPEDS files
#' @param file_list Data frame with file information (from scraping functions)
#' @param download_dir Directory for downloads (default: data/downloads)
#' @param db_connection Database connection (optional)
#' @param max_concurrent Maximum number of concurrent downloads
#' @param verbose Whether to print progress
#' @return Data frame with processing results
#' @export
batch_download_ipeds_files <- function(file_list, download_dir = file.path("data", "downloads"), 
                                      db_connection = NULL, max_concurrent = 3,
                                      force_redownload = FALSE, verbose = TRUE) {
  
  if (nrow(file_list) == 0) {
    warning("No files to download")
    return(data.frame())
  }
  
  if (is.null(db_connection)) {
    db_connection <- ensure_connection(read_only = FALSE)
  }
  
  if (verbose) {
    message("Starting batch download of ", nrow(file_list), " files...")
  }
  
  # Create results tracking data frame
  results <- data.frame(
    table_name = file_list$table_name,
    download_success = FALSE,
    import_success = FALSE,
    error_message = "",
    row_count = 0,
    processing_time = 0,
    stringsAsFactors = FALSE
  )
  
  # Process files (for now, sequentially - could be parallelized)
  for (i in seq_len(nrow(file_list))) {
    file_info <- file_list[i, ]
    
    start_time <- Sys.time()
    
    if (verbose) {
      message("Processing ", i, "/", nrow(file_list), ": ", file_info$table_name)
    }
    
    # Check if table already exists in database
    existing_tables <- DBI::dbListTables(db_connection)
    table_exists <- file_info$table_name %in% existing_tables
    
    if (table_exists && !force_redownload) {
      if (verbose) {
        message("  ✓ Table ", file_info$table_name, " already exists, skipping download")
      }
      results$download_success[i] <- TRUE
      results$import_success[i] <- TRUE
      
      # Get existing row count
      row_count <- DBI::dbGetQuery(
        db_connection,
        paste("SELECT COUNT(*) as n FROM", file_info$table_name)
      )$n
      results$row_count[i] <- row_count
      
      next  # Skip to next file
    }
    
    if (verbose && table_exists) {
      message("  ⟳ Table exists but force_redownload=TRUE, re-downloading...")
    }
    
    # Download the file
    csv_path <- download_ipeds_csv(file_info, download_dir, 
                                  force_redownload = force_redownload, verbose = verbose)
    
    if (!is.null(csv_path)) {
      results$download_success[i] <- TRUE
      
      # Import to database
      import_success <- import_csv_to_duckdb(
        csv_path, 
        file_info$table_name, 
        db_connection,
        replace_existing = TRUE,
        verbose = verbose
      )
      
      results$import_success[i] <- import_success
      
      if (import_success) {
        # Get row count
        row_count <- DBI::dbGetQuery(
          db_connection,
          paste("SELECT COUNT(*) as n FROM", file_info$table_name)
        )$n
        results$row_count[i] <- row_count
      }
      
      # Clean up downloaded file
      if (file.exists(csv_path)) {
        file.remove(csv_path)
      }
    } else {
      results$error_message[i] <- "Download failed"
    }
    
    results$processing_time[i] <- as.numeric(difftime(Sys.time(), start_time, units = "secs"))
    
    # Be respectful to the server
    Sys.sleep(1)
  }
  
  if (verbose) {
    successful_downloads <- sum(results$download_success)
    successful_imports <- sum(results$import_success)
    message("Batch processing complete: ", successful_downloads, " downloads, ", 
            successful_imports, " successful imports")
  }
  
  return(results)
}

#' Create or update IPEDS database with new year's data
#' @param year Year to download and process
#' @param components Vector of components to include (NULL for all)
#' @param force_redownload Whether to redownload existing tables
#' @param backup_first Whether to backup existing database
#' @param verbose Whether to print progress
#' @return List with processing results and summary
#' @export
update_ipeds_database_year <- function(year, components = NULL, 
                                      force_redownload = FALSE,
                                      backup_first = TRUE, verbose = TRUE) {
  
  if (verbose) {
    message("Starting IPEDS database update for year ", year)
  }
  
  # Backup existing database if requested
  if (backup_first && ipeds_database_exists()) {
    backup_path <- backup_database()
    if (verbose) {
      message("Database backed up to: ", basename(backup_path))
    }
  }
  
  # Get list of available files for the year
  if (verbose) {
    message("Fetching file list for ", year, "...")
  }
  
  available_files <- scrape_ipeds_files_enhanced(year, verbose = verbose)
  
  if (nrow(available_files) == 0) {
    warning("No files found for year ", year)
    return(list(
      success = FALSE,
      message = "No files found",
      files_processed = 0,
      results = data.frame()
    ))
  }
  
  # Filter by components if specified
  if (!is.null(components)) {
    available_files <- available_files[
      available_files$survey_component %in% components, 
    ]
    
    if (nrow(available_files) == 0) {
      warning("No files found for specified components in year ", year)
      return(list(
        success = FALSE,
        message = "No files found for specified components",
        files_processed = 0,
        results = data.frame()
      ))
    }
  }
  
  # Check which tables already exist (if not forcing redownload)
  if (!force_redownload) {
    existing_tables <- DBI::dbListTables(ensure_connection())
    existing_files <- available_files[
      available_files$table_name %in% existing_tables,
    ]
    
    if (nrow(existing_files) > 0 && verbose) {
      message("Skipping ", nrow(existing_files), " existing tables. ",
              "Use force_redownload=TRUE to update them.")
      available_files <- available_files[
        !available_files$table_name %in% existing_tables,
      ]
    }
  }
  
  if (nrow(available_files) == 0) {
    if (verbose) {
      message("All requested files already exist in database")
    }
    return(list(
      success = TRUE,
      message = "All files already exist",
      files_processed = 0,
      results = data.frame()
    ))
  }
  
  # Download and process files
  results <- batch_download_ipeds_files(
    available_files, 
    verbose = verbose
  )
  
  # Create summary
  successful_imports <- sum(results$import_success)
  total_files <- nrow(results)
  
  success <- successful_imports > 0
  message_text <- paste0(
    "Processed ", total_files, " files, ", 
    successful_imports, " successful imports"
  )
  
  if (verbose) {
    message("Update complete: ", message_text)
  }
  
  return(list(
    success = success,
    message = message_text,
    files_processed = total_files,
    successful_imports = successful_imports,
    results = results
  ))
}