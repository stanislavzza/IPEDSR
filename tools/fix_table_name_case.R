# Fix Table Name Case Inconsistency
# 
# This script standardizes all table names to lowercase to fix the issue
# where older tables (2004-2021) use lowercase and newer tables (2022-2024)
# use uppercase, causing functions like get_characteristics() to fail.

library(devtools)
load_all()

cat("=" %>% rep(70) %>% paste(collapse=""), "\n")
cat("IPEDS TABLE NAME STANDARDIZATION\n")
cat("=" %>% rep(70) %>% paste(collapse=""), "\n\n")

# Step 1: Check current state
cat("Step 1: Analyzing current table names...\n")
cat("-" %>% rep(70) %>% paste(collapse=""), "\n")

con <- ensure_connection()
all_tables <- DBI::dbListTables(con)

# Find tables with uppercase letters
uppercase_tables <- all_tables[grepl("[A-Z]", all_tables)]
lowercase_tables <- all_tables[!grepl("[A-Z]", all_tables)]

cat("Total tables in database:", length(all_tables), "\n")
cat("Tables with UPPERCASE letters:", length(uppercase_tables), "\n")
cat("Tables with lowercase only:", length(lowercase_tables), "\n\n")

if (length(uppercase_tables) > 0) {
  cat("Sample uppercase tables:\n")
  print(head(sort(uppercase_tables), 20))
  cat("\n")
}

# Check HD tables specifically
hd_tables <- grep("^[Hh][Dd][0-9]{4}$", all_tables, value = TRUE)
cat("HD tables found:\n")
print(sort(hd_tables))
cat("\n")

# Check if HD2022 exists
if (!("HD2022" %in% all_tables || "hd2022" %in% all_tables)) {
  cat("⚠️  WARNING: HD2022/hd2022 table is missing!\n")
  cat("   This explains why get_characteristics(year=2022) failed.\n")
  cat("   The import likely failed during update_data().\n\n")
}

# Step 2: Ask user if they want to proceed
cat("Step 2: Ready to standardize table names to lowercase?\n")
cat("-" %>% rep(70) %>% paste(collapse=""), "\n")
cat("This will rename", length(uppercase_tables), "tables to lowercase.\n")
cat("For example: HD2023 → hd2023, IC2023_PY → ic2023_py\n\n")

response <- readline(prompt = "Create backup and proceed? (yes/no): ")

if (tolower(response) != "yes" && tolower(response) != "y") {
  cat("\nOperation cancelled by user.\n")
  quit(save = "no")
}

# Step 3: Create backup
cat("\nStep 3: Creating backup...\n")
cat("-" %>% rep(70) %>% paste(collapse=""), "\n")
ipeds_data_manager("backup")

# Step 4: Standardize table names
cat("\nStep 4: Standardizing table names to lowercase...\n")
cat("-" %>% rep(70) %>% paste(collapse=""), "\n")

result <- standardize_table_names_to_lowercase(verbose = TRUE)

# Step 5: Verify results
cat("\nStep 5: Verifying results...\n")
cat("-" %>% rep(70) %>% paste(collapse=""), "\n")

# Re-check database state
all_tables_after <- DBI::dbListTables(con)
uppercase_tables_after <- all_tables_after[grepl("[A-Z]", all_tables_after)]
hd_tables_after <- grep("^hd[0-9]{4}$", all_tables_after, value = TRUE)

cat("Tables with uppercase after fix:", length(uppercase_tables_after), "\n")
cat("HD tables now available:\n")
print(sort(hd_tables_after))
cat("\n")

# Step 6: Test get_characteristics()
cat("\nStep 6: Testing get_characteristics() function...\n")
cat("-" %>% rep(70) %>% paste(collapse=""), "\n")

# Test with year 2023 (should work now)
tryCatch({
  test_years <- as.integer(gsub("hd", "", hd_tables_after))
  test_year <- max(test_years[test_years <= 2023])  # Use most recent year up to 2023
  
  cat("Testing get_characteristics(year =", test_year, ")...\n")
  
  # Get characteristics for a specific institution (if default UNITID set)
  result_test <- get_characteristics(year = test_year)
  
  cat("✓ Success! Retrieved", nrow(result_test), "institution(s)\n")
  cat("  Available years:", paste(sort(test_years), collapse = ", "), "\n")
  
}, error = function(e) {
  cat("✗ Error:", e$message, "\n")
})

# Step 7: Summary
cat("\n")
cat("=" %>% rep(70) %>% paste(collapse=""), "\n")
cat("SUMMARY\n")
cat("=" %>% rep(70) %>% paste(collapse=""), "\n")
cat("Tables renamed:", result$renamed, "\n")
cat("Errors:", result$errors, "\n")
cat("\n")

if (result$renamed > 0 && result$errors == 0) {
  cat("✓ SUCCESS! All table names standardized to lowercase.\n")
  cat("✓ Functions like get_characteristics() should now work correctly.\n")
  cat("✓ Future data imports will use lowercase table names automatically.\n")
} else if (result$errors > 0) {
  cat("⚠️  WARNING: Some tables could not be renamed.\n")
  cat("   Review error messages above for details.\n")
} else {
  cat("ℹ️  Database was already using lowercase table names.\n")
}

# Note about HD2022
if (!("hd2022" %in% all_tables_after)) {
  cat("\n")
  cat("⚠️  NOTE: HD2022 is still missing from the database.\n")
  cat("   The import error during update_data() needs to be fixed separately.\n")
  cat("   Error was: 'undefined columns selected'\n")
  cat("   This is likely a data issue with the HD2022.csv file itself.\n")
}

cat("\n")
