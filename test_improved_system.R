# Test the improved IPEDS download and import system
# Source the updated functions
source("R/web_scraping.R")
source("R/data_processing.R")
source("R/database_management.R")
source("R/ipeds_utilities.R")

# Test with a small subset
message("Testing improved IPEDS system...")

# First, get file list for 2024
file_list <- scrape_ipeds_files_enhanced(2024)
message("Found ", nrow(file_list), " files for 2024")

# Test with just one file first
if (nrow(file_list) > 0) {
  test_file <- file_list[1, ]
  message("Testing with file: ", test_file$table_name)
  
  # Test download (should skip if already exists)
  csv_path <- download_ipeds_csv(test_file, verbose = TRUE)
  
  if (!is.null(csv_path) && file.exists(csv_path)) {
    message("Download successful: ", csv_path)
    message("File size: ", file.size(csv_path), " bytes")
    
    # Test import
    import_result <- import_csv_to_duckdb(csv_path, test_file$table_name, verbose = TRUE)
    
    if (import_result) {
      message("Import successful!")
      
      # Check if table exists in database
      con <- ensure_connection()
      tables <- DBI::dbListTables(con)
      if (test_file$table_name %in% tables) {
        row_count <- DBI::dbGetQuery(con, paste("SELECT COUNT(*) as n FROM", test_file$table_name))$n
        message("Table ", test_file$table_name, " exists with ", row_count, " rows")
      }
    } else {
      message("Import failed!")
    }
  } else {
    message("Download failed!")
  }
} else {
  message("No files found for 2024")
}