#!/usr/bin/env Rscript

# Check what years of IPEDS data are actually in the database
library(IPEDSR)
library(DBI)

cat("Checking IPEDS database contents...\n\n")

# Get database connection and list all tables
db_conn <- IPEDSR:::ensure_connection()
all_tables <- DBI::dbListTables(db_conn)

cat("Total tables in database:", length(all_tables), "\n\n")

# Look for recent years
for (year in 2024:2020) {
  tables_year <- all_tables[grepl(as.character(year), all_tables)]
  cat("Tables with", year, "in name:", length(tables_year), "\n")
  if (length(tables_year) > 0) {
    # Show a few example table names
    cat("  Examples:", paste(head(tables_year, 3), collapse = ", "), "\n")
  }
}

cat("\n")

# Extract all years from table names
years_pattern <- regexpr("[0-9]{4}", all_tables)
years_matches <- regmatches(all_tables, years_pattern)
years_valid <- years_matches[nchar(years_matches) == 4]
years_numeric <- as.numeric(years_valid)
years_unique <- sort(unique(years_numeric), decreasing = TRUE)

cat("All years found in table names:\n")
print(years_unique)

cat("\n")

# Check if we have any version tracking metadata
metadata_exists <- "ipeds_metadata" %in% all_tables
cat("Version tracking metadata exists:", metadata_exists, "\n")

if (metadata_exists) {
  cat("\nChecking metadata table...\n")
  metadata <- DBI::dbGetQuery(db_conn, "SELECT data_year, COUNT(*) as table_count, MAX(download_date) as latest_download FROM ipeds_metadata GROUP BY data_year ORDER BY data_year DESC")
  print(metadata)
}

# Check database file info
tryCatch({
  # Try to get database path
  if (inherits(db_conn, "duckdb_connection")) {
    # For newer DuckDB versions, we need to get path differently
    cat("\nDatabase connection type: DuckDB\n")
    
    # Try to find database file in expected location
    library(rappdirs)
    db_dir <- user_data_dir("IPEDSR")
    db_files <- list.files(db_dir, pattern = "\\.duckdb$", full.names = TRUE)
    
    if (length(db_files) > 0) {
      db_path <- db_files[1]  # Use first found
      file_info <- file.info(db_path)
      cat("Database file info:\n")
      cat("Path:", db_path, "\n")
      cat("Size:", round(file_info$size / 1024 / 1024, 1), "MB\n")
      cat("Last modified:", format(file_info$mtime, "%Y-%m-%d %H:%M:%S"), "\n")
    } else {
      cat("Database file not found in expected location:", db_dir, "\n")
    }
  }
}, error = function(e) {
  cat("Could not get database file info:", e$message, "\n")
})