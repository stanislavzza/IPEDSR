# SEARCH FOR 2024 IPEDS DICTIONARY FILES (XX_Dict.zip pattern)
# Look specifically for dictionary files with XX_Dict.zip naming pattern

cat("=== SEARCHING FOR 2024 DICTIONARY FILES (XX_Dict.zip) ===\n")

library(IPEDSR)

# 1. Check our current scraping to see if it captures Dict.zip files
cat("\n1. CHECKING CURRENT SCRAPING FOR DICT.ZIP PATTERNS:\n")
available_2024 <- scrape_ipeds_files_enhanced(2024, verbose = FALSE)

cat("Current 2024 files found:", nrow(available_2024), "\n")
cat("Looking for XX_Dict.zip patterns in current results:\n")

# Look for Dict.zip pattern
dict_files <- grep("_Dict\\.zip$|Dict\\.zip$", available_2024$table_name, ignore.case = TRUE, value = TRUE)

if (length(dict_files) > 0) {
  cat("✅ Dictionary files found in current scraping:\n")
  for (file in dict_files) {
    cat("  ", file, "\n")
  }
} else {
  cat("❌ No XX_Dict.zip files found in current scraping results\n")
  cat("This suggests our scraping function may not be capturing the dictionary column\n")
}

# 2. Examine the scraping function to understand what it captures
cat("\n2. ANALYZING SCRAPING FUNCTION COVERAGE:\n")
cat("Current scraping results show these patterns:\n")
for (file in sort(available_2024$table_name)) {
  cat("  ", file, "\n")
}

# Check if there are any hints about dictionary files in the data we have
cat("\nFile naming patterns observed:\n")
base_names <- unique(gsub("2024.*", "", gsub("\\.zip$", "", available_2024$table_name)))
cat("Base survey names:", paste(base_names, collapse = ", "), "\n")

# 3. Expected dictionary files based on pattern
cat("\n3. EXPECTED 2024 DICTIONARY FILES:\n")
cat("Based on XX_Dict.zip pattern, we should look for:\n")

# Generate expected dictionary file names based on survey components we have
survey_components <- unique(gsub("2024.*", "", gsub("\\.zip$", "", available_2024$table_name)))
survey_components <- survey_components[survey_components != ""]

expected_dict_files <- paste0(survey_components, "_Dict.zip")
cat("Expected dictionary files:\n")
for (file in sort(expected_dict_files)) {
  cat("  ", file, "\n")
}

# 4. Enhanced scraping strategy needed
cat("\n4. ENHANCED SCRAPING STRATEGY REQUIRED:\n")
cat("Our current scraping function needs to be enhanced to:\n")
cat("1. Look for dictionary files in separate/last column on download pages\n")
cat("2. Capture XX_Dict.zip pattern files\n")
cat("3. Parse additional columns beyond main data files\n")

# 5. Manual check approach
cat("\n5. MANUAL VERIFICATION APPROACH:\n")
cat("To verify dictionary availability:\n")
cat("1. Visit IPEDS 2024 download pages manually\n")
cat("2. Look for separate dictionary column\n")
cat("3. Identify specific XX_Dict.zip files available\n")
cat("4. Update scraping function to capture dictionary files\n")

# 6. Test with known pattern
cat("\n6. TESTING SPECIFIC PATTERNS:\n")
cat("Known 2024 survey components from our data:\n")
data_2024_tables <- grep("2024", DBI::dbListTables(ensure_connection()), value = TRUE)
survey_prefixes <- unique(gsub("2024.*", "", data_2024_tables))
survey_prefixes <- survey_prefixes[survey_prefixes != ""]

cat("Survey prefixes in database:", paste(survey_prefixes, collapse = ", "), "\n")
cat("Corresponding expected dictionary files:\n")
for (prefix in sort(survey_prefixes)) {
  expected_dict <- paste0(prefix, "_Dict.zip")
  cat("  ", expected_dict, "\n")
}

# 7. Enhanced scraping function needed
cat("\n7. NEXT STEPS:\n")
cat("Required actions:\n")
cat("1. Enhance scrape_ipeds_files_enhanced() to capture dictionary column\n")
cat("2. Look specifically for XX_Dict.zip pattern files\n")
cat("3. Download and process dictionary ZIP files containing Excel workbooks\n")
cat("4. Extract Tables, valuesets, vartable worksheets from Excel files\n")
cat("5. Import as tables24, valuesets24, vartable24 to database\n")

cat("\n=== DICTIONARY SEARCH ANALYSIS COMPLETE ===\n")
cat("CONCLUSION: Need enhanced scraping to capture dictionary files from separate column\n")