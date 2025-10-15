# Step 3: Download 2024 Data (with Duplicate Prevention)
# Download and import 2024 files - SKIPPING any that already exist

cat("=== STEP 3: Downloading 2024 Data (Smart Download) ===\n")

library(IPEDSR)

cat("\n🛡️  DUPLICATE PREVENTION ACTIVE:\n")
cat("   - Will check if files already exist before downloading\n")
cat("   - Will skip existing files to avoid server overload\n")
cat("   - Will only download new/missing files\n")

cat("\n1. Getting list of 2024 files to download...\n")
files_2024 <- scrape_ipeds_files_enhanced(2024)
cat("📋 Found", nrow(files_2024), "files available for 2024\n")

cat("\n2. Checking download directory for existing files...\n")
download_dir <- file.path("data", "downloads")
if (dir.exists(download_dir)) {
  existing_files <- list.files(download_dir, pattern = "2024.*\\.csv$")
  cat("📁 Found", length(existing_files), "existing 2024 files in download directory\n")
  if (length(existing_files) > 0) {
    cat("📄 Existing files:\n")
    for (f in head(existing_files, 5)) {
      cat("   -", f, "\n")
    }
    if (length(existing_files) > 5) {
      cat("   - ... and", length(existing_files) - 5, "more\n")
    }
  }
} else {
  cat("📁 Download directory doesn't exist yet - will be created\n")
  existing_files <- character(0)
}

cat("\n3. Starting batch download with duplicate prevention...\n")
cat("⚡ force_redownload = FALSE (will skip existing files)\n")

# Run the batch download
results <- batch_download_ipeds_files(
  files_2024, 
  force_redownload = FALSE,  # KEY: Don't redownload existing files
  verbose = TRUE
)

cat("\n4. Download and Import Summary:\n")
if (!is.null(results) && nrow(results) > 0) {
  downloads_attempted <- nrow(results)
  downloads_successful <- sum(results$download_success, na.rm = TRUE)
  downloads_skipped <- sum(!results$download_success & !is.na(results$download_success), na.rm = TRUE)
  imports_successful <- sum(results$import_success, na.rm = TRUE)
  
  cat("📊 DOWNLOAD RESULTS:\n")
  cat("   - Files available: ", nrow(files_2024), "\n")
  cat("   - Downloads attempted: ", downloads_attempted, "\n")  
  cat("   - Downloads successful: ", downloads_successful, "\n")
  cat("   - Downloads skipped (already exist): ", downloads_skipped, "\n")
  cat("   - Database imports successful: ", imports_successful, "\n")
  
  if (imports_successful > 0) {
    cat("\n✅ SUCCESS: 2024 data has been added to your database!\n")
  } else {
    cat("\n⚠️  WARNING: Downloads worked but imports may have failed\n")
  }
} else {
  cat("❌ No results returned - check for errors above\n")
}

cat("\n=== STEP 3 COMPLETE ===\n")
cat("2024 data download attempted with duplicate prevention.\n")
cat("Ready for Step 4 (Verify 2024 Data in Database)? (y/n)\n")