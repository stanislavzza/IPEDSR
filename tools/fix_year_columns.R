# Fix YEAR column format in consolidated tables
# Convert from 2-character strings ("23") to 4-digit integers (2023)

library(DBI)
source("R/database_management.R")

# Connect to database
con <- get_ipeds_connection(read_only = FALSE)

cat("Fixing YEAR column format in consolidated tables...\n")
cat("==========================================================\n")

# Function to convert 2-digit year string to 4-digit integer
# Assumes years 00-50 are 2000s, 51-99 are 1900s (adjust as needed)
convert_year <- function(year_str) {
  year_int <- as.integer(year_str)
  if (year_int <= 50) {
    return(2000 + year_int)
  } else {
    return(1900 + year_int)
  }
}

# 1. Fix Tables_All YEAR column
cat("1. Updating Tables_All YEAR column...\n")

# Get current year values to see what we're working with
current_years <- dbGetQuery(con, "SELECT DISTINCT YEAR FROM Tables_All ORDER BY YEAR")
cat("Current YEAR values in Tables_All:", paste(current_years$YEAR, collapse=", "), "\n")

# Update Tables_All with proper 4-digit years
dbExecute(con, "
UPDATE Tables_All 
SET YEAR = CASE 
  WHEN CAST(YEAR AS INTEGER) <= 50 THEN 2000 + CAST(YEAR AS INTEGER)
  ELSE 1900 + CAST(YEAR AS INTEGER)
END
")

# Verify the update
updated_years <- dbGetQuery(con, "SELECT DISTINCT YEAR FROM Tables_All ORDER BY YEAR")
cat("Updated YEAR values in Tables_All:", paste(updated_years$YEAR, collapse=", "), "\n")

# 2. Fix vartable_All YEAR column
cat("\n2. Updating vartable_All YEAR column...\n")

current_years <- dbGetQuery(con, "SELECT DISTINCT YEAR FROM vartable_All ORDER BY YEAR")
cat("Current YEAR values in vartable_All:", paste(current_years$YEAR, collapse=", "), "\n")

dbExecute(con, "
UPDATE vartable_All 
SET YEAR = CASE 
  WHEN CAST(YEAR AS INTEGER) <= 50 THEN 2000 + CAST(YEAR AS INTEGER)
  ELSE 1900 + CAST(YEAR AS INTEGER)
END
")

updated_years <- dbGetQuery(con, "SELECT DISTINCT YEAR FROM vartable_All ORDER BY YEAR")
cat("Updated YEAR values in vartable_All:", paste(updated_years$YEAR, collapse=", "), "\n")

# 3. Fix valuesets_All YEAR column  
cat("\n3. Updating valuesets_All YEAR column...\n")

current_years <- dbGetQuery(con, "SELECT DISTINCT YEAR FROM valuesets_All ORDER BY YEAR")
cat("Current YEAR values in valuesets_All:", paste(current_years$YEAR, collapse=", "), "\n")

dbExecute(con, "
UPDATE valuesets_All 
SET YEAR = CASE 
  WHEN CAST(YEAR AS INTEGER) <= 50 THEN 2000 + CAST(YEAR AS INTEGER)
  ELSE 1900 + CAST(YEAR AS INTEGER)
END
")

updated_years <- dbGetQuery(con, "SELECT DISTINCT YEAR FROM valuesets_All ORDER BY YEAR")
cat("Updated YEAR values in valuesets_All:", paste(updated_years$YEAR, collapse=", "), "\n")

# 4. Change YEAR column data type to INTEGER
cat("\n4. Converting YEAR columns to INTEGER data type...\n")

# For Tables_All
dbExecute(con, "ALTER TABLE Tables_All ALTER COLUMN YEAR TYPE INTEGER")
cat("Tables_All YEAR column converted to INTEGER\n")

# For vartable_All  
dbExecute(con, "ALTER TABLE vartable_All ALTER COLUMN YEAR TYPE INTEGER")
cat("vartable_All YEAR column converted to INTEGER\n")

# For valuesets_All
dbExecute(con, "ALTER TABLE valuesets_All ALTER COLUMN YEAR TYPE INTEGER") 
cat("valuesets_All YEAR column converted to INTEGER\n")

# 5. Verification and examples
cat("\n==========================================================\n")
cat("YEAR COLUMN FIX COMPLETE!\n")
cat("==========================================================\n")

# Verify the changes with sample queries
cat("Sample queries showing proper 4-digit years:\n\n")

cat("Tables_All sample:\n")
sample <- dbGetQuery(con, "SELECT TableName, TableTitle, YEAR FROM Tables_All WHERE YEAR IN (2006, 2023, 2024) ORDER BY YEAR, TableName LIMIT 5")
print(sample)

cat("\nvartable_All sample:\n")
sample <- dbGetQuery(con, "SELECT varName, varTitle, YEAR FROM vartable_All WHERE YEAR IN (2006, 2023, 2024) AND varTitle IS NOT NULL ORDER BY YEAR, varName LIMIT 5")
print(sample)

cat("\nvaluesets_All sample:\n")
sample <- dbGetQuery(con, "SELECT varName, valueLabel, YEAR FROM valuesets_All WHERE YEAR IN (2006, 2023, 2024) AND valueLabel IS NOT NULL ORDER BY YEAR, varName LIMIT 5")
print(sample)

# Show year range coverage
cat("\nYear coverage summary:\n")
tables_range <- dbGetQuery(con, "SELECT MIN(YEAR) as min_year, MAX(YEAR) as max_year, COUNT(DISTINCT YEAR) as year_count FROM Tables_All")
cat("Tables_All covers", tables_range$year_count, "years from", tables_range$min_year, "to", tables_range$max_year, "\n")

vartable_range <- dbGetQuery(con, "SELECT MIN(YEAR) as min_year, MAX(YEAR) as max_year, COUNT(DISTINCT YEAR) as year_count FROM vartable_All")
cat("vartable_All covers", vartable_range$year_count, "years from", vartable_range$min_year, "to", vartable_range$max_year, "\n")

valuesets_range <- dbGetQuery(con, "SELECT MIN(YEAR) as min_year, MAX(YEAR) as max_year, COUNT(DISTINCT YEAR) as year_count FROM valuesets_All")
cat("valuesets_All covers", valuesets_range$year_count, "years from", valuesets_range$min_year, "to", valuesets_range$max_year, "\n")

# Example queries that are now possible
cat("\nExample queries now possible:\n")
cat("- SELECT * FROM Tables_All WHERE YEAR >= 2020\n")
cat("- SELECT * FROM vartable_All WHERE YEAR BETWEEN 2010 AND 2015\n") 
cat("- SELECT varName, COUNT(*) FROM vartable_All WHERE YEAR < 2010 GROUP BY varName\n")
cat("- SELECT YEAR, COUNT(*) FROM Tables_All GROUP BY YEAR ORDER BY YEAR\n")

dbDisconnect(con)
cat("\nYEAR columns are now proper 4-digit integers!\n")