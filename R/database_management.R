#' Database Management for IPEDSR
#' 
#' Functions to manage the IPEDS database including setup, updates, and connection management.

# Global variables for package
.ipeds_env <- new.env(parent = emptyenv())

# Database configuration
.IPEDS_DB_URL <- "https://drive.google.com/uc?export=download&id=1xS0HIGH-XhoSXPIFE9YQ8gn1OmmrzUOC&confirm=t"
.IPEDS_DB_NAME <- "ipeds_2004-2023.duckdb"
.IPEDS_VERSION <- "2023.1"  # Version tracking for updates

#' Get IPEDS database path
#' @description Returns the path where the IPEDS database should be stored
#' @return Character string with the database path
#' @keywords internal
get_ipeds_db_path <- function() {
  # Use user's data directory
  data_dir <- rappdirs::user_data_dir("IPEDSR", "FurmanIR")
  if (!dir.exists(data_dir)) {
    dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
  }
  file.path(data_dir, .IPEDS_DB_NAME)
}

#' Check if IPEDS database exists and is valid
#' @description Checks if the database file exists and can be opened
#' @return Logical indicating if database is ready to use
#' @export
ipeds_database_exists <- function() {
  db_path <- get_ipeds_db_path()
  
  if (!file.exists(db_path)) {
    return(FALSE)
  }
  
  # Try to connect to verify it's a valid database
  tryCatch({
    conn <- DBI::dbConnect(duckdb::duckdb(), db_path, read_only = TRUE)
    tables <- DBI::dbListTables(conn)
    DBI::dbDisconnect(conn)
    return(length(tables) > 0)
  }, error = function(e) {
    return(FALSE)
  })
}

#' Download and setup IPEDS database
#' @description Downloads the IPEDS database from Google Drive and sets it up for use
#' @param force Logical, if TRUE will re-download even if database exists
#' @param quiet Logical, if TRUE suppresses progress messages
#' @return Logical indicating success
#' @export
setup_ipeds_database <- function(force = FALSE, quiet = FALSE) {
  db_path <- get_ipeds_db_path()
  
  # Check if database already exists and is valid
  if (!force && ipeds_database_exists()) {
    if (!quiet) {
      message("IPEDS database already exists and is valid at: ", db_path)
    }
    return(TRUE)
  }
  
  if (!quiet) {
    message("Setting up IPEDS database...")
    message("This is a large file (2.4GB) and may take several minutes to download.")
  }
  
  # Create directory if it doesn't exist
  data_dir <- dirname(db_path)
  if (!dir.exists(data_dir)) {
    dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
  }
  
  # Download the database with Google Drive handling
  tryCatch({
    if (!quiet) {
      message("Downloading IPEDS database from Google Drive...")
    }
    
    # For large Google Drive files, we need to handle the virus scan warning
    # First attempt: try direct download
    response <- httr::GET(
      .IPEDS_DB_URL,
      httr::write_disk(db_path, overwrite = TRUE),
      httr::progress()
    )
    
    # Check if we got an HTML page (virus scan warning) instead of the file
    if (httr::status_code(response) == 200) {
      # Check if the downloaded file is actually HTML (Google's warning page)
      if (file.exists(db_path)) {
        # Read first few bytes to check if it's HTML
        first_bytes <- readBin(db_path, "raw", n = 100)
        first_text <- rawToChar(first_bytes[first_bytes != 0])
        
        if (grepl("<html|<!DOCTYPE", first_text, ignore.case = TRUE)) {
          if (!quiet) {
            message("Received Google Drive virus scan warning. Attempting alternative download...")
          }
          
          # Try alternative approach for large files
          file.remove(db_path)
          
          # Alternative URL format that sometimes bypasses the warning
          alt_url <- paste0("https://drive.usercontent.google.com/download?id=1xS0HIGH-XhoSXPIFE9YQ8gn1OmmrzUOC&export=download&authuser=0&confirm=t")
          
          response <- httr::GET(
            alt_url,
            httr::write_disk(db_path, overwrite = TRUE),
            httr::progress()
          )
        }
      }
    }
    
    if (httr::status_code(response) != 200) {
      stop("Failed to download database. HTTP status: ", httr::status_code(response))
    }
    
    # Verify the downloaded file
    if (!ipeds_database_exists()) {
      stop("Downloaded file appears to be invalid. This may be due to Google Drive's virus scan for large files. Please try downloading manually from: https://drive.google.com/file/d/1xS0HIGH-XhoSXPIFE9YQ8gn1OmmrzUOC/view")
    }
    
    # Store metadata about the download
    store_database_metadata()
    
    if (!quiet) {
      message("IPEDS database successfully downloaded and verified!")
      message("Database location: ", db_path)
    }
    
    return(TRUE)
    
  }, error = function(e) {
    # Clean up partial download
    if (file.exists(db_path)) {
      file.remove(db_path)
    }
    stop("Failed to setup IPEDS database: ", e$message)
  })
}

#' Store database metadata
#' @description Stores information about when the database was downloaded/updated
#' @keywords internal
store_database_metadata <- function() {
  metadata <- list(
    download_date = Sys.Date(),
    download_time = Sys.time(),
    version = .IPEDS_VERSION,
    source_url = .IPEDS_DB_URL
  )
  
  metadata_path <- file.path(dirname(get_ipeds_db_path()), "database_metadata.rds")
  saveRDS(metadata, metadata_path)
}

#' Get database metadata
#' @description Retrieves information about the current database
#' @return List with database metadata or NULL if not found
#' @export
get_database_info <- function() {
  metadata_path <- file.path(dirname(get_ipeds_db_path()), "database_metadata.rds")
  
  if (!file.exists(metadata_path)) {
    return(NULL)
  }
  
  metadata <- readRDS(metadata_path)
  
  # Add current file info
  db_path <- get_ipeds_db_path()
  if (file.exists(db_path)) {
    metadata$file_size <- file.size(db_path)
    metadata$file_modified <- file.mtime(db_path)
  }
  
  return(metadata)
}

#' Check if database needs updating
#' @description Checks if the database should be updated based on age
#' @param max_age_days Maximum age of database in days before suggesting update
#' @return Logical indicating if update is recommended
#' @export
check_database_age <- function(max_age_days = 90) {
  metadata <- get_database_info()
  
  if (is.null(metadata)) {
    return(TRUE)  # No metadata means we should update
  }
  
  days_since_download <- as.numeric(Sys.Date() - metadata$download_date)
  return(days_since_download > max_age_days)
}

#' Update IPEDS database
#' @description Forces an update of the IPEDS database
#' @param quiet Logical, if TRUE suppresses progress messages
#' @return Logical indicating success
#' @export
update_ipeds_database <- function(quiet = FALSE) {
  if (!quiet) {
    message("Updating IPEDS database...")
  }
  
  return(setup_ipeds_database(force = TRUE, quiet = quiet))
}

#' Get database connection
#' @description Internal function to get a database connection
#' @param read_only Logical, if TRUE opens connection in read-only mode
#' @return DBI connection object
#' @keywords internal
get_ipeds_connection <- function(read_only = TRUE) {
  # Check if database exists, if not, set it up
  if (!ipeds_database_exists()) {
    message("IPEDS database not found. Setting up for first use...")
    setup_ipeds_database(quiet = FALSE)
  }
  
  # Check if database is old and suggest update
  if (check_database_age()) {
    message("Note: Your IPEDS database is more than 90 days old. Consider running update_ipeds_database()")
  }
  
  db_path <- get_ipeds_db_path()
  conn <- DBI::dbConnect(duckdb::duckdb(), db_path, read_only = read_only)
  
  return(conn)
}

#' Ensure database connection
#' @description Ensures a valid database connection exists, creating one if needed
#' @return DBI connection object
#' @keywords internal
ensure_connection <- function() {
  # Check if we have a cached connection
  if (exists("connection", envir = .ipeds_env) && 
      DBI::dbIsValid(.ipeds_env$connection)) {
    return(.ipeds_env$connection)
  }
  
  # Create new connection
  .ipeds_env$connection <- get_ipeds_connection()
  return(.ipeds_env$connection)
}

#' Disconnect from database
#' @description Cleanly disconnects from the IPEDS database
#' @export
disconnect_ipeds <- function() {
  if (exists("connection", envir = .ipeds_env) && 
      DBI::dbIsValid(.ipeds_env$connection)) {
    DBI::dbDisconnect(.ipeds_env$connection)
    rm("connection", envir = .ipeds_env)
  }
}

#' Manually setup IPEDS database from local file
#' @description Set up the IPEDS database from a manually downloaded file
#' @param file_path Path to the manually downloaded database file
#' @return Logical indicating success
#' @export
setup_ipeds_database_manual <- function(file_path) {
  if (!file.exists(file_path)) {
    stop("File not found: ", file_path)
  }
  
  db_path <- get_ipeds_db_path()
  
  # Create directory if it doesn't exist
  data_dir <- dirname(db_path)
  if (!dir.exists(data_dir)) {
    dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
  }
  
  # Copy the file
  message("Copying database file...")
  file.copy(file_path, db_path, overwrite = TRUE)
  
  # Verify the file
  if (!ipeds_database_exists()) {
    stop("The provided file does not appear to be a valid IPEDS database")
  }
  
  # Store metadata
  store_database_metadata()
  
  message("IPEDS database successfully set up from manual file!")
  message("Database location: ", db_path)
  
  return(TRUE)
}

#' Get database path for manual download
#' @description Returns the path where users should place manually downloaded database files
#' @return Character string with the expected database path
#' @export
get_manual_database_path <- function() {
  db_path <- get_ipeds_db_path()
  message("Manual database setup instructions:")
  message("1. Download the database from: https://drive.google.com/file/d/1xS0HIGH-XhoSXPIFE9YQ8gn1OmmrzUOC/view")
  message("2. Place the file at: ", db_path)
  message("3. Or use: setup_ipeds_database_manual('/path/to/your/downloaded/file.duckdb')")
  return(db_path)
}

#' Package cleanup
#' @description Ensures database connection is closed when package is unloaded
#' @param libpath Library path (unused)
#' @keywords internal
.onUnload <- function(libpath) {
  disconnect_ipeds()
}