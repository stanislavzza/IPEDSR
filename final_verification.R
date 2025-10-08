# Final verification of 2024 data completeness
library(IPEDSR)

cat("=== FINAL 2024 DATA COMPLETENESS CHECK ===\n")

# Get available files and clean duplicates
available_2024 <- scrape_ipeds_files_enhanced(2024, verbose = FALSE)
available_clean <- gsub("\\.zip$", "", available_2024$table_name)
unique_available <- unique(available_clean)

# Get existing database tables
existing_2024 <- grep("2024", DBI::dbListTables(ensure_connection()), value = TRUE)

# Check completeness
missing <- unique_available[!unique_available %in% existing_2024]

cat("📊 SUMMARY:\n")
cat("   Unique files available online:", length(unique_available), "\n")
cat("   Files in database:", length(existing_2024), "\n")
cat("   Actually missing:", length(missing), "\n")

if (length(missing) == 0) {
  cat("\n🎉 SUCCESS: All unique 2024 files are in the database!\n")
  
  # Show final summary with row counts
  cat("\n📊 Complete 2024 database contents:\n")
  total_rows <- 0
  for (table in sort(existing_2024)) {
    row_count <- DBI::dbGetQuery(ensure_connection(), paste("SELECT COUNT(*) as n FROM", table))$n
    total_rows <- total_rows + row_count
    cat("   ", table, ":", format(row_count, big.mark = ","), "rows\n")
  }
  cat("\n📊 Total 2024 records:", format(total_rows, big.mark = ","), "\n")
  
  # Verify years in database
  years <- get_database_years()
  cat("\n📅 Database now contains years:", paste(years, collapse = ", "), "\n")
  cat("📊 Total years:", length(years), "\n")
  
} else {
  cat("\n❌ Still missing files:\n")
  for (m in missing) {
    cat("   -", m, "\n")
  }
}

# Show duplicate analysis
if (any(duplicated(available_clean))) {
  cat("\n📋 Duplicate file analysis:\n")
  dups <- available_clean[duplicated(available_clean)]
  for (d in unique(dups)) {
    count <- sum(available_clean == d)
    cat("   ", d, "appears", count, "times in available list\n")
  }
  cat("   (This explains why 15 total != 13 unique files)\n")
}

cat("\n=== VERIFICATION COMPLETE ===\n")