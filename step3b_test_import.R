# Step 3b: Test Fixed Import Process
# Try importing one of the downloaded files with the fixed table naming

cat("=== STEP 3B: Testing Fixed Import Process ===\n")

library(IPEDSR)

cat("\n1. Testing import of one downloaded file...\n")

# Try importing the HD2024 file we know exists
csv_path <- "data/downloads/HD2024.zip.csv"
if (file.exists(csv_path)) {
  cat("✅ Found file:", csv_path, "\n")
  cat("📏 File size:", round(file.size(csv_path) / 1024 / 1024, 2), "MB\n")
  
  # Clean table name (remove .zip)
  clean_table_name <- "HD2024"
  
  cat("\n2. Importing to database with clean table name:", clean_table_name, "\n")
  
  import_result <- import_csv_to_duckdb(
    csv_path, 
    clean_table_name, 
    verbose = TRUE
  )
  
  if (import_result) {
    cat("\n✅ Import successful!\n")
    
    # Verify table exists
    con <- ensure_connection()
    tables <- DBI::dbListTables(con)
    if (clean_table_name %in% tables) {
      row_count <- DBI::dbGetQuery(con, paste("SELECT COUNT(*) as n FROM", clean_table_name))$n
      cat("🎉 Table", clean_table_name, "exists with", row_count, "rows\n")
    }
  } else {
    cat("\n❌ Import failed\n")
  }
  
} else {
  cat("❌ File not found:", csv_path, "\n")
}

cat("\n=== STEP 3B COMPLETE ===\n")
cat("Import test completed. Ready to retry full batch? (y/n)\n")