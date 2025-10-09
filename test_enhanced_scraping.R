# TEST ENHANCED DICTIONARY SCRAPING
# Test the modified scraping function to see if it captures dictionary files

cat("=== TESTING ENHANCED DICTIONARY SCRAPING ===\n")

library(IPEDSR)

cat("\n1. TESTING ENHANCED SCRAPING FUNCTION:\n")
cat("Testing with 2024 data to see if dictionary files are now captured...\n")

# Test the enhanced function
enhanced_results <- scrape_ipeds_files_enhanced(2024, verbose = FALSE)

cat("Enhanced function finds:", nrow(enhanced_results), "files\n")

if (nrow(enhanced_results) > 0) {
  # Check if we now have dictionary links
  dict_count <- sum(enhanced_results$dictionary_link != "", na.rm = TRUE)
  cat("Files with dictionary links:", dict_count, "\n")
  
  if (dict_count > 0) {
    cat("\n✅ DICTIONARY FILES FOUND:\n")
    dict_files <- enhanced_results[enhanced_results$dictionary_link != "", ]
    for (i in seq_len(nrow(dict_files))) {
      cat("  ", dict_files$table_name[i], "\n")
      cat("    Dictionary file:", dict_files$dictionary_file[i], "\n")
      cat("    Dictionary link:", substr(dict_files$dictionary_link[i], 1, 60), "...\n")
    }
  } else {
    cat("\n❌ NO DICTIONARY FILES FOUND\n")
    cat("The enhancement may need further refinement\n")
  }
  
  # Show sample of all results
  cat("\n📊 SAMPLE RESULTS:\n")
  for (i in seq_len(min(5, nrow(enhanced_results)))) {
    cat("  ", enhanced_results$table_name[i], "\n")
    cat("    CSV:", if(enhanced_results$csv_link[i] != "") "✅" else "❌", "\n")
    cat("    ZIP:", if(enhanced_results$zip_link[i] != "") "✅" else "❌", "\n") 
    cat("    Dict:", if(enhanced_results$dictionary_link[i] != "") "✅" else "❌", "\n")
  }
} else {
  cat("❌ No files found - there may be an issue with the scraping function\n")
}

cat("\n=== TEST COMPLETE ===\n")