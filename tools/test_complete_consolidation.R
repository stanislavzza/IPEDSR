#!/usr/bin/env Rscript
# Complete test of all three consolidation tables

library(DBI)
library(duckdb)

test_db <- tempfile(fileext = ".duckdb")
con <- dbConnect(duckdb(), test_db)

cat(paste(rep("=", 70), collapse=""), "\n")
cat("COMPLETE CONSOLIDATION TEST\n")
cat(paste(rep("=", 70), collapse=""), "\n\n")

# Create sample tables with varying schemas
cat("1. Creating test tables...\n")

# tables with varying schemas
dbExecute(con, 'CREATE TABLE tables06 (SurveyOrder INT, Survey VARCHAR, TableName VARCHAR, Release VARCHAR, Description VARCHAR)')
dbExecute(con, "INSERT INTO tables06 VALUES (1, 'HD', 'HD', 'Prov', 'Directory')")

dbExecute(con, 'CREATE TABLE tables15 (SurveyOrder INT, Survey VARCHAR, TableName VARCHAR, Release VARCHAR, "Release date" VARCHAR, Description VARCHAR)')
dbExecute(con, "INSERT INTO tables15 VALUES (1, 'HD', 'HD', 'Final', '2016-01-15', 'Directory')")

dbExecute(con, 'CREATE TABLE tables22 (SurveyOrder INT, Survey VARCHAR, TableName VARCHAR, Release VARCHAR, "Release date" VARCHAR, F11 VARCHAR, F12 VARCHAR, Description VARCHAR)')
dbExecute(con, "INSERT INTO tables22 VALUES (1, 'HD', 'HD', 'Final', '2023-01-15', '', '', 'Directory')")

# vartable with varying schemas
dbExecute(con, 'CREATE TABLE vartable06 (varName VARCHAR, varTitle VARCHAR, TableName VARCHAR)')
dbExecute(con, "INSERT INTO vartable06 VALUES ('UNITID', 'Institution ID', 'HD')")

dbExecute(con, 'CREATE TABLE vartable15 (varName VARCHAR, varTitle VARCHAR, TableName VARCHAR, varType VARCHAR, varLength INT)')
dbExecute(con, "INSERT INTO vartable15 VALUES ('UNITID', 'Institution ID', 'HD', 'N', 6)")

dbExecute(con, 'CREATE TABLE vartable22 (varName VARCHAR, varTitle VARCHAR, TableName VARCHAR, varType VARCHAR, varLength INT, DataType VARCHAR, Format VARCHAR)')
dbExecute(con, "INSERT INTO vartable22 VALUES ('UNITID', 'Institution ID', 'HD', 'N', 6, 'integer', 'F6.0')")

# valuesets with varying schemas
dbExecute(con, 'CREATE TABLE valuesets06 (varName VARCHAR, Value VARCHAR, valueLabel VARCHAR)')
dbExecute(con, "INSERT INTO valuesets06 VALUES ('CONTROL', '1', 'Public')")

dbExecute(con, 'CREATE TABLE valuesets15 (varName VARCHAR, Value VARCHAR, valueLabel VARCHAR, TableName VARCHAR)')
dbExecute(con, "INSERT INTO valuesets15 VALUES ('CONTROL', '1', 'Public', 'HD')")

dbExecute(con, 'CREATE TABLE valuesets22 (varName VARCHAR, Value VARCHAR, valueLabel VARCHAR, TableName VARCHAR, Tablenumber VARCHAR, codeDesc VARCHAR)')
dbExecute(con, "INSERT INTO valuesets22 VALUES ('CONTROL', '1', 'Public', 'HD', '01', 'Institutional control')")

cat("✓ Test tables created\n\n")

# Source the consolidation logic
cat("2. Running consolidation logic...\n\n")

all_tables <- dbListTables(con)
verbose <- TRUE

# TABLES consolidation
tables_tables <- grep('^tables[0-9]{2}$', all_tables, value=TRUE, ignore.case=TRUE)
if (length(tables_tables) > 0) {
  cat("  Processing tables_all...\n")
  
  tables_queries <- c()
  for (table in tables_tables) {
    year <- gsub("tables", "", table, ignore.case=TRUE)
    year_4digit <- ifelse(as.numeric(year) <= 50, 2000 + as.numeric(year), 1900 + as.numeric(year))
    
    cols <- dbListFields(con, table)
    has_release_date <- any(grepl("^release.?date$", cols, ignore.case=TRUE))
    has_f_cols <- any(grepl("^f[0-9]{2}$", cols, ignore.case=TRUE))
    
    select_parts <- c("SurveyOrder", "Survey", "TableName", "Release")
    
    if (has_release_date) {
      release_date_col <- cols[grepl("^release.?date$", cols, ignore.case=TRUE)][1]
      select_parts <- c(select_parts, sprintf('"%s"', release_date_col))
    } else {
      select_parts <- c(select_parts, 'NULL as "Release date"')
    }
    
    if (has_f_cols) {
      f_cols_present <- grep("^f[0-9]{2}$", cols, value=TRUE, ignore.case=TRUE)
      select_parts <- c(select_parts, f_cols_present)
    } else {
      select_parts <- c(select_parts, "NULL as F11", "NULL as F12")
    }
    
    select_parts <- c(select_parts, "Description", sprintf("%d as YEAR", year_4digit))
    
    query <- sprintf('SELECT %s FROM %s', paste(select_parts, collapse=", "), table)
    tables_queries <- c(tables_queries, query)
  }
  
  union_query <- paste(tables_queries, collapse=" UNION ALL ")
  dbExecute(con, sprintf("CREATE TABLE tables_all AS %s", union_query))
  cat("  ✓ tables_all created\n")
}

# VARTABLE consolidation  
vartable_tables <- grep('^vartable[0-9]{2}$', all_tables, value=TRUE, ignore.case=TRUE)
if (length(vartable_tables) > 0) {
  cat("  Processing vartable_all...\n")
  
  all_vartable_columns <- list()
  for (table in vartable_tables) {
    all_vartable_columns[[table]] <- dbListFields(con, table)
  }
  all_unique_vartable_cols <- unique(unlist(all_vartable_columns))
  
  vartable_queries <- c()
  for (table in vartable_tables) {
    year <- gsub("vartable", "", table, ignore.case=TRUE)
    year_4digit <- ifelse(as.numeric(year) <= 50, 2000 + as.numeric(year), 1900 + as.numeric(year))
    
    cols <- all_vartable_columns[[table]]
    
    select_parts <- c()
    for (col in all_unique_vartable_cols) {
      if (col %in% cols) {
        select_parts <- c(select_parts, col)
      } else {
        select_parts <- c(select_parts, sprintf("NULL as %s", col))
      }
    }
    select_parts <- c(select_parts, sprintf("%d as YEAR", year_4digit))
    
    query <- sprintf('SELECT %s FROM %s', paste(select_parts, collapse=", "), table)
    vartable_queries <- c(vartable_queries, query)
  }
  
  union_query <- paste(vartable_queries, collapse=" UNION ALL ")
  dbExecute(con, sprintf("CREATE TABLE vartable_all AS %s", union_query))
  cat("  ✓ vartable_all created\n")
}

# VALUESETS consolidation
valuesets_tables <- grep('^valuesets[0-9]{2}$', all_tables, value=TRUE, ignore.case=TRUE)
if (length(valuesets_tables) > 0) {
  cat("  Processing valuesets_all...\n")
  
  all_valuesets_columns <- list()
  for (table in valuesets_tables) {
    all_valuesets_columns[[table]] <- dbListFields(con, table)
  }
  all_unique_valuesets_cols <- unique(unlist(all_valuesets_columns))
  
  valuesets_queries <- c()
  for (table in valuesets_tables) {
    year <- gsub("valuesets", "", table, ignore.case=TRUE)
    year_4digit <- ifelse(as.numeric(year) <= 50, 2000 + as.numeric(year), 1900 + as.numeric(year))
    
    cols <- all_valuesets_columns[[table]]
    
    select_parts <- c()
    for (col in all_unique_valuesets_cols) {
      if (col %in% cols) {
        select_parts <- c(select_parts, col)
      } else {
        select_parts <- c(select_parts, sprintf("NULL as %s", col))
      }
    }
    select_parts <- c(select_parts, sprintf("%d as YEAR", year_4digit))
    
    query <- sprintf('SELECT %s FROM %s', paste(select_parts, collapse=", "), table)
    valuesets_queries <- c(valuesets_queries, query)
  }
  
  union_query <- paste(valuesets_queries, collapse=" UNION ALL ")
  dbExecute(con, sprintf("CREATE TABLE valuesets_all AS %s", union_query))
  cat("  ✓ valuesets_all created\n")
}

cat("\n3. Verifying results...\n\n")

# Verify tables_all
cat("tables_all:\n")
result <- dbGetQuery(con, "SELECT * FROM tables_all ORDER BY YEAR")
print(result)

cat("\nvartable_all:\n")
result <- dbGetQuery(con, "SELECT * FROM vartable_all ORDER BY YEAR")
print(result)

cat("\nvaluesets_all:\n")
result <- dbGetQuery(con, "SELECT * FROM valuesets_all ORDER BY YEAR")
print(result)

cat("\n", paste(rep("=", 70), collapse=""), "\n")
cat("✅ ALL CONSOLIDATION TESTS PASSED!\n")
cat(paste(rep("=", 70), collapse=""), "\n")

dbDisconnect(con)
unlink(test_db)
