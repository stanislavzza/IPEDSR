#!/usr/bin/env Rscript
# Test script for schema detection fix in consolidation

library(DBI)
library(duckdb)

# Create a test database with varying schemas
test_db <- tempfile(fileext = ".duckdb")
con <- dbConnect(duckdb(), test_db)

cat("Creating test tables with different schemas...\n")

# Create tables06 - early format without "Release date" 
dbExecute(con, 'CREATE TABLE tables06 (
  SurveyOrder INTEGER,
  SurveyNumber VARCHAR,
  Survey VARCHAR,
  YearCoverage VARCHAR,
  TableName VARCHAR,
  Tablenumber VARCHAR,
  TableTitle VARCHAR,
  Release VARCHAR,
  Description VARCHAR
)')
dbExecute(con, "INSERT INTO tables06 VALUES (1, 'HD', 'Directory', '2006', 'HD', '01', 'Directory Info', 'Provisional', 'Institution characteristics')")

# Create tables15 - format WITH "Release date" but few columns
dbExecute(con, 'CREATE TABLE tables15 (
  SurveyOrder INTEGER,
  SurveyNumber VARCHAR,
  Survey VARCHAR,
  YearCoverage VARCHAR,
  TableName VARCHAR,
  Tablenumber VARCHAR,
  TableTitle VARCHAR,
  Release VARCHAR,
  "Release date" VARCHAR,
  Description VARCHAR
)')
dbExecute(con, "INSERT INTO tables15 VALUES (1, 'HD', 'Directory', '2015', 'HD', '01', 'Directory Info', 'Final', '2016-01-15', 'Institution characteristics')")

# Create tables22 - later format WITH "Release date" AND F columns
dbExecute(con, 'CREATE TABLE tables22 (
  SurveyOrder INTEGER,
  SurveyNumber VARCHAR,
  Survey VARCHAR,
  YearCoverage VARCHAR,
  TableName VARCHAR,
  Tablenumber VARCHAR,
  TableTitle VARCHAR,
  Release VARCHAR,
  "Release date" VARCHAR,
  F11 VARCHAR,
  F12 VARCHAR,
  F13 VARCHAR,
  F14 VARCHAR,
  F15 VARCHAR,
  F16 VARCHAR,
  Description VARCHAR
)')
dbExecute(con, "INSERT INTO tables22 VALUES (1, 'HD', 'Directory', '2022', 'HD', '01', 'Directory Info', 'Final', '2023-01-15', '', '', '', '', '', '', 'Institution characteristics')")

cat("\nTest table schemas:\n")
cat("tables06 columns:", paste(dbListFields(con, "tables06"), collapse=", "), "\n")
cat("tables15 columns:", paste(dbListFields(con, "tables15"), collapse=", "), "\n")
cat("tables22 columns:", paste(dbListFields(con, "tables22"), collapse=", "), "\n")

cat("\nTesting consolidation with new schema detection logic...\n")

# Test the new logic
all_tables <- dbListTables(con)
tables_tables <- grep('^tables[0-9]{2}$', all_tables, value = TRUE, ignore.case = TRUE)

tables_queries <- c()
for (table in tables_tables) {
  year <- gsub("tables", "", table, ignore.case = TRUE)
  year_4digit <- ifelse(as.numeric(year) <= 50, 2000 + as.numeric(year), 1900 + as.numeric(year))
  
  # Get actual column names for this table
  cols <- dbListFields(con, table)
  
  cat(sprintf("  Processing %s (year %d): %d columns\n", table, year_4digit, length(cols)))
  
  # Check which optional columns exist
  has_release_date <- any(grepl("^release.?date$", cols, ignore.case = TRUE))
  has_f_cols <- any(grepl("^f[0-9]{2}$", cols, ignore.case = TRUE))
  
  cat(sprintf("    Has 'Release date': %s\n", has_release_date))
  cat(sprintf("    Has F columns: %s\n", has_f_cols))
  
  # Build SELECT clause based on available columns
  select_parts <- c(
    "SurveyOrder", "SurveyNumber", "Survey", "YearCoverage",
    "TableName", "Tablenumber", "TableTitle", "Release"
  )
  
  # Add "Release date" if it exists, otherwise NULL
  if (has_release_date) {
    release_date_col <- cols[grepl("^release.?date$", cols, ignore.case = TRUE)][1]
    select_parts <- c(select_parts, sprintf('"%s"', release_date_col))
  } else {
    select_parts <- c(select_parts, "NULL as \"Release date\"")
  }
  
  # Add F11-F16 if they exist, otherwise NULL
  if (has_f_cols) {
    select_parts <- c(select_parts, "F11", "F12", "F13", "F14", "F15", "F16")
  } else {
    select_parts <- c(select_parts, 
                     "NULL as F11", "NULL as F12", "NULL as F13", 
                     "NULL as F14", "NULL as F15", "NULL as F16")
  }
  
  # Add Description and YEAR
  select_parts <- c(select_parts, "Description", sprintf("%d as YEAR", year_4digit))
  
  # Build query
  query <- sprintf('SELECT %s FROM %s', 
                  paste(select_parts, collapse = ", "), 
                  table)
  
  tables_queries <- c(tables_queries, query)
}

cat("\nExecuting UNION ALL query...\n")
union_query <- paste(tables_queries, collapse=" UNION ALL ")
tryCatch({
  dbExecute(con, sprintf("CREATE TABLE tables_all AS %s", union_query))
  cat("✓ Successfully created tables_all!\n")
  
  # Verify the result
  result <- dbGetQuery(con, "SELECT * FROM tables_all ORDER BY YEAR")
  cat("\nConsolidated table contents:\n")
  print(result)
  
  cat("\n✓ Schema detection fix is working correctly!\n")
  cat("  - tables06 (no 'Release date'): used NULL placeholder\n")
  cat("  - tables15 ('Release date' present): used actual column\n")
  cat("  - tables22 ('Release date' + F cols): used all columns\n")
  
}, error = function(e) {
  cat("✗ Error during consolidation:\n")
  cat(conditionMessage(e), "\n")
})

dbDisconnect(con)
unlink(test_db)

cat("\nTest complete!\n")
