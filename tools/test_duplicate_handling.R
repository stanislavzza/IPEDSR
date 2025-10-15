#!/usr/bin/env Rscript
# Test the duplicate row handling fix with IC2023_CAMPUSES

# Source the updated function
source("R/data_updates.R")

library(DBI)
library(duckdb)

# Get database path
get_ipeds_db_path <- function() {
  data_dir <- rappdirs::user_data_dir("IPEDSR", "FurmanIR")
  file.path(data_dir, "ipeds_2004-2023.duckdb")
}

cat("Testing duplicate row handling with IC2023_CAMPUSES...\n")
cat("=====================================================\n\n")

# Check if the file was downloaded
downloads_dir <- file.path(rappdirs::user_data_dir("IPEDSR"), "downloads")
ic_campus_file <- file.path(downloads_dir, "IC2023_CAMPUSES.zip")

if (!file.exists(ic_campus_file)) {
  cat("❌ IC2023_CAMPUSES.zip not found at:", ic_campus_file, "\n")
  cat("Run update_data(years = 2023) first to download the file.\n")
  quit(status = 1)
}

cat("✓ Found IC2023_CAMPUSES.zip\n")
cat("File size:", file.size(ic_campus_file), "bytes\n\n")

# Connect to database
con <- DBI::dbConnect(duckdb::duckdb(), get_ipeds_db_path())

# Test the import function directly
cat("Testing import_data_file_new() with duplicate handling...\n")

result <- import_data_file_new(ic_campus_file, "IC2023_CAMPUSES_TEST", con, verbose = TRUE)

if (result) {
  cat("\n✅ SUCCESS: Import completed without errors!\n")
  
  # Check the imported data
  count <- DBI::dbGetQuery(con, "SELECT COUNT(*) as count FROM IC2023_CAMPUSES_TEST")$count
  cat("Imported", count, "rows\n")
  
  # Show a sample of the data
  sample_data <- DBI::dbGetQuery(con, "SELECT * FROM IC2023_CAMPUSES_TEST LIMIT 5")
  cat("Sample data:\n")
  print(sample_data)
  
  # Clean up test table
  DBI::dbExecute(con, "DROP TABLE IF EXISTS IC2023_CAMPUSES_TEST")
  cat("\nTest table cleaned up.\n")
  
} else {
  cat("\n❌ FAILED: Import still failed with the new handling.\n")
}

DBI::dbDisconnect(con)
cat("\nTest complete!\n")