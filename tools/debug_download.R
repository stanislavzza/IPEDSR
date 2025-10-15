#!/usr/bin/env Rscript
# Debug why 2024 downloads are failing

# Load the package functions
if (file.exists("DESCRIPTION")) {
  devtools::load_all()
} else {
  library(IPEDSR)
}

cat("=== DEBUGGING 2024 DOWNLOAD ISSUES ===\n\n")

# Test 1: Check if we can scrape the files
cat("1. Testing file scraping for 2024...\n")
tryCatch({
  files_2024 <- scrape_ipeds_files_enhanced(2024, verbose = TRUE)
  cat("   Found", nrow(files_2024), "files for 2024\n")
  
  if (nrow(files_2024) > 0) {
    cat("   First few file names:\n")
    print(head(files_2024$table_name, 5))
    
    cat("   Sample CSV links:\n")
    csv_links <- files_2024$csv_link[!is.na(files_2024$csv_link) & files_2024$csv_link != ""]
    if (length(csv_links) > 0) {
      print(head(csv_links, 3))
    } else {
      cat("   ⚠️  NO CSV LINKS FOUND!\n")
    }
    
    cat("   Sample ZIP links:\n") 
    zip_links <- files_2024$zip_link[!is.na(files_2024$zip_link) & files_2024$zip_link != ""]
    if (length(zip_links) > 0) {
      print(head(zip_links, 3))
    } else {
      cat("   ⚠️  NO ZIP LINKS FOUND!\n")
    }
  }
  
}, error = function(e) {
  cat("   ❌ Error in scraping:", e$message, "\n")
})

cat("\n2. Testing single file download...\n")
tryCatch({
  # Try to download one file manually
  files_2024 <- scrape_ipeds_files_enhanced(2024, verbose = FALSE)
  
  if (nrow(files_2024) > 0) {
    # Pick first file with a valid link (CSV or ZIP)
    test_file <- NULL
    for (i in 1:nrow(files_2024)) {
      if ((!is.na(files_2024$csv_link[i]) && files_2024$csv_link[i] != "") ||
          (!is.na(files_2024$zip_link[i]) && files_2024$zip_link[i] != "")) {
        test_file <- files_2024[i, ]
        break
      }
    }
    
    if (!is.null(test_file)) {
      cat("   Testing download of:", test_file$table_name, "\n")
      if (!is.na(test_file$csv_link) && test_file$csv_link != "") {
        cat("   CSV link:", test_file$csv_link, "\n")
      }
      if (!is.na(test_file$zip_link) && test_file$zip_link != "") {
        cat("   ZIP link:", test_file$zip_link, "\n")
      }
      
      # Try download
      temp_dir <- tempdir()
      result <- download_ipeds_csv(test_file, temp_dir, verbose = TRUE)
      
      if (!is.null(result)) {
        cat("   ✅ Download successful:", result, "\n")
        cat("   File size:", file.size(result), "bytes\n")
        
        # Clean up
        if (file.exists(result)) file.remove(result)
      } else {
        cat("   ❌ Download returned NULL\n")
      }
    } else {
      cat("   ❌ No files with valid CSV or ZIP links found\n")
    }
  }
  
}, error = function(e) {
  cat("   ❌ Error in download test:", e$message, "\n")
})

cat("\n3. Checking CSV vs ZIP availability...\n")
tryCatch({
  files_2024 <- scrape_ipeds_files_enhanced(2024, verbose = FALSE)
  
  if (nrow(files_2024) > 0) {
    csv_count <- sum(!is.na(files_2024$csv_link) & files_2024$csv_link != "")
    zip_count <- sum(!is.na(files_2024$zip_link) & files_2024$zip_link != "")
    
    cat("   Files with CSV links:", csv_count, "\n")
    cat("   Files with ZIP links:", zip_count, "\n")
    
    if (csv_count == 0 && zip_count > 0) {
      cat("   💡 INSIGHT: Only ZIP files available, no direct CSV links!\n")
      cat("   This might be why downloads are failing - system expects CSV links.\n")
    }
  }
  
}, error = function(e) {
  cat("   ❌ Error in link analysis:", e$message, "\n")
})

cat("\n=== DEBUG COMPLETE ===\n")