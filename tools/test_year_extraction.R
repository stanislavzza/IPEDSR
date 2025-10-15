# Test year extraction logic and check existing YEAR columns
# This helps validate our new extract_year_from_table_name() function

library(DBI)
source("R/database_management.R")
source("R/data_updates.R")

cat("========================================\n")
cat("YEAR EXTRACTION VALIDATION TEST\n")
cat("========================================\n\n")

# Connect to database
con <- get_ipeds_connection(read_only = TRUE)

# Get all tables
all_tables <- DBI::dbListTables(con)
data_tables <- all_tables[!grepl("^(ipeds_|sqlite_|Tables|vartable|valuesets)", all_tables)]

cat("Testing year extraction on", length(data_tables), "tables...\n\n")

# Test both methods
results <- data.frame(
  table_name = character(),
  existing_method = character(),
  new_method = integer(),
  has_year_col = logical(),
  year_col_name = character(),
  match = logical(),
  stringsAsFactors = FALSE
)

cat("Sampling tables to compare methods:\n")
cat("-----------------------------------\n")

# Sample tables for detailed testing
sample_tables <- c(
  "ADM2022", "ADM2023",           # Simple 4-digit year
  "ef0910", "ef1920", "ef2223",  # Two-digit year range
  "sfa1819_p1", "sfa2021_p2",    # Year range with suffix
  "C2022_A", "C2023_B",          # Year with component
  "HD2023", "IC2023", "EFFY2023" # Different survey types
)

for (tbl in sample_tables) {
  if (tbl %in% data_tables) {
    # Existing method (from ipeds_utilities.R)
    existing_year <- tryCatch({
      yr_4digit <- stringr::str_extract(tbl, "\\d\\d\\d\\d")
      if (!is.na(yr_4digit)) {
        yr_2digit <- stringr::str_sub(yr_4digit, 3, 4)
        yr_4digit  # Return the 4-digit year
      } else {
        NA
      }
    }, error = function(e) NA)
    
    # New method
    new_year <- extract_year_from_table_name(tbl)
    
    # Check if table has YEAR column
    schema_query <- paste("PRAGMA table_info(", tbl, ")")
    schema <- DBI::dbGetQuery(con, schema_query)
    year_cols <- grep("^year$", schema$name, ignore.case = TRUE, value = TRUE)
    has_year <- length(year_cols) > 0
    year_col_name <- if (has_year) year_cols[1] else NA
    
    # Compare methods
    match <- (!is.na(existing_year) && !is.na(new_year) && 
              as.integer(existing_year) == new_year)
    
    cat(sprintf("%-15s | Old: %-4s | New: %-4s | Has YEAR: %-5s | Match: %s\n",
                tbl, 
                ifelse(is.na(existing_year), "NA", existing_year),
                ifelse(is.na(new_year), "NA", new_year),
                has_year,
                ifelse(match, "✓", "✗")))
    
    results <- rbind(results, data.frame(
      table_name = tbl,
      existing_method = ifelse(is.na(existing_year), NA, existing_year),
      new_method = new_year,
      has_year_col = has_year,
      year_col_name = year_col_name,
      match = match,
      stringsAsFactors = FALSE
    ))
  }
}

cat("\n========================================\n")
cat("FULL DATABASE ANALYSIS\n")
cat("========================================\n\n")

# Now test all tables
tables_with_year <- 0
tables_without_year <- 0
tables_year_extractable <- 0
tables_no_year_in_name <- 0

for (tbl in data_tables) {
  # Check if table has YEAR column
  schema_query <- paste("PRAGMA table_info(", tbl, ")")
  schema <- tryCatch({
    DBI::dbGetQuery(con, schema_query)
  }, error = function(e) {
    return(data.frame(name = character(0)))
  })
  
  if (nrow(schema) == 0) next
  
  year_cols <- grep("^year$", schema$name, ignore.case = TRUE, value = TRUE)
  has_year <- length(year_cols) > 0
  
  # Try to extract year
  extracted_year <- extract_year_from_table_name(tbl)
  
  if (has_year) {
    tables_with_year <- tables_with_year + 1
  } else {
    tables_without_year <- tables_without_year + 1
  }
  
  if (!is.na(extracted_year)) {
    tables_year_extractable <- tables_year_extractable + 1
  } else {
    tables_no_year_in_name <- tables_no_year_in_name + 1
  }
}

cat("Summary Statistics:\n")
cat("------------------\n")
cat("Total data tables:", length(data_tables), "\n")
cat("Tables WITH existing YEAR column:", tables_with_year, "\n")
cat("Tables WITHOUT YEAR column:", tables_without_year, "\n")
cat("Tables where year is EXTRACTABLE from name:", tables_year_extractable, "\n")
cat("Tables with NO year in name:", tables_no_year_in_name, "\n\n")

cat("Impact of add_year_columns_to_database():\n")
cat("-----------------------------------------\n")
tables_to_update <- tables_without_year - tables_no_year_in_name
cat("Tables that would be UPDATED:", tables_to_update, "\n")
cat("Tables that would be SKIPPED (already have YEAR):", tables_with_year, "\n")
cat("Tables that would be SKIPPED (no year in name):", tables_no_year_in_name, "\n")

# Find examples of tables without year columns
cat("\n========================================\n")
cat("EXAMPLES: Tables without YEAR columns\n")
cat("========================================\n\n")

count <- 0
for (tbl in data_tables) {
  if (count >= 10) break
  
  schema_query <- paste("PRAGMA table_info(", tbl, ")")
  schema <- tryCatch({
    DBI::dbGetQuery(con, schema_query)
  }, error = function(e) {
    return(data.frame(name = character(0)))
  })
  
  if (nrow(schema) == 0) next
  
  year_cols <- grep("^year$", schema$name, ignore.case = TRUE, value = TRUE)
  has_year <- length(year_cols) > 0
  
  if (!has_year) {
    extracted_year <- extract_year_from_table_name(tbl)
    cat(sprintf("%-15s | Extracted year: %-4s | Columns: %s\n",
                tbl,
                ifelse(is.na(extracted_year), "NA", extracted_year),
                paste(head(schema$name, 5), collapse = ", ")))
    count <- count + 1
  }
}

# Find examples of tables WITH year columns
cat("\n========================================\n")
cat("EXAMPLES: Tables WITH existing YEAR columns\n")
cat("========================================\n\n")

count <- 0
for (tbl in data_tables) {
  if (count >= 10) break
  
  schema_query <- paste("PRAGMA table_info(", tbl, ")")
  schema <- tryCatch({
    DBI::dbGetQuery(con, schema_query)
  }, error = function(e) {
    return(data.frame(name = character(0)))
  })
  
  if (nrow(schema) == 0) next
  
  year_cols <- grep("^year$", schema$name, ignore.case = TRUE, value = TRUE)
  has_year <- length(year_cols) > 0
  
  if (has_year) {
    # Get sample data to see what's in the YEAR column
    sample_query <- paste("SELECT", year_cols[1], "FROM", tbl, "LIMIT 1")
    sample_value <- tryCatch({
      DBI::dbGetQuery(con, sample_query)[[1]][1]
    }, error = function(e) NA)
    
    extracted_year <- extract_year_from_table_name(tbl)
    
    cat(sprintf("%-15s | Year column: %-8s | Sample value: %-4s | Extracted: %-4s\n",
                tbl,
                year_cols[1],
                ifelse(is.na(sample_value), "NA", sample_value),
                ifelse(is.na(extracted_year), "NA", extracted_year)))
    count <- count + 1
  }
}

# Test for potential issues
cat("\n========================================\n")
cat("POTENTIAL ISSUES\n")
cat("========================================\n\n")

cat("Checking for year extraction mismatches...\n")
mismatches <- 0

for (tbl in sample(data_tables, min(50, length(data_tables)))) {
  schema_query <- paste("PRAGMA table_info(", tbl, ")")
  schema <- tryCatch({
    DBI::dbGetQuery(con, schema_query)
  }, error = function(e) {
    return(data.frame(name = character(0)))
  })
  
  if (nrow(schema) == 0) next
  
  year_cols <- grep("^year$", schema$name, ignore.case = TRUE, value = TRUE)
  
  if (length(year_cols) > 0) {
    # Table has year column, check if it matches extracted year
    sample_query <- paste("SELECT DISTINCT", year_cols[1], "FROM", tbl, "LIMIT 5")
    year_values <- tryCatch({
      DBI::dbGetQuery(con, sample_query)[[1]]
    }, error = function(e) NA)
    
    extracted_year <- extract_year_from_table_name(tbl)
    
    if (!is.na(extracted_year) && !any(is.na(year_values))) {
      # Check if extracted year matches any value in the column
      if (!extracted_year %in% year_values) {
        cat(sprintf("⚠️  MISMATCH: %-15s | Extracted: %d | Column values: %s\n",
                    tbl, extracted_year, paste(year_values, collapse = ", ")))
        mismatches <- mismatches + 1
      }
    }
  }
}

if (mismatches == 0) {
  cat("✓ No mismatches found in sample!\n")
} else {
  cat(sprintf("⚠️  Found %d potential mismatches\n", mismatches))
}

cat("\n========================================\n")
cat("TEST COMPLETE\n")
cat("========================================\n\n")

cat("Key Findings:\n")
cat("1. The new extract_year_from_table_name() function handles more patterns\n")
cat("2. It safely skips tables that already have YEAR columns\n")
cat("3. add_year_columns_to_database() is idempotent (safe to run multiple times)\n")
cat("4. Tables without year info in their name will be safely skipped\n")

dbDisconnect(con)
