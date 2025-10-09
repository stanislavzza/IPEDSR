# Cleanup duplicate Stata tables from IPEDS database
# Run this from within RStudio where the database connection is active

# If you have a connection open, use it. Otherwise create one:
if (!exists("con") || !DBI::dbIsValid(con)) {
  library(DBI)
  library(duckdb)
  
  get_ipeds_db_path <- function() {
    data_dir <- rappdirs::user_data_dir("IPEDSR", "FurmanIR")
    file.path(data_dir, "ipeds_2004-2023.duckdb")
  }
  
  con <- DBI::dbConnect(duckdb::duckdb(), get_ipeds_db_path())
  should_disconnect <- TRUE
} else {
  should_disconnect <- FALSE
}

# Get all table names
all_tables <- DBI::dbListTables(con)

# Find Stata tables (ending with _Data_Stata)
stata_tables <- grep("_Data_Stata$", all_tables, value = TRUE)

cat("Found", length(stata_tables), "Stata tables to remove:\n")
for (table in stata_tables) {
  cat("  -", table, "\n")
}

if (length(stata_tables) > 0) {
  
  response <- readline(paste0("Remove ", length(stata_tables), " duplicate Stata tables? (yes/no): "))
  
  if (tolower(response) == "yes") {
    cat("\nRemoving duplicate Stata tables...\n")
    
    for (table in stata_tables) {
      tryCatch({
        DBI::dbExecute(con, paste0("DROP TABLE IF EXISTS \"", table, "\""))
        cat("  ✓ Removed:", table, "\n")
      }, error = function(e) {
        cat("  ✗ Error removing", table, ":", e$message, "\n")
      })
    }
    
    cat("\nCleanup complete!\n")
    
    # Show final table count
    remaining_tables <- DBI::dbListTables(con)
    cat("Database now has", length(remaining_tables), "tables\n")
    
    # Show some example remaining tables
    regular_2024_tables <- remaining_tables[grepl("2024", remaining_tables) & !grepl("_Data_Stata", remaining_tables)]
    cat("2024 tables (without Stata duplicates):\n")
    for (table in head(regular_2024_tables, 10)) {
      cat("  -", table, "\n")
    }
    
  } else {
    cat("Cleanup cancelled.\n")
  }
  
} else {
  cat("No Stata tables found to remove.\n")
}

# Only disconnect if we created the connection
if (should_disconnect) {
  DBI::dbDisconnect(con)
  cat("Database connection closed.\n")
}