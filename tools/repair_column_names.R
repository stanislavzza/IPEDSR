# Repair Script: Fix Column Names in Tables with YEAR
# Run this to fix the "data...1.unitid_pos." column name issue

library(DBI)
library(duckdb)
library(IPEDSR)

cat("========================================\n")
cat("REPAIRING COLUMN NAMES\n")
cat("========================================\n\n")

# Connect to database
db_path <- file.path(rappdirs::user_data_dir("IPEDSR"), "ipeds_2004-2023.duckdb")
con <- dbConnect(duckdb::duckdb(), db_path, read_only = FALSE)

# Get all tables
all_tables <- dbListTables(con)
data_tables <- all_tables[!grepl("^(ipeds_|sqlite_|Tables|vartable|valuesets)", all_tables)]

cat("Checking", length(data_tables), "tables for column name issues...\n\n")

repaired <- 0
checked <- 0

for (i in seq_along(data_tables)) {
  table_name <- data_tables[i]
  
  if (i == 1 || i == length(data_tables) || i %% 50 == 0) {
    cat("Checking table", i, "/", length(data_tables), ":", table_name, "\n")
  }
  
  tryCatch({
    # Get schema
    schema <- dbGetQuery(con, paste("PRAGMA table_info(", table_name, ")"))
    
    # Check for problematic column names
    bad_cols <- grep("^data\\.\\.\\.|\\.\\.\\.$", schema$name, value = TRUE)
    
    if (length(bad_cols) > 0) {
      cat("  Found bad column names in", table_name, ":", paste(bad_cols, collapse = ", "), "\n")
      
      # Read the table
      data <- dbReadTable(con, table_name)
      
      # Fix column names
      # The pattern "data...1.unitid_pos." suggests data.frame() mangled names
      # We need to restore proper names
      
      # Get original column positions
      col_names <- names(data)
      
      # Fix the mangled names - likely the first one should be UNITID
      if (any(grepl("data\\.\\.\\.", col_names))) {
        # Try to reconstruct original names
        # If we have YEAR in the table, it should help us identify structure
        year_pos <- which(col_names == "YEAR")
        
        if (length(year_pos) > 0) {
          # Get the original table structure before YEAR was added
          # We'll need to delete and re-add YEAR properly
          
          # Remove YEAR column
          data_no_year <- data[, col_names != "YEAR", drop = FALSE]
          
          # Check if this table still exists in a backup or can be re-imported
          # For now, let's just report it
          cat("    ⚠️  Table", table_name, "needs manual repair or re-import\n")
          cat("       Bad columns:", paste(bad_cols, collapse = ", "), "\n")
        }
      }
      
      repaired <- repaired + 1
    }
    
    checked <- checked + 1
    
  }, error = function(e) {
    cat("  Error checking", table_name, ":", e$message, "\n")
  })
}

dbDisconnect(con, shutdown = TRUE)

cat("\n========================================\n")
cat("REPAIR SUMMARY\n")
cat("========================================\n")
cat("Tables checked:", checked, "\n")
cat("Tables with column name issues:", repaired, "\n\n")

if (repaired > 0) {
  cat("RECOMMENDED ACTION:\n")
  cat("The tables with bad column names need to be fixed.\n")
  cat("The safest approach is to:\n")
  cat("1. Delete those tables from the database\n")
  cat("2. Re-run add_year_columns_to_database() with the fixed version\n")
  cat("\nOr better yet:\n")
  cat("1. Backup your database: ipeds_data_manager('backup')\n")
  cat("2. Re-download the affected tables: update_data()\n")
  cat("3. Run add_year_columns_to_database() again\n")
} else {
  cat("✓ No column name issues found!\n")
}
