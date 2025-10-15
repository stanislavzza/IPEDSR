#!/usr/bin/env Rscript
# Check vartable schemas to understand variation

library(DBI)
library(duckdb)

# Create test database with sample vartable schemas
test_db <- tempfile(fileext = ".duckdb")
con <- dbConnect(duckdb(), test_db)

cat("Creating test vartable tables with different schemas...\n\n")

# vartable06 - early format (fewer columns)
dbExecute(con, 'CREATE TABLE vartable06 (
  varName VARCHAR,
  varTitle VARCHAR,
  TableName VARCHAR,
  Tablenumber VARCHAR
)')
dbExecute(con, "INSERT INTO vartable06 VALUES ('UNITID', 'Institution ID', 'HD', '01')")
dbExecute(con, "INSERT INTO vartable06 VALUES ('INSTNM', 'Institution Name', 'HD', '01')")

# vartable15 - mid format (added columns)
dbExecute(con, 'CREATE TABLE vartable15 (
  varName VARCHAR,
  varTitle VARCHAR,
  TableName VARCHAR,
  Tablenumber VARCHAR,
  varType VARCHAR,
  varLength INTEGER
)')
dbExecute(con, "INSERT INTO vartable15 VALUES ('UNITID', 'Institution ID', 'HD', '01', 'N', 6)")
dbExecute(con, "INSERT INTO vartable15 VALUES ('INSTNM', 'Institution Name', 'HD', '01', 'A', 100)")

# vartable22 - later format (even more columns)
dbExecute(con, 'CREATE TABLE vartable22 (
  varName VARCHAR,
  varTitle VARCHAR,
  TableName VARCHAR,
  Tablenumber VARCHAR,
  varType VARCHAR,
  varLength INTEGER,
  DataType VARCHAR,
  Format VARCHAR
)')
dbExecute(con, "INSERT INTO vartable22 VALUES ('UNITID', 'Institution ID', 'HD', '01', 'N', 6, 'integer', 'F6.0')")
dbExecute(con, "INSERT INTO vartable22 VALUES ('INSTNM', 'Institution Name', 'HD', '01', 'A', 100, 'varchar', 'A100')")

cat("Test table schemas:\n")
for (tbl in c("vartable06", "vartable15", "vartable22")) {
  cols <- dbListFields(con, tbl)
  cat(sprintf("  %s: %s\n", tbl, paste(cols, collapse=", ")))
}

cat("\nAttempting naive UNION with SELECT *...\n")
tryCatch({
  dbExecute(con, "CREATE TABLE test_union AS 
    SELECT *, 2006 as YEAR FROM vartable06
    UNION ALL
    SELECT *, 2015 as YEAR FROM vartable15
    UNION ALL
    SELECT *, 2022 as YEAR FROM vartable22")
  cat("✓ Success!\n")
}, error = function(e) {
  cat("✗ ERROR:", conditionMessage(e), "\n")
  cat("\nThis is expected - different column counts!\n")
})

cat("\nSolution: Find common columns across all tables\n\n")

# Get all vartable tables
all_tables <- dbListTables(con)
vartable_tables <- grep('^vartable[0-9]{2}$', all_tables, value=TRUE, ignore.case=TRUE)

# Collect all unique columns
all_columns <- list()
for (table in vartable_tables) {
  cols <- dbListFields(con, table)
  all_columns[[table]] <- cols
  cat(sprintf("%s has %d columns: %s\n", table, length(cols), paste(cols, collapse=", ")))
}

# Find common columns (present in ALL tables)
common_cols <- Reduce(intersect, all_columns)
cat(sprintf("\nCommon columns across all tables: %s\n", paste(common_cols, collapse=", ")))

# Find all unique columns (present in ANY table)
all_unique_cols <- unique(unlist(all_columns))
cat(sprintf("All unique columns: %s\n", paste(all_unique_cols, collapse=", ")))

cat("\nApproach: Select common columns + NULL for missing ones\n\n")

# Build queries with NULL placeholders
vartable_queries <- c()
for (table in vartable_tables) {
  year <- gsub("vartable", "", table, ignore.case = TRUE)
  year_4digit <- ifelse(as.numeric(year) <= 50, 2000 + as.numeric(year), 1900 + as.numeric(year))
  
  cols <- dbListFields(con, table)
  
  # Build SELECT list with all columns, using NULL where missing
  select_parts <- c()
  for (col in all_unique_cols) {
    if (col %in% cols) {
      select_parts <- c(select_parts, col)
    } else {
      select_parts <- c(select_parts, sprintf("NULL as %s", col))
    }
  }
  select_parts <- c(select_parts, sprintf("%d as YEAR", year_4digit))
  
  query <- sprintf('SELECT %s FROM %s', paste(select_parts, collapse=", "), table)
  cat(sprintf("%s query:\n  %s\n\n", table, query))
  vartable_queries <- c(vartable_queries, query)
}

cat("Attempting UNION with NULL placeholders...\n")
tryCatch({
  union_query <- paste(vartable_queries, collapse=" UNION ALL ")
  dbExecute(con, sprintf("CREATE TABLE vartable_all AS %s", union_query))
  
  result <- dbGetQuery(con, "SELECT * FROM vartable_all ORDER BY YEAR, varName")
  cat("✓ Success! Created vartable_all\n\n")
  print(result)
  
  cat("\n✅ This approach works for varying schemas!\n")
}, error = function(e) {
  cat("✗ ERROR:", conditionMessage(e), "\n")
})

dbDisconnect(con)
unlink(test_db)

cat("\nTest complete!\n")
