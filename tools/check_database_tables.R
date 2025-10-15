#!/usr/bin/env Rscript
# Check what tables are actually in the database

library(DBI)
library(duckdb)

# Get database path
get_ipeds_db_path <- function() {
  data_dir <- rappdirs::user_data_dir("IPEDSR", "FurmanIR")
  file.path(data_dir, "ipeds_2004-2023.duckdb")
}

con <- DBI::dbConnect(duckdb::duckdb(), get_ipeds_db_path())

# Get all table names
all_tables <- DBI::dbListTables(con)

cat("Total tables in database:", length(all_tables), "\n\n")

# Look for 2023 tables
tables_2023 <- grep("2023", all_tables, value = TRUE)
cat("2023 tables found:", length(tables_2023), "\n")

# Look for various patterns
sps_pattern <- grep("_SPS", all_tables, value = TRUE)
sas_pattern <- grep("_SAS", all_tables, value = TRUE) 
stata_pattern <- grep("_Stata", all_tables, value = TRUE)
data_stata_pattern <- grep("_Data_Stata", all_tables, value = TRUE)

cat("Tables with _SPS:", length(sps_pattern), "\n")
cat("Tables with _SAS:", length(sas_pattern), "\n")
cat("Tables with _Stata:", length(stata_pattern), "\n") 
cat("Tables with _Data_Stata:", length(data_stata_pattern), "\n")

cat("\nFirst 10 2023 tables:\n")
for (table in head(tables_2023, 10)) {
  cat("  -", table, "\n")
}

# Check for failed imports
cat("\nLast 20 tables in alphabetical order:\n")
sorted_tables <- sort(all_tables)
for (table in tail(sorted_tables, 20)) {
  cat("  -", table, "\n")
}

DBI::dbDisconnect(con)