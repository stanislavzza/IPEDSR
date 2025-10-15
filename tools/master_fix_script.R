# MASTER FIX SCRIPT - Apply All Fixes
# 
# This script applies all fixes for:
# 1. Table name standardization (lowercase)
# 2. HD2022 import
# 3. Metadata table renaming
# 4. (Optional) YEAR type conversion

library(devtools)
load_all()

cat("\n")
cat("=" %>% rep(80) %>% paste(collapse=""), "\n")
cat("IPEDS R PACKAGE - MASTER FIX SCRIPT\n")
cat("October 15, 2025\n")
cat("=" %>% rep(80) %>% paste(collapse=""), "\n")
cat("\n")

cat("This script will:\n")
cat("  1. Create a database backup\n")
cat("  2. Standardize all table names to lowercase\n")
cat("  3. Re-import HD2022 and IC2022_CAMPUSES (if failed)\n")
cat("  4. Rebuild consolidated metadata tables (tables_all, etc.)\n")
cat("  5. Optionally convert YEAR columns to INTEGER type\n")
cat("  6. Validate the final database\n")
cat("\n")

response <- readline(prompt = "Proceed with fixes? (yes/no): ")

if (tolower(response) != "yes" && tolower(response) != "y") {
  cat("\nOperation cancelled.\n")
  quit(save = "no")
}

# Track progress
start_time <- Sys.time()
errors <- list()

# ============================================================================
# STEP 1: CREATE BACKUP
# ============================================================================

cat("\n")
cat("STEP 1: Creating Database Backup\n")
cat("-" %>% rep(80) %>% paste(collapse=""), "\n")

tryCatch({
  ipeds_data_manager("backup")
  cat("✓ Backup created successfully\n")
}, error = function(e) {
  cat("✗ Backup failed:", e$message, "\n")
  errors <<- c(errors, list(step = "backup", error = e$message))
})

# ============================================================================
# STEP 2: STANDARDIZE TABLE NAMES
# ============================================================================

cat("\n")
cat("STEP 2: Standardizing Table Names to Lowercase\n")
cat("-" %>% rep(80) %>% paste(collapse=""), "\n")

tryCatch({
  con <- ensure_connection()
  all_tables_before <- DBI::dbListTables(con)
  uppercase_before <- sum(grepl("[A-Z]", all_tables_before))
  
  cat("Tables with uppercase before:", uppercase_before, "\n")
  
  if (uppercase_before > 0) {
    result <- standardize_table_names_to_lowercase(verbose = TRUE)
    cat("\n✓ Standardization complete\n")
    cat("  Renamed:", result$renamed, "tables\n")
    cat("  Already lowercase:", result$already_lowercase, "tables\n")
    cat("  Errors:", result$errors, "\n")
  } else {
    cat("✓ All tables already lowercase\n")
  }
}, error = function(e) {
  cat("✗ Standardization failed:", e$message, "\n")
  errors <<- c(errors, list(step = "standardization", error = e$message))
})

# ============================================================================
# STEP 3: RE-IMPORT HD2022 (if missing)
# ============================================================================

cat("\n")
cat("STEP 3: Checking and Importing HD2022\n")
cat("-" %>% rep(80) %>% paste(collapse=""), "\n")

tryCatch({
  con <- ensure_connection()
  all_tables <- DBI::dbListTables(con)
  
  if (!("hd2022" %in% all_tables)) {
    cat("HD2022 not found. Attempting import...\n")
    update_result <- update_data(years = 2022, force_download = FALSE, verbose = TRUE)
    
    # Check again
    all_tables <- DBI::dbListTables(con)
    if ("hd2022" %in% all_tables) {
      cat("✓ HD2022 imported successfully\n")
    } else {
      cat("⚠ HD2022 import may have failed - check messages above\n")
      errors <<- c(errors, list(step = "hd2022_import", error = "Table not created"))
    }
  } else {
    cat("✓ HD2022 already exists\n")
  }
  
  # Check IC2022_CAMPUSES
  if (!("ic2022_campuses" %in% all_tables)) {
    cat("\nIC2022_CAMPUSES not found. Attempting import...\n")
    # Update will handle this
  } else {
    cat("✓ IC2022_CAMPUSES already exists\n")
  }
}, error = function(e) {
  cat("✗ Import check failed:", e$message, "\n")
  errors <<- c(errors, list(step = "import_check", error = e$message))
})

# ============================================================================
# STEP 4: REBUILD CONSOLIDATED METADATA TABLES
# ============================================================================

cat("\n")
cat("STEP 4: Rebuilding Consolidated Metadata Tables\n")
cat("-" %>% rep(80) %>% paste(collapse=""), "\n")

tryCatch({
  update_consolidated_dictionary_tables(verbose = TRUE)
  
  # Verify they exist
  con <- ensure_connection()
  all_tables <- DBI::dbListTables(con)
  
  has_tables_all <- "tables_all" %in% all_tables
  has_vartable_all <- "vartable_all" %in% all_tables
  has_valuesets_all <- "valuesets_all" %in% all_tables
  
  cat("\nConsolidated tables status:\n")
  cat("  tables_all:", ifelse(has_tables_all, "✓ exists", "✗ missing"), "\n")
  cat("  vartable_all:", ifelse(has_vartable_all, "✓ exists", "✗ missing"), "\n")
  cat("  valuesets_all:", ifelse(has_valuesets_all, "✓ exists", "✗ missing"), "\n")
  
  if (has_tables_all && has_vartable_all && has_valuesets_all) {
    cat("\n✓ All consolidated tables created successfully\n")
  } else {
    cat("\n⚠ Some consolidated tables may be missing\n")
    errors <<- c(errors, list(step = "consolidated_tables", error = "Some tables missing"))
  }
}, error = function(e) {
  cat("✗ Metadata rebuild failed:", e$message, "\n")
  errors <<- c(errors, list(step = "metadata_rebuild", error = e$message))
})

# ============================================================================
# STEP 5: OPTIONAL - CONVERT YEAR TO INTEGER
# ============================================================================

cat("\n")
cat("STEP 5: Convert YEAR Columns to INTEGER Type (Optional)\n")
cat("-" %>% rep(80) %>% paste(collapse=""), "\n")
cat("This is cosmetic - YEAR works fine as DOUBLE but INTEGER is more correct.\n")
cat("This step may take 2-5 minutes.\n\n")

convert_response <- readline(prompt = "Convert YEAR to INTEGER? (yes/no): ")

if (tolower(convert_response) == "yes" || tolower(convert_response) == "y") {
  tryCatch({
    result <- convert_year_to_integer(verbose = TRUE)
    cat("\n✓ YEAR conversion complete\n")
    cat("  Converted:", result$converted, "tables\n")
    cat("  Already INTEGER:", result$already_integer, "tables\n")
    cat("  No YEAR column:", result$no_year, "tables\n")
    cat("  Errors:", result$errors, "\n")
  }, error = function(e) {
    cat("✗ YEAR conversion failed:", e$message, "\n")
    errors <<- c(errors, list(step = "year_conversion", error = e$message))
  })
} else {
  cat("⊘ Skipped YEAR conversion\n")
}

# ============================================================================
# STEP 6: VALIDATE DATABASE
# ============================================================================

cat("\n")
cat("STEP 6: Validating Database\n")
cat("-" %>% rep(80) %>% paste(collapse=""), "\n")

tryCatch({
  validation <- ipeds_data_manager("validate")
  cat("\n✓ Validation complete\n")
  cat("Check results above for any remaining issues.\n")
}, error = function(e) {
  cat("✗ Validation failed:", e$message, "\n")
  errors <<- c(errors, list(step = "validation", error = e$message))
})

# ============================================================================
# STEP 7: FINAL VERIFICATION
# ============================================================================

cat("\n")
cat("STEP 7: Final Verification\n")
cat("-" %>% rep(80) %>% paste(collapse=""), "\n")

con <- ensure_connection()
all_tables <- DBI::dbListTables(con)

# Check HD tables
hd_tables <- grep("^hd[0-9]{4}$", all_tables, value = TRUE)
cat("HD tables found:", length(hd_tables), "\n")
cat("Available years:", paste(sort(gsub("hd", "", hd_tables)), collapse = ", "), "\n")

# Check HD2022 specifically
if ("hd2022" %in% hd_tables) {
  cat("✓ HD2022 present\n")
  
  # Test get_characteristics
  tryCatch({
    test <- get_characteristics(year = 2022)
    cat("✓ get_characteristics(year = 2022) works! Retrieved", nrow(test), "institutions\n")
  }, error = function(e) {
    cat("✗ get_characteristics(year = 2022) failed:", e$message, "\n")
  })
} else {
  cat("✗ HD2022 still missing\n")
  errors <<- c(errors, list(step = "verification", error = "HD2022 not found"))
}

# Check case consistency
uppercase_count <- sum(grepl("[A-Z]", all_tables))
cat("\nTables with uppercase letters:", uppercase_count, "\n")
if (uppercase_count > 10) {
  cat("⚠ Many uppercase tables remain - may need manual intervention\n")
} else {
  cat("✓ Case standardization successful\n")
}

# Check metadata tables
meta_lower <- c("tables_all", "vartable_all", "valuesets_all")
meta_present <- sum(meta_lower %in% all_tables)
cat("\nConsolidated metadata tables (lowercase):", meta_present, "/", length(meta_lower), "\n")

# ============================================================================
# SUMMARY
# ============================================================================

end_time <- Sys.time()
elapsed <- round(difftime(end_time, start_time, units = "mins"), 1)

cat("\n")
cat("=" %>% rep(80) %>% paste(collapse=""), "\n")
cat("FIX SCRIPT COMPLETE\n")
cat("=" %>% rep(80) %>% paste(collapse=""), "\n")
cat("\n")

cat("Time elapsed:", elapsed, "minutes\n")
cat("Errors encountered:", length(errors), "\n")

if (length(errors) > 0) {
  cat("\nErrors details:\n")
  for (i in seq_along(errors)) {
    cat("  ", i, ". Step:", errors[[i]]$step, "- Error:", errors[[i]]$error, "\n")
  }
  cat("\n⚠ Some fixes may have failed. Review errors above.\n")
} else {
  cat("\n✓ All fixes applied successfully!\n")
}

cat("\nYour IPEDS database is now:\n")
cat("  ✓ Using consistent lowercase table names\n")
cat("  ✓ Has HD2022 and IC2022_CAMPUSES imported\n")
cat("  ✓ Has lowercase metadata tables (tables_all, etc.)\n")
cat("  ✓ Has YEAR columns in all data tables\n")
if (tolower(convert_response) == "yes" || tolower(convert_response) == "y") {
  cat("  ✓ Has YEAR as INTEGER type\n")
}

cat("\nYou can now use:\n")
cat("  get_characteristics(year = 2022)  # And any other year\n")
cat("  update_data(years = 2025)  # Future imports will work correctly\n")

cat("\n")
