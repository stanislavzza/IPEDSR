# CHECK FOR 2024 DICTIONARY AVAILABILITY
# Investigate if Tables24, valuesets24, vartable24 are available for download

cat("=== CHECKING 2024 DICTIONARY AVAILABILITY ===\n")

library(IPEDSR)

# 1. Check what 2024 files are available from IPEDS
cat("\n1. CHECKING AVAILABLE 2024 FILES FROM IPEDS:\n")
available_2024 <- scrape_ipeds_files_enhanced(2024, verbose = FALSE)

cat("Total 2024 files available:", nrow(available_2024), "\n")
cat("Available file names:\n")
for (file in sort(available_2024$table_name)) {
  cat("  ", file, "\n")
}

# 2. Look specifically for dictionary-related files (ZIP files with Excel workbooks)
cat("\n2. SEARCHING FOR DICTIONARY ZIP FILES:\n")

# Dictionary files are ZIP files containing Excel workbooks with Tables, valuesets, vartable worksheets
# Look for patterns that might indicate dictionary/metadata files
dict_patterns <- c("dict", "tables", "valuesets", "vartable", "meta", "documentation", 
                   "varlist", "codebook", "schema", "variables", "labels")

dict_related <- c()
for (pattern in dict_patterns) {
  matches <- grep(pattern, available_2024$table_name, ignore.case = TRUE, value = TRUE)
  dict_related <- c(dict_related, matches)
}

# Remove duplicates
dict_related <- unique(dict_related)

if (length(dict_related) > 0) {
  cat("Potential dictionary-related ZIP files found (", length(dict_related), "):\n")
  for (file in dict_related) {
    cat("  ✅", file, "\n")
  }
} else {
  cat("❌ No obvious dictionary ZIP files found in 2024 available files\n")
  
  # Check for files that might contain documentation/metadata
  cat("\nChecking for files that might contain dictionary data:\n")
  
  # Look for any files that aren't obviously data tables
  data_table_patterns <- c("^C2024", "^HD2024", "^IC2024", "^EF", "^ADM", "^FLAGS", "^DRV", "^S2024")
  non_data_files <- available_2024$table_name
  
  for (pattern in data_table_patterns) {
    non_data_files <- grep(pattern, non_data_files, value = TRUE, invert = TRUE)
  }
  
  if (length(non_data_files) > 0) {
    cat("  Non-data files that might contain dictionaries:\n")
    for (file in non_data_files) {
      cat("    -", file, "\n")
    }
  }
}

# 3. Check URLs to understand file structure
cat("\n3. EXAMINING FILE DETAILS:\n")
if (nrow(available_2024) > 0) {
  # Show first few files with details
  sample_files <- head(available_2024, 5)
  for (i in 1:nrow(sample_files)) {
    cat("\nFile:", sample_files$table_name[i], "\n")
    cat("  URL:", sample_files$url[i], "\n")
    cat("  Size:", if ("size" %in% names(sample_files)) sample_files$size[i] else "Unknown", "\n")
  }
}

# 4. Check what IPEDS documentation says about dictionaries
cat("\n4. HISTORICAL PATTERN ANALYSIS:\n")
cat("Based on our database analysis:\n")
cat("- Tables: Pattern exists for 2006-2023 (missing: 2018)\n")
cat("- valuesets: Pattern exists for 2006-2023 (complete)\n") 
cat("- vartable: Pattern exists for 2006-2023 (complete)\n")
cat("\nDictionary files are ZIP archives containing Excel workbooks with:\n")
cat("- Tables worksheet: Survey metadata (53 tables in 2023)\n")
cat("- valuesets worksheet: Variable value labels (12,983 records in 2023)\n")
cat("- vartable worksheet: Variable definitions (2,683 variables in 2023)\n")

# 5. Alternative download strategies for Excel-based dictionaries
cat("\n5. EXCEL WORKBOOK EXTRACTION STRATEGY:\n")
cat("If 2024 dictionary ZIP files are found:\n")
cat("1. Download ZIP file containing Excel workbook\n")
cat("2. Extract Excel file from ZIP archive\n") 
cat("3. Read Tables, valuesets, vartable worksheets from Excel\n")
cat("4. Import each worksheet as separate database table\n")
cat("5. Maintain naming consistency (tables24, valuesets24, vartable24)\n")
cat("\nRequired R packages for Excel processing:\n")
cat("- readxl: Read Excel worksheets\n")
cat("- zip/unzip: Handle ZIP archives\n")

cat("\n=== 2024 DICTIONARY CHECK COMPLETE ===\n")