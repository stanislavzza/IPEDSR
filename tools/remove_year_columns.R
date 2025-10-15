# Simple Fix: Remove YEAR columns from all tables and re-add them properly
# This is the fastest way to fix the column naming issue

library(DBI)
library(duckdb)

cat("========================================\n")
cat("REMOVING YEAR COLUMNS FOR CLEAN RE-ADD\n")
cat("========================================\n\n")

# Connect to database
db_path <- file.path(rappdirs::user_data_dir("IPEDSR"), "ipeds_2004-2023.duckdb")
con <- dbConnect(duckdb::duckdb(), db_path, read_only = FALSE)

# Get all tables
all_tables <- dbListTables(con)
data_tables <- all_tables[!grepl("^(ipeds_|sqlite_|Tables|vartable|valuesets)", all_tables)]

cat("Removing YEAR columns from", length(data_tables), "tables...\n\n")

removed <- 0

for (i in seq_along(data_tables)) {
  table_name <- data_tables[i]
  
  if (i == 1 || i == length(data_tables) || i %% 50 == 0) {
    cat("Processing table", i, "/", length(data_tables), ":", table_name, "\n")
  }
  
  tryCatch({
    # Read table
    data <- dbReadTable(con, table_name)
    
    # Check if YEAR column exists
    if ("YEAR" %in% names(data)) {
      # Remove YEAR column
      data <- data[, names(data) != "YEAR", drop = FALSE]
      
      # Write back
      dbWriteTable(con, table_name, data, overwrite = TRUE)
      
      removed <- removed + 1
    }
    
  }, error = function(e) {
    cat("  Error processing", table_name, ":", e$message, "\n")
  })
}

dbDisconnect(con, shutdown = TRUE)

cat("\n========================================\n")
cat("REMOVAL COMPLETE\n")
cat("========================================\n")
cat("YEAR columns removed from", removed, "tables\n\n")

cat("Now run in R:\n")
cat("  library(IPEDSR)\n")
cat("  add_year_columns_to_database()\n\n")
cat("This will re-add YEAR columns with proper names.\n")
