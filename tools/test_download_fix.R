# Test the filename fix by trying to download one file
# This will demonstrate whether the .zip.csv naming issue is fixed

cat("=== TESTING DOWNLOAD FILENAME FIX ===\n")

library(IPEDSR)

# Get one file from 2024 to test
available_2024 <- scrape_ipeds_files_enhanced(2024, verbose = FALSE)
test_file <- available_2024[1, ]  # Just test the first one

cat("Testing download for:", test_file$table_name, "\n")

# Clear downloads directory to see fresh files
downloads_dir <- get_ipeds_downloads_path()
if (dir.exists(downloads_dir)) {
  existing_files <- list.files(downloads_dir, full.names = TRUE)
  if (length(existing_files) > 0) {
    file.remove(existing_files)
    cat("Cleared", length(existing_files), "existing files from downloads directory\n")
  }
}

# Download the file with verbose output
result <- download_ipeds_csv(test_file, verbose = TRUE)

cat("\nResult:", ifelse(is.null(result), "FAILED", "SUCCESS"), "\n")
if (!is.null(result)) {
  cat("File saved to:", result, "\n")
  cat("File exists:", file.exists(result), "\n")
  if (file.exists(result)) {
    cat("File size:", file.size(result), "bytes\n")
  }
}

# Check what files are actually in the downloads directory
cat("\nFiles in downloads directory:\n")
files_in_dir <- list.files(downloads_dir, full.names = FALSE)
if (length(files_in_dir) > 0) {
  for (f in files_in_dir) {
    cat(" -", f, "\n")
  }
} else {
  cat(" (empty)\n")
}

cat("\n=== TEST COMPLETE ===\n")