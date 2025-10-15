# Step 3 FINAL: Download 2024 Data with Persistent Storage
# Download and import all 2024 files with proper persistence and duplicate prevention

cat("=== STEP 3 FINAL: 2024 Data Download & Import ===\n")

library(IPEDSR)

cat("\n📍 Download Location Confirmed:\n")
downloads_path <- get_ipeds_downloads_path()
cat("   Files will be stored at:", downloads_path, "\n")
cat("   This location persists between R sessions ✅\n")

cat("\n1. Getting list of 2024 files...\n")
files_2024 <- scrape_ipeds_files_enhanced(2024)
cat("📋 Found", nrow(files_2024), "files available for 2024\n")

cat("\n2. Checking for existing downloads...\n")
if (dir.exists(downloads_path)) {
  existing_files <- list.files(downloads_path, pattern = "2024.*\\.csv$")
  cat("📁 Found", length(existing_files), "existing 2024 files\n")
  if (length(existing_files) > 0) {
    cat("📄 Existing files will be SKIPPED:\n")
    for (f in head(existing_files, 5)) {
      cat("   -", f, "\n")
    }
    if (length(existing_files) > 5) {
      cat("   - ... and", length(existing_files) - 5, "more\n")
    }
  }
} else {
  existing_files <- character(0)
  cat("📁 No existing files - will download all\n")
}

cat("\n3. Starting BATCH DOWNLOAD with duplicate prevention...\n")
cat("🛡️  force_redownload = FALSE (DUPLICATE PREVENTION ACTIVE)\n")
cat("📁 Persistent storage location:", downloads_path, "\n")

# Run the complete batch download and import
results <- batch_download_ipeds_files(
  files_2024, 
  force_redownload = FALSE,  # SKIP existing files
  verbose = TRUE
)

cat("\n4. FINAL RESULTS SUMMARY:\n")
if (!is.null(results) && nrow(results) > 0) {
  total_files <- nrow(files_2024)
  downloads_successful <- sum(results$download_success, na.rm = TRUE)
  imports_successful <- sum(results$import_success, na.rm = TRUE)
  
  cat("📊 DOWNLOAD SUMMARY:\n")
  cat("   - Total 2024 files available: ", total_files, "\n")
  cat("   - Downloads successful: ", downloads_successful, "\n")
  cat("   - Database imports successful: ", imports_successful, "\n")
  
  if (imports_successful > 0) {
    cat("\n🎉 SUCCESS! 2024 data has been added to your database!\n")
    cat("📈 You now have data for 2004-2024 (21 years total)\n")
    
    # Show which tables were imported
    successful_imports <- results[results$import_success == TRUE, ]
    if (nrow(successful_imports) > 0) {
      cat("\n📋 Successfully imported tables:\n")
      for (i in 1:min(5, nrow(successful_imports))) {
        table_name <- gsub("\\.zip$", "", successful_imports$file_name[i])
        row_count <- successful_imports$row_count[i]
        cat("   -", table_name, "(", format(row_count, big.mark = ","), "rows )\n")
      }
      if (nrow(successful_imports) > 5) {
        cat("   - ... and", nrow(successful_imports) - 5, "more tables\n")
      }
    }
  } else if (downloads_successful > 0) {
    cat("\n⚠️  PARTIAL SUCCESS: Files downloaded but imports failed\n")
    cat("📁 Files are safely stored at:", downloads_path, "\n")
  } else {
    cat("\n❌ DOWNLOAD ISSUES: Check for errors above\n")
  }
  
} else {
  cat("❌ No results returned - check for errors\n")
}

cat("\n=== STEP 3 COMPLETE ===\n")
cat("Files persist at:", downloads_path, "\n")
cat("Ready for Step 4 (Verify Database Contains 2024 Data)? (y/n)\n")