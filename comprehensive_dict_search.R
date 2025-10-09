# SEARCH FOR 2024 IPEDS DICTIONARY FILES
# More comprehensive search for dictionary files including alternative locations

cat("=== COMPREHENSIVE 2024 DICTIONARY SEARCH ===\n")

library(IPEDSR)

# 1. Check if there are any files we haven't seen yet
cat("\n1. ALTERNATIVE DICTIONARY SEARCH STRATEGIES:\n")

# Sometimes dictionaries are released separately or have different patterns
# Let's check a few different approaches

# A. Check if there are dictionary files with year patterns
cat("Checking for alternative year patterns (24, 2024):\n")

# Function to search for dictionary patterns across different sources
search_dict_patterns <- function() {
  patterns_to_check <- c(
    # Standard patterns
    "Tables24", "valuesets24", "vartable24",
    "Tables2024", "valuesets2024", "vartable2024",
    
    # Alternative naming patterns IPEDS might use
    "Dictionary2024", "Dict2024", "Variables2024", "Vars2024",
    "Codebook2024", "Labels2024", "Metadata2024",
    "DataDictionary2024", "VarList2024",
    
    # Excel workbook patterns
    "TableDictionary", "VariableDictionary", "DataDict",
    "CompleteDictionary", "MasterDictionary"
  )
  
  return(patterns_to_check)
}

patterns <- search_dict_patterns()
cat("Searching for patterns:", paste(patterns[1:10], collapse = ", "), "...\n")

# B. Check if dictionaries might be in previous year's download process
cat("\n2. EXAMINING HISTORICAL DICTIONARY DOWNLOAD PATTERNS:\n")

# Let's look at how we got the 2023 dictionaries - were they separate downloads?
cat("Historical dictionary availability:\n")

# Check a recent year to see what the pattern was
recent_files_2023 <- tryCatch({
  scrape_ipeds_files_enhanced(2023, verbose = FALSE)
}, error = function(e) {
  cat("Could not check 2023 files:", e$message, "\n")
  data.frame()
})

if (nrow(recent_files_2023) > 0) {
  cat("2023 files available (", nrow(recent_files_2023), " total):\n")
  
  # Look for dictionary patterns in 2023
  dict_2023 <- grep("dict|tables|valuesets|vartable|variable", 
                    recent_files_2023$table_name, ignore.case = TRUE, value = TRUE)
  
  if (length(dict_2023) > 0) {
    cat("Dictionary-related files in 2023:\n")
    for (file in dict_2023) {
      cat("  ", file, "\n")
    }
  } else {
    cat("No obvious dictionary files in 2023 either\n")
  }
}

# C. Check documentation patterns
cat("\n3. IPEDS DOCUMENTATION SEARCH:\n")
cat("Dictionary files might be:\n")
cat("1. Released later in the academic year (after data files)\n")
cat("2. Combined into a single comprehensive dictionary file\n") 
cat("3. Available from a different IPEDS portal/section\n")
cat("4. Embedded within the data ZIP files as additional Excel sheets\n")

# D. Check if existing 2024 ZIP files might contain Excel workbooks with dictionaries
cat("\n4. EXAMINING 2024 ZIP CONTENTS:\n")
cat("Strategy: Download one 2024 ZIP file and check if it contains dictionary sheets\n")

# Let's examine what's actually in a 2024 ZIP file
if (nrow(available_2024) > 0) {
  test_file <- available_2024$table_name[1]  # Take first file
  cat("Test file for examination:", test_file, "\n")
  cat("We could download this file and check if it contains:\n")
  cat("- Multiple sheets in Excel workbook\n")
  cat("- Dictionary/metadata sheets alongside data\n")
  cat("- Documentation files within the ZIP\n")
}

# E. Manual dictionary creation strategy
cat("\n5. FALLBACK STRATEGY - CREATE 2024 DICTIONARIES:\n")
cat("If no 2024 dictionaries are available, we can:\n")
cat("1. Use 2023 dictionaries as base (tables23, valuesets23, vartable23)\n")
cat("2. Update with 2024-specific table names and variables\n")
cat("3. Extract variable information from 2024 data file headers\n")
cat("4. Create consolidated dictionaries manually\n")

cat("\n=== NEXT STEPS ===\n")
cat("Recommendation:\n")
cat("1. Download and examine contents of one 2024 ZIP file\n")
cat("2. Check if Excel workbooks contain dictionary worksheets\n") 
cat("3. If not found, use 2023 dictionaries as template for 2024\n")
cat("4. Proceed with consolidation strategy using available data\n")

cat("\n=== COMPREHENSIVE SEARCH COMPLETE ===\n")