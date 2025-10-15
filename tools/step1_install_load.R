# Step 1: Install and Load IPEDSR Package
# Test package installation and loading

cat("=== STEP 1: Installing and Loading IPEDSR ===\n")

# Install the package from the current directory
cat("Installing IPEDSR package...\n")
devtools::install(quiet = FALSE)

cat("\nLoading IPEDSR package...\n")
library(IPEDSR)

cat("\nChecking key functions are available...\n")
functions_to_check <- c(
  "scrape_ipeds_files_enhanced",
  "download_ipeds_csv", 
  "batch_download_ipeds_files",
  "import_csv_to_duckdb",
  "ensure_connection",
  "get_database_years"
)

for (func in functions_to_check) {
  if (exists(func)) {
    cat("✅", func, "- Available\n")
  } else {
    cat("❌", func, "- Missing\n")
  }
}

cat("\n=== STEP 1 COMPLETE ===\n")
cat("Ready to proceed to Step 2? (y/n)\n")