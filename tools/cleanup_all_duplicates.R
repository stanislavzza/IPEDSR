#!/usr/bin/env Rscript
# Cleanup all duplicate statistical software tables from IPEDS database

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

# Find ALL statistical software tables (SPS, SAS, Stata formats)
sps_tables <- grep("_SPS$", all_tables, value = TRUE)
sas_tables <- grep("_SAS$", all_tables, value = TRUE)
stata_tables <- grep("_Stata$", all_tables, value = TRUE)
data_stata_tables <- grep("_Data_Stata$", all_tables, value = TRUE)

# Combine all statistical software tables
duplicate_tables <- c(sps_tables, sas_tables, stata_tables, data_stata_tables)
duplicate_tables <- unique(duplicate_tables)

cat("Found", length(duplicate_tables), "statistical software tables to remove:\n")
cat("\nSPS tables (", length(sps_tables), "):\n")
for (table in head(sps_tables, 10)) {
  cat("  -", table, "\n")
}
if (length(sps_tables) > 10) cat("  ... and", length(sps_tables) - 10, "more\n")

cat("\nSAS tables (", length(sas_tables), "):\n")
for (table in head(sas_tables, 10)) {
  cat("  -", table, "\n")
}
if (length(sas_tables) > 10) cat("  ... and", length(sas_tables) - 10, "more\n")

cat("\nStata tables (", length(stata_tables), "):\n")
for (table in head(stata_tables, 10)) {
  cat("  -", table, "\n")
}
if (length(stata_tables) > 10) cat("  ... and", length(stata_tables) - 10, "more\n")

cat("\nData_Stata tables (", length(data_stata_tables), "):\n")
for (table in head(data_stata_tables, 10)) {
  cat("  -", table, "\n")
}
if (length(data_stata_tables) > 10) cat("  ... and", length(data_stata_tables) - 10, "more\n")

if (length(duplicate_tables) > 0) {
  
  cat("\n" , paste(rep("=", 60), collapse=""), "\n")
  cat("REMOVING", length(duplicate_tables), "DUPLICATE STATISTICAL SOFTWARE TABLES\n")
  cat(paste(rep("=", 60), collapse=""), "\n\n")
  
  success_count <- 0
  error_count <- 0
  
  for (table in duplicate_tables) {
    tryCatch({
      DBI::dbExecute(con, paste0("DROP TABLE IF EXISTS \"", table, "\""))
      cat("  ✓ Removed:", table, "\n")
      success_count <- success_count + 1
    }, error = function(e) {
      cat("  ✗ Error removing", table, ":", e$message, "\n")
      error_count <- error_count + 1
    })
  }
  
  cat("\n", paste(rep("=", 60), collapse=""), "\n")
  cat("CLEANUP COMPLETE!\n")
  cat("  Successfully removed:", success_count, "tables\n")
  cat("  Errors:", error_count, "tables\n")
  cat(paste(rep("=", 60), collapse=""), "\n\n")
  
  # Show final table count
  remaining_tables <- DBI::dbListTables(con)
  cat("Database now has", length(remaining_tables), "tables\n")
  
  # Show some example remaining 2023 tables (should only be CSV versions)
  regular_2023_tables <- remaining_tables[grepl("2023", remaining_tables) & 
                                          !grepl("_(SPS|SAS|Stata|Data_Stata)$", remaining_tables) &
                                          !grepl("^(Tables|vartable|valuesets)", remaining_tables)]
  cat("\n2023 data tables (regular CSV only, first 10):\n")
  for (table in head(regular_2023_tables, 10)) {
    cat("  -", table, "\n")
  }
  if (length(regular_2023_tables) > 10) {
    cat("  ... and", length(regular_2023_tables) - 10, "more 2023 tables\n")
  }
  
} else {
  cat("No statistical software tables found to remove.\n")
}

# Disconnect
DBI::dbDisconnect(con)
cat("\nDatabase connection closed.\n")