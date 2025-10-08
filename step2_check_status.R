# Step 2: Check Current Database Status
# Examine existing data and prepare for 2024 update

cat("=== STEP 2: Checking Current Database Status ===\n")

library(IPEDSR)

cat("\n1. Checking if IPEDS database exists...\n")
if (ipeds_database_exists()) {
  cat("✅ IPEDS database found\n")
  
  cat("\n2. Getting current database years...\n")
  current_years <- get_database_years()
  cat("📊 Years in database:", paste(current_years, collapse = ", "), "\n")
  cat("📈 Total years:", length(current_years), "\n")
  
  cat("\n3. Checking for 2024 data...\n")
  has_2024 <- "2024" %in% current_years
  if (has_2024) {
    cat("✅ 2024 data found in database\n")
  } else {
    cat("❌ No 2024 data found - ready for update\n")
  }
  
  cat("\n4. Getting database connection info...\n")
  db_info <- get_database_info()
  cat("🗂️  Database path:", db_info$database_path, "\n")
  cat("📏 Database size:", round(db_info$size_mb, 2), "MB\n")
  cat("📅 Last modified:", db_info$last_modified, "\n")
  
  cat("\n5. Checking available 2024 files online...\n")
  cat("🌐 Scraping IPEDS website for 2024 files...\n")
  files_2024 <- scrape_ipeds_files_enhanced(2024)
  cat("📋 Found", nrow(files_2024), "files available for 2024\n")
  
  if (nrow(files_2024) > 0) {
    cat("\n📝 Sample of available 2024 files:\n")
    sample_files <- head(files_2024$table_name, 5)
    for (i in seq_along(sample_files)) {
      cat("   ", i, ".", sample_files[i], "\n")
    }
    if (nrow(files_2024) > 5) {
      cat("   ... and", nrow(files_2024) - 5, "more files\n")
    }
  }
  
} else {
  cat("❌ IPEDS database not found\n")
  cat("🔧 Database needs to be set up first\n")
  cat("💡 This will be handled automatically during first download\n")
}

cat("\n=== STEP 2 COMPLETE ===\n")
cat("Database status checked. Ready for Step 3 (Download 2024 Data)? (y/n)\n")