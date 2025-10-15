# DICTIONARY TABLE ANALYSIS
# Comprehensive analysis of Tables, valuesets, and vartable structures

cat("=== IPEDS DICTIONARY TABLE ANALYSIS ===\n")

library(IPEDSR)
library(dplyr)
con <- ensure_connection()

# 1. IDENTIFY ALL DICTIONARY TABLES
cat("\n1. DICTIONARY TABLE INVENTORY:\n")
all_tables <- DBI::dbListTables(con)

# Find all dictionary table patterns
tables_pattern <- grep("^tables[0-9]{2}$", all_tables, value = TRUE, ignore.case = TRUE)
valuesets_pattern <- grep("^valuesets[0-9]{2}$", all_tables, value = TRUE, ignore.case = TRUE)
vartable_pattern <- grep("^vartable[0-9]{2}$", all_tables, value = TRUE, ignore.case = TRUE)

cat("Tables pattern (", length(tables_pattern), "):", paste(sort(tables_pattern), collapse = ", "), "\n")
cat("Valuesets pattern (", length(valuesets_pattern), "):", paste(sort(valuesets_pattern), collapse = ", "), "\n")
cat("Vartable pattern (", length(vartable_pattern), "):", paste(sort(vartable_pattern), collapse = ", "), "\n")

# Check for 2024 dictionaries
tables_2024 <- grep("tables24", all_tables, value = TRUE, ignore.case = TRUE)
valuesets_2024 <- grep("valuesets24", all_tables, value = TRUE, ignore.case = TRUE)
vartable_2024 <- grep("vartable24", all_tables, value = TRUE, ignore.case = TRUE)

cat("\n2024 Dictionary Tables:\n")
cat("Tables24:", if(length(tables_2024) > 0) paste(tables_2024, collapse = ", ") else "❌ MISSING", "\n")
cat("valuesets24:", if(length(valuesets_2024) > 0) paste(valuesets_2024, collapse = ", ") else "❌ MISSING", "\n")
cat("vartable24:", if(length(vartable_2024) > 0) paste(vartable_2024, collapse = ", ") else "❌ MISSING", "\n")

# 2. ANALYZE TABLE STRUCTURES
cat("\n2. ANALYZING DICTIONARY TABLE STRUCTURES:\n")

# Sample one table from each type to understand structure
if (length(tables_pattern) > 0) {
  sample_tables <- tables_pattern[length(tables_pattern)]  # Most recent
  cat("\nTABLES structure (using", sample_tables, "):\n")
  tables_cols <- DBI::dbListFields(con, sample_tables)
  cat("Columns:", paste(tables_cols, collapse = ", "), "\n")
  
  # Show sample data
  sample_tables_data <- DBI::dbGetQuery(con, paste("SELECT * FROM", sample_tables, "LIMIT 5"))
  cat("Sample records:\n")
  print(sample_tables_data)
}

if (length(valuesets_pattern) > 0) {
  sample_valuesets <- valuesets_pattern[length(valuesets_pattern)]  # Most recent
  cat("\n\nVALUESETS structure (using", sample_valuesets, "):\n")
  valuesets_cols <- DBI::dbListFields(con, sample_valuesets)
  cat("Columns:", paste(valuesets_cols, collapse = ", "), "\n")
  
  # Show sample data
  sample_valuesets_data <- DBI::dbGetQuery(con, paste("SELECT * FROM", sample_valuesets, "LIMIT 5"))
  cat("Sample records:\n")
  print(sample_valuesets_data)
}

if (length(vartable_pattern) > 0) {
  sample_vartable <- vartable_pattern[length(vartable_pattern)]  # Most recent
  cat("\n\nVARTABLE structure (using", sample_vartable, "):\n")
  vartable_cols <- DBI::dbListFields(con, sample_vartable)
  cat("Columns:", paste(vartable_cols, collapse = ", "), "\n")
  
  # Show sample data
  sample_vartable_data <- DBI::dbGetQuery(con, paste("SELECT * FROM", sample_vartable, "LIMIT 5"))
  cat("Sample records:\n")
  print(sample_vartable_data)
}

# 3. ANALYZE CONTENT PATTERNS
cat("\n\n3. CONTENT EVOLUTION ANALYSIS:\n")

# Row counts over time
cat("Row count evolution:\n")
cat("Year\tTables\tValuesets\tVartable\n")
for (year in 2006:2023) {
  year_suffix <- sprintf("%02d", year %% 100)
  
  tables_name <- paste0("Tables", year_suffix)
  valuesets_name <- paste0("valuesets", year_suffix)
  vartable_name <- paste0("vartable", year_suffix)
  
  tables_count <- if (tables_name %in% all_tables) {
    DBI::dbGetQuery(con, paste("SELECT COUNT(*) as n FROM", tables_name))$n
  } else NA
  
  valuesets_count <- if (valuesets_name %in% all_tables) {
    DBI::dbGetQuery(con, paste("SELECT COUNT(*) as n FROM", valuesets_name))$n
  } else NA
  
  vartable_count <- if (vartable_name %in% all_tables) {
    DBI::dbGetQuery(con, paste("SELECT COUNT(*) as n FROM", vartable_name))$n
  } else NA
  
  cat(year, "\t", tables_count, "\t", valuesets_count, "\t", vartable_count, "\n")
}

# 4. EXAMINE RELATIONSHIPS
cat("\n4. DICTIONARY TABLE RELATIONSHIPS:\n")

if (length(tables_pattern) > 0 && length(valuesets_pattern) > 0) {
  # Use most recent year for relationship analysis
  recent_tables <- tables_pattern[length(tables_pattern)]
  recent_valuesets <- valuesets_pattern[length(valuesets_pattern)]
  
  cat("Analyzing relationships using", recent_tables, "and", recent_valuesets, "\n")
  
  # Check if Tables references valuesets or vartable
  tables_data <- DBI::dbGetQuery(con, paste("SELECT * FROM", recent_tables))
  valuesets_data <- DBI::dbGetQuery(con, paste("SELECT * FROM", recent_valuesets))
  
  cat("Tables table unique values in key columns:\n")
  if ("TableName" %in% names(tables_data)) {
    unique_tables <- unique(tables_data$TableName)
    cat("Unique TableName values:", length(unique_tables), "\n")
    cat("Sample TableNames:", paste(head(unique_tables, 10), collapse = ", "), "\n")
  }
  
  cat("\nValuesets table unique values in key columns:\n")
  if ("TableName" %in% names(valuesets_data)) {
    unique_valuesets_tables <- unique(valuesets_data$TableName)
    cat("Unique TableName values:", length(unique_valuesets_tables), "\n")
    cat("Sample TableNames:", paste(head(unique_valuesets_tables, 10), collapse = ", "), "\n")
  }
  
  if ("varname" %in% names(valuesets_data)) {
    unique_varnames <- unique(valuesets_data$varname)
    cat("Unique varname values:", length(unique_varnames), "\n")
    cat("Sample varnames:", paste(head(unique_varnames, 10), collapse = ", "), "\n")
  }
}

# 5. CHECK FOR STANDARDIZATION OPPORTUNITIES
cat("\n5. STANDARDIZATION ANALYSIS:\n")

# Compare column structures across years
if (length(tables_pattern) >= 2) {
  cat("Tables column consistency:\n")
  first_tables_cols <- DBI::dbListFields(con, tables_pattern[1])
  last_tables_cols <- DBI::dbListFields(con, tables_pattern[length(tables_pattern)])
  
  cat("First year (", tables_pattern[1], ") columns:", paste(first_tables_cols, collapse = ", "), "\n")
  cat("Latest year (", tables_pattern[length(tables_pattern)], ") columns:", paste(last_tables_cols, collapse = ", "), "\n")
  cat("Columns consistent?", if (identical(first_tables_cols, last_tables_cols)) "✅ YES" else "❌ NO", "\n")
}

if (length(valuesets_pattern) >= 2) {
  cat("\nValuesets column consistency:\n")
  first_valuesets_cols <- DBI::dbListFields(con, valuesets_pattern[1])
  last_valuesets_cols <- DBI::dbListFields(con, valuesets_pattern[length(valuesets_pattern)])
  
  cat("First year (", valuesets_pattern[1], ") columns:", paste(first_valuesets_cols, collapse = ", "), "\n")
  cat("Latest year (", valuesets_pattern[length(valuesets_pattern)], ") columns:", paste(last_valuesets_cols, collapse = ", "), "\n")
  cat("Columns consistent?", if (identical(first_valuesets_cols, last_valuesets_cols)) "✅ YES" else "❌ NO", "\n")
}

if (length(vartable_pattern) >= 2) {
  cat("\nVartable column consistency:\n")
  first_vartable_cols <- DBI::dbListFields(con, vartable_pattern[1])
  last_vartable_cols <- DBI::dbListFields(con, vartable_pattern[length(vartable_pattern)])
  
  cat("First year (", vartable_pattern[1], ") columns:", paste(first_vartable_cols, collapse = ", "), "\n")
  cat("Latest year (", vartable_pattern[length(vartable_pattern)], ") columns:", paste(last_vartable_cols, collapse = ", "), "\n")
  cat("Columns consistent?", if (identical(first_vartable_cols, last_vartable_cols)) "✅ YES" else "❌ NO", "\n")
}

cat("\n=== DICTIONARY ANALYSIS COMPLETE ===\n")
cat("\nNext steps:\n")
cat("1. Review the structure and relationship findings above\n")
cat("2. Check if 2024 dictionary tables are available for download\n")
cat("3. Design consolidation strategy based on these findings\n")