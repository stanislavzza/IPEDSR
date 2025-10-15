# PHASE 2: DUCKDB EXPLORATION GUIDE FOR IPEDS
# Practical guide to exploring your IPEDS database using DuckDB and R

cat("=== DUCKDB EXPLORATION GUIDE ===\n")

library(IPEDSR)

cat("\n🔧 DUCKDB CONNECTION PATTERNS\n")
cat("=====================================\n")

# Method 1: Using package functions (recommended)
con <- ensure_connection()
cat("✅ Connected using IPEDSR::ensure_connection()\n")

# Method 2: Direct DBI connection (for advanced users)
# db_path <- get_ipeds_db_path()
# con_direct <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path, read_only = TRUE)

cat("\n🗃️  BASIC DATABASE EXPLORATION\n")
cat("=====================================\n")

# List all tables
all_tables <- DBI::dbListTables(con)
cat("Total tables available:", length(all_tables), "\n")

# Show recent tables (2020+)
recent_tables <- grep("202[0-9]", all_tables, value = TRUE)
cat("Recent tables (2020+):", length(recent_tables), "\n")
cat("Sample:", paste(head(recent_tables, 5), collapse = ", "), "\n")

cat("\n📊 TABLE INFORMATION QUERIES\n")
cat("=====================================\n")

# Get table structure (DuckDB specific)
sample_table <- "HD2024"
if (sample_table %in% all_tables) {
  cat("Example: Getting table structure for", sample_table, "\n")

  # Method 1: PRAGMA table_info (DuckDB specific)
  columns <- DBI::dbGetQuery(con,
                             paste("PRAGMA table_info(",
                                   sample_table, ")"))
  cat("Columns in", sample_table, ":\n")
  print(head(columns[, c("name", "type", "notnull")], 8))

  # Method 2: DESCRIBE (also DuckDB specific)
  # describe_result <- DBI::dbGetQuery(con, paste("DESCRIBE", sample_table))

  # Method 3: Standard SQL information_schema (if available)
  # info_schema <- DBI::dbGetQuery(con, "SELECT * FROM information_schema.columns WHERE table_name = ?", sample_table)
}

cat("\n🔍 DATA PREVIEW TECHNIQUES\n")
cat("=====================================\n")

if (sample_table %in% all_tables) {
  # Quick row count
  row_count <- DBI::dbGetQuery(con, paste("SELECT COUNT(*) as count FROM", sample_table))
  cat("Row count for", sample_table, ":", row_count$count, "\n")
  
  # Sample data preview
  cat("\nSample data (first 3 rows, first 5 columns):\n")
  sample_data <- DBI::dbGetQuery(con, paste("SELECT * FROM", sample_table, "LIMIT 3"))
  print(sample_data[, 1:min(5, ncol(sample_data))])
  
  # Check for missing values in key columns
  cat("\nMissing value check for UNITID:\n")
  missing_check <- DBI::dbGetQuery(con, paste("SELECT COUNT(*) as total, COUNT(UNITID) as non_null FROM", sample_table))
  cat("Total rows:", missing_check$total, "Non-null UNITID:", missing_check$non_null, "\n")
}

cat("\n🔗 CROSS-TABLE EXPLORATION\n")
cat("=====================================\n")

# Find common UNITIDs across years
cat("Finding institutions with data across multiple years:\n")
hd_tables <- grep("^hd[0-9]{4}$|^HD[0-9]{4}$", all_tables, value = TRUE)
cat("HD (directory) tables available:", length(hd_tables), "\n")
cat("Years:", paste(head(hd_tables, 5), collapse = ", "), "...\n")

if (length(hd_tables) >= 2) {
  # Compare institution counts across years
  table1 <- hd_tables[length(hd_tables)-1]  # Second to last
  table2 <- hd_tables[length(hd_tables)]    # Last
  
  count1 <- DBI::dbGetQuery(con, paste("SELECT COUNT(DISTINCT UNITID) as count FROM", table1))
  count2 <- DBI::dbGetQuery(con, paste("SELECT COUNT(DISTINCT UNITID) as count FROM", table2))
  
  cat("Institutions in", table1, ":", count1$count, "\n")
  cat("Institutions in", table2, ":", count2$count, "\n")
}

cat("\n⚡ DUCKDB-SPECIFIC FEATURES\n")
cat("=====================================\n")

# DuckDB has excellent SQL extensions
cat("DuckDB SQL Extensions you can use:\n")
cat("1. PRAGMA commands for metadata\n")
cat("2. Advanced analytics functions\n")
cat("3. Efficient aggregation with FILTER\n")
cat("4. JSON and array operations\n")
cat("5. Regular expressions\n")
cat("6. Window functions\n")

# Example of DuckDB-specific analytics
if ("EFFY2024" %in% all_tables) {
  cat("\nExample: Advanced aggregation with FILTER clause\n")
  enrollment_summary <- DBI::dbGetQuery(con, "
    SELECT 
      COUNT(*) as total_records,
      COUNT(*) FILTER (WHERE EFYTOTLT > 0) as institutions_with_enrollment,
      AVG(EFYTOTLT) FILTER (WHERE EFYTOTLT > 0) as avg_enrollment
    FROM EFFY2024 
    WHERE EFYTOTLT IS NOT NULL
  ")
  print(enrollment_summary)
}

cat("\n📈 PERFORMANCE TIPS\n")
cat("=====================================\n")
cat("1. DuckDB is columnar - aggregations are very fast\n")
cat("2. Use LIMIT for exploration, COUNT(*) for verification\n")
cat("3. PRAGMA functions give metadata without scanning data\n")
cat("4. DuckDB handles large JOINs efficiently\n")
cat("5. Use EXPLAIN to see query plans\n")

# Example performance check
if ("HD2024" %in% all_tables) {
  cat("\nExample: EXPLAIN query plan\n")
  plan <- DBI::dbGetQuery(con, "EXPLAIN SELECT COUNT(*) FROM HD2024")
  print(head(plan, 3))
}

cat("\n🎯 RECOMMENDED EXPLORATION WORKFLOW\n")
cat("=====================================\n")
cat("1. Start with HD tables (institutional directory) - they're the foundation\n")
cat("2. Explore EFFY tables (enrollment) - they link to most other data\n")
cat("3. Join HD + EFFY to get institution names with enrollment\n")
cat("4. Add C tables (completions) for degree production analysis\n")
cat("5. Use UNITID as the primary key across all tables\n")
cat("6. Always check data coverage by year before longitudinal analysis\n")

cat("\n💡 NEXT STEPS\n")
cat("=====================================\n")
cat("Ready to:\n")
cat("A) Explore specific survey components (HD, EFFY, C)\n")
cat("B) Build cross-table joins and relationships\n")
cat("C) Create example research queries\n")
cat("D) Develop user-friendly exploration functions\n")

cat("\n✅ DUCKDB GUIDE COMPLETE\n")