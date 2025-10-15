# Debug HD2022 Import Failure
# This script investigates why HD2022.csv fails to import

library(devtools)
load_all()

# Find the HD2022 zip file
downloads_dir <- file.path(rappdirs::user_data_dir('IPEDSR'), 'downloads')
zip_file <- file.path(downloads_dir, 'HD2022.zip')

cat("Investigating HD2022 import failure...\n")
cat("=" %>% rep(70) %>% paste(collapse=""), "\n\n")

if (!file.exists(zip_file)) {
  cat("ERROR: HD2022.zip not found at:", zip_file, "\n")
  quit(save = "no", status = 1)
}

# Extract it
temp_dir <- tempdir()
extract_dir <- file.path(temp_dir, 'hd2022_debug')
dir.create(extract_dir, showWarnings = FALSE, recursive = TRUE)

cat("Extracting ZIP file...\n")
unzip(zip_file, exdir = extract_dir, overwrite = TRUE)

# Find CSV
csv_files <- list.files(extract_dir, pattern = "\\.csv$", full.names = TRUE, ignore.case = TRUE)
if (length(csv_files) == 0) {
  cat("ERROR: No CSV file found in ZIP\n")
  quit(save = "no", status = 1)
}

csv_file <- csv_files[1]
cat("CSV file:", basename(csv_file), "\n\n")

# Read just first few rows to inspect
cat("Reading CSV file structure...\n")
cat("-" %>% rep(70) %>% paste(collapse=""), "\n")

data <- read.csv(csv_file, nrows = 5, stringsAsFactors = FALSE, check.names = FALSE)

cat("Total columns:", ncol(data), "\n")
cat("Total rows (sample):", nrow(data), "\n\n")

cat("Column names:\n")
for (i in seq_along(names(data))) {
  cat(sprintf("%3d. %s\n", i, names(data)[i]))
}

# Check for duplicate column names
cat("\nDuplicate column names:\n")
dup_count <- sum(duplicated(names(data)))
cat("Count:", dup_count, "\n")
if (dup_count > 0) {
  cat("Duplicate names found:\n")
  dup_names <- names(data)[duplicated(names(data))]
  for (name in unique(dup_names)) {
    indices <- which(names(data) == name)
    cat("  '", name, "' appears at columns:", paste(indices, collapse=", "), "\n", sep="")
  }
}

# Check for empty column names
cat("\nEmpty column names:\n")
empty_count <- sum(names(data) == "")
cat("Count:", empty_count, "\n")
if (empty_count > 0) {
  empty_indices <- which(names(data) == "")
  cat("Empty names at columns:", paste(empty_indices, collapse=", "), "\n")
}

# Try to replicate the import error
cat("\n")
cat("=" %>% rep(70) %>% paste(collapse=""), "\n")
cat("ATTEMPTING IMPORT (replicating error)...\n")
cat("=" %>% rep(70) %>% paste(collapse=""), "\n\n")

tryCatch({
  # Read full file
  cat("Reading full CSV...\n")
  full_data <- read.csv(csv_file, stringsAsFactors = FALSE)
  
  cat("✓ CSV read successfully\n")
  cat("  Rows:", nrow(full_data), "\n")
  cat("  Columns:", ncol(full_data), "\n\n")
  
  # Try to add YEAR column (this is where error might occur)
  cat("Attempting to add YEAR column...\n")
  
  # Check if YEAR column exists
  year_exists <- any(grepl("^year$", names(full_data), ignore.case = TRUE))
  cat("  YEAR column exists:", year_exists, "\n")
  
  if (!year_exists) {
    # Extract year from filename
    year <- 2022
    cat("  Extracted year:", year, "\n")
    
    # Check if UNITID exists
    has_unitid <- "UNITID" %in% names(full_data)
    cat("  UNITID column exists:", has_unitid, "\n")
    
    if (has_unitid) {
      unitid_pos <- which(names(full_data) == "UNITID")[1]
      cat("  UNITID position:", unitid_pos, "\n")
      
      # Try the problematic cbind operation
      if (unitid_pos < ncol(full_data)) {
        cat("  Attempting cbind operation...\n")
        
        first_cols <- full_data[, 1:unitid_pos, drop = FALSE]
        rest_cols <- full_data[, (unitid_pos + 1):ncol(full_data), drop = FALSE]
        
        cat("    first_cols:", ncol(first_cols), "columns\n")
        cat("    rest_cols:", ncol(rest_cols), "columns\n")
        
        result <- cbind(
          first_cols,
          YEAR = year,
          rest_cols,
          stringsAsFactors = FALSE
        )
        
        cat("  ✓ cbind successful\n")
        cat("  Result columns:", ncol(result), "\n")
      }
    }
  }
  
  cat("\n✓ NO ERROR - Import should work!\n")
  cat("  The error must be occurring elsewhere in the pipeline.\n")
  
}, error = function(e) {
  cat("\n✗ ERROR FOUND:\n")
  cat("  Message:", e$message, "\n")
  cat("  This is the error preventing HD2022 import!\n")
})

cat("\n")
cat("=" %>% rep(70) %>% paste(collapse=""), "\n")
cat("DIAGNOSIS COMPLETE\n")
cat("=" %>% rep(70) %>% paste(collapse=""), "\n")
