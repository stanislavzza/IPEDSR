#!/usr/bin/env Rscript
# Investigate IC2023_CAMPUSES import issue

library(DBI)
library(duckdb)

# Check if the table exists in database
get_ipeds_db_path <- function() {
  data_dir <- rappdirs::user_data_dir("IPEDSR", "FurmanIR")
  file.path(data_dir, "ipeds_2004-2023.duckdb")
}

con <- DBI::dbConnect(duckdb::duckdb(), get_ipeds_db_path())
all_tables <- DBI::dbListTables(con)

cat("Checking for IC2023_CAMPUSES table...\n")
if ("IC2023_CAMPUSES" %in% all_tables) {
  cat("✓ IC2023_CAMPUSES table exists in database\n")
  
  # Get basic info
  count <- DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM IC2023_CAMPUSES")$count
  cat("  Rows:", count, "\n")
  
  # Check for duplicates
  unique_count <- DBI::dbGetQuery(con, "SELECT COUNT(DISTINCT *) as count FROM IC2023_CAMPUSES")$count
  cat("  Unique rows:", unique_count, "\n")
  
  if (count != unique_count) {
    cat("  WARNING: Table has", count - unique_count, "duplicate rows\n")
  }
  
} else {
  cat("✗ IC2023_CAMPUSES table NOT found in database\n")
  cat("  This confirms the import failed due to duplicate row names\n")
}

# Check if the file was downloaded
downloads_dir <- file.path(rappdirs::user_data_dir("IPEDSR"), "downloads")
ic_campus_file <- file.path(downloads_dir, "IC2023_CAMPUSES.zip")

cat("\nChecking downloaded file...\n")
if (file.exists(ic_campus_file)) {
  cat("✓ IC2023_CAMPUSES.zip was downloaded to:", ic_campus_file, "\n")
  cat("  File size:", file.size(ic_campus_file), "bytes\n")
  
  # Try to examine the file
  temp_dir <- tempdir()
  unzip(ic_campus_file, exdir = temp_dir, overwrite = TRUE)
  
  csv_files <- list.files(temp_dir, pattern = "\\.csv$", full.names = TRUE, ignore.case = TRUE)
  cat("  CSV files in ZIP:", length(csv_files), "\n")
  
  if (length(csv_files) > 0) {
    cat("  CSV file:", basename(csv_files[1]), "\n")
    
    # Try to read just the first few rows to see the structure
    tryCatch({
      test_read <- read.csv(csv_files[1], nrows = 5, stringsAsFactors = FALSE)
      cat("  Columns:", ncol(test_read), "\n")
      cat("  Column names:", paste(colnames(test_read), collapse = ", "), "\n")
      cat("  First few rows preview:\n")
      print(head(test_read, 3))
    }, error = function(e) {
      cat("  Error reading CSV:", e$message, "\n")
    })
  }
  
} else {
  cat("✗ IC2023_CAMPUSES.zip was NOT downloaded\n")
}

DBI::dbDisconnect(con)