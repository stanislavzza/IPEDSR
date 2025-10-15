# VALIDATE 2024 DATA IN DUCKDB
# Check actual data contents, not just table existence

cat("=== VALIDATING 2024 DATA IN DUCKDB DATABASE ===\n")

library(IPEDSR)

con <- ensure_connection()

# Get all 2024 tables
tables_2024 <- grep("2024", DBI::dbListTables(con), value = TRUE)

cat("Found", length(tables_2024), "tables with '2024' in name:\n")

total_2024_records <- 0
valid_tables <- 0

for (table in sort(tables_2024)) {
  cat("\n📊 TABLE:", table, "\n")
  
  tryCatch({
    # Get basic row count
    row_count <- DBI::dbGetQuery(con, paste("SELECT COUNT(*) as n FROM", table))$n
    total_2024_records <- total_2024_records + row_count
    
    cat("   Rows:", format(row_count, big.mark = ","), "\n")
    
    # Get column info
    columns <- DBI::dbGetQuery(con, paste("PRAGMA table_info(", table, ")"))
    cat("   Columns:", nrow(columns), "\n")
    
    # Check if UNITID column exists (most IPEDS tables should have this)
    has_unitid <- "UNITID" %in% columns$name
    cat("   Has UNITID:", has_unitid, "\n")
    
    # Sample a few rows to verify data exists
    if (row_count > 0) {
      sample_data <- DBI::dbGetQuery(con, paste("SELECT * FROM", table, "LIMIT 3"))
      cat("   Sample data preview:\n")
      
      # Show first few columns of first row
      if (nrow(sample_data) > 0) {
        first_row <- sample_data[1, 1:min(5, ncol(sample_data))]
        cat("     First row (first 5 cols):", paste(names(first_row), "=", first_row, collapse = ", "), "\n")
        
        # Check if UNITID has reasonable values (should be numeric institution IDs)
        if (has_unitid && !is.na(sample_data$UNITID[1])) {
          unitid_sample <- sample_data$UNITID[1:min(3, nrow(sample_data))]
          cat("     UNITID samples:", paste(unitid_sample, collapse = ", "), "\n")
        }
        
        valid_tables <- valid_tables + 1
      } else {
        cat("     ❌ No data rows found!\n")
      }
    } else {
      cat("     ❌ Table is empty!\n")
    }
    
  }, error = function(e) {
    cat("   ❌ ERROR querying table:", e$message, "\n")
  })
}

cat("\n" %||% "=== SUMMARY ===\n")
cat("📊 Total 2024 tables found:", length(tables_2024), "\n")
cat("✅ Tables with valid data:", valid_tables, "\n")
cat("📈 Total 2024 records across all tables:", format(total_2024_records, big.mark = ","), "\n")

# Verify this represents actual 2024 academic year data
cat("\n🔍 VERIFICATION CHECKS:\n")

# Check if we have institution data (HD2024)
if ("HD2024" %in% tables_2024) {
  tryCatch({
    hd_sample <- DBI::dbGetQuery(con, "SELECT UNITID, INSTNM, STABBR FROM HD2024 LIMIT 5")
    cat("✅ Institutional Directory (HD2024) sample:\n")
    for (i in 1:nrow(hd_sample)) {
      cat("   ", hd_sample$UNITID[i], "-", hd_sample$INSTNM[i], "(", hd_sample$STABBR[i], ")\n")
    }
  }, error = function(e) {
    cat("❌ Error checking HD2024:", e$message, "\n")
  })
}

# Check if we have enrollment data (EFFY2024)
if ("EFFY2024" %in% tables_2024) {
  tryCatch({
    effy_summary <- DBI::dbGetQuery(con, "SELECT COUNT(*) as institutions, SUM(CAST(EFYTOTLT AS INTEGER)) as total_enrollment FROM EFFY2024 WHERE EFYTOTLT IS NOT NULL AND EFYTOTLT != ''")
    cat("✅ Fall Enrollment (EFFY2024) summary:\n")
    cat("   Institutions with enrollment:", format(effy_summary$institutions, big.mark = ","), "\n")
    if (!is.na(effy_summary$total_enrollment)) {
      cat("   Total fall enrollment:", format(effy_summary$total_enrollment, big.mark = ","), "\n")
    }
  }, error = function(e) {
    cat("❌ Error checking EFFY2024:", e$message, "\n")
  })
}

# Check if we have completions data (C2024_A)
if ("C2024_A" %in% tables_2024) {
  tryCatch({
    completions_summary <- DBI::dbGetQuery(con, "SELECT COUNT(*) as records, COUNT(DISTINCT UNITID) as institutions FROM C2024_A")
    cat("✅ Completions (C2024_A) summary:\n")
    cat("   Total completion records:", format(completions_summary$records, big.mark = ","), "\n")
    cat("   Institutions reporting:", format(completions_summary$institutions, big.mark = ","), "\n")
  }, error = function(e) {
    cat("❌ Error checking C2024_A:", e$message, "\n")
  })
}

# Final validation
if (valid_tables == length(tables_2024) && total_2024_records > 0) {
  cat("\n🎉 SUCCESS: Database contains valid 2024 IPEDS data!\n")
  cat("   All", length(tables_2024), "tables are accessible and contain data\n")
  cat("   Total records:", format(total_2024_records, big.mark = ","), "\n")
} else {
  cat("\n⚠️  ISSUES FOUND:\n")
  if (valid_tables < length(tables_2024)) {
    cat("   ", (length(tables_2024) - valid_tables), "tables have no data or errors\n")
  }
  if (total_2024_records == 0) {
    cat("   No records found across all tables\n")
  }
}

cat("\n=== VALIDATION COMPLETE ===\n")