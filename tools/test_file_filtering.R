#!/usr/bin/env Rscript
# Test the fixed file filtering function

# Source the updated function
source("R/data_updates.R")

cat("Testing fixed file filtering function...\n")
cat("=====================================\n\n")

# Simulate HTML content with various file types
test_html <- '
<a href="HD2023.zip">HD2023.zip</a>
<a href="HD2023_SPS.zip">HD2023_SPS.zip</a>
<a href="HD2023_SAS.zip">HD2023_SAS.zip</a>
<a href="HD2023_Stata.zip">HD2023_Stata.zip</a>
<a href="HD2023_Data_Stata.zip">HD2023_Data_Stata.zip</a>
<a href="HD2023_Dict.zip">HD2023_Dict.zip</a>
<a href="IC2023.zip">IC2023.zip</a>
<a href="IC2023_CAMPUSES.zip">IC2023_CAMPUSES.zip</a>
<a href="IC2023_CAMPUSES_SPS.zip">IC2023_CAMPUSES_SPS.zip</a>
<a href="IC2023_CAMPUSES_SAS.zip">IC2023_CAMPUSES_SAS.zip</a>
<a href="IC2023_CAMPUSES_Stata.zip">IC2023_CAMPUSES_Stata.zip</a>
'

# Test the function
result <- extract_data_files_comprehensive(test_html, "23")

cat("Input HTML contained these file types:\n")
cat("  - HD2023.zip (should be included)\n")
cat("  - HD2023_SPS.zip (should be excluded)\n")
cat("  - HD2023_SAS.zip (should be excluded)\n")
cat("  - HD2023_Stata.zip (should be excluded)\n")
cat("  - HD2023_Data_Stata.zip (should be excluded)\n")
cat("  - HD2023_Dict.zip (should be excluded)\n")
cat("  - IC2023.zip (should be included)\n")
cat("  - IC2023_CAMPUSES.zip (should be included)\n")
cat("  - IC2023_CAMPUSES_SPS.zip (should be excluded)\n")
cat("  - IC2023_CAMPUSES_SAS.zip (should be excluded)\n")
cat("  - IC2023_CAMPUSES_Stata.zip (should be excluded)\n")

cat("\nFunction returned", length(result), "files:\n")
for (file in result) {
  filename <- basename(file)
  cat("  ✓", filename, "\n")
}

cat("\nExpected files: HD2023.zip, IC2023.zip, IC2023_CAMPUSES.zip\n")

if (length(result) == 3 && 
    any(grepl("HD2023.zip$", result)) &&
    any(grepl("IC2023.zip$", result)) &&
    any(grepl("IC2023_CAMPUSES.zip$", result))) {
  cat("\n✅ SUCCESS: Function correctly filtered files!\n")
} else {
  cat("\n❌ FAILURE: Function did not filter correctly!\n")
}

cat("\nTesting complete.\n")