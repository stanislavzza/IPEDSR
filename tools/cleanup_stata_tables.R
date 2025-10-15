#!/usr/bin/env Rscript
# Cleanup duplicate Stata tables from IPEDS database

library(DBI)
library(duckdb)

# Get database path
get_ipeds_db_path <- function() {
  data_dir <- rappdirs::user_data_dir("IPEDSR", "FurmanIR")
  file.path(data_dir, "ipeds_2004-2023.duckdb")
}

cat("Connecting to IPEDS database...\n")
con <- DBI::dbConnect(duckdb::duckdb(), get_ipeds_db_path())

# Get all table names
all_tables <- DBI::dbListTables(con)

# Find Stata tables (ending with _Data_Stata)
stata_tables <- grep("_Data_Stata$", all_tables, value = TRUE)

cat("Found", length(stata_tables), "Stata tables to remove:\n")
for (table in stata_tables) {
  cat("  -", table, "\n")
}

if (length(stata_tables) > 0) {
  
  cat("\nRemoving duplicate Stata tables...\n")
  
  for (table in stata_tables) {
    tryCatch({
      DBI::dbExecute(con, paste0("DROP TABLE IF EXISTS ", table))
      cat("  ✓ Removed:", table, "\n")
    }, error = function(e) {
      cat("  ✗ Error removing", table, ":", e$message, "\n")
    })
  }
  
  cat("\nCleanup complete!\n")
  
  # Show final table count
  remaining_tables <- DBI::dbListTables(con)
  cat("Database now has", length(remaining_tables), "tables\n")
  
} else {
  cat("No Stata tables found to remove.\n")
}

# Disconnect
DBI::dbDisconnect(con)
cat("Database connection closed.\n")