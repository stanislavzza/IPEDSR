# COMPLETE 2024 DOWNLOAD: Get remaining missing files
# This script will identify and download only the missing 2024 files

cat("=== COMPLETING 2024 IPEDS DATA DOWNLOAD ===\n")

library(IPEDSR)

cat("\n1. CHECKING CURRENT STATUS...\n")
con <- ensure_connection()
existing_tables <- DBI::dbListTables(con)
existing_2024 <- grep("2024", existing_tables, value = TRUE)

cat("📊 Existing 2024 tables in database:", length(existing_2024), "\n")
for (table in existing_2024) {
  row_count <- DBI::dbGetQuery(con, paste("SELECT COUNT(*) as n FROM", table))$n
  cat("   ✅", table, "(", format(row_count, big.mark = ","), "rows)\n")
}

cat("\n2. CHECKING AVAILABLE FILES ONLINE...\n")
available_2024 <- scrape_ipeds_files_enhanced(2024, verbose = FALSE)
cat("🌐 Available 2024 files online:", nrow(available_2024), "\n")

# Clean the table names for comparison (remove .zip extension)
available_clean_names <- gsub("\\.zip$", "", available_2024$table_name)

cat("\n3. IDENTIFYING MISSING FILES...\n")
missing_files <- available_clean_names[!available_clean_names %in% existing_2024]
cat("❌ Missing from database:", length(missing_files), "files\n")

if (length(missing_files) > 0) {
  cat("   Missing files:\n")
  for (file in missing_files) {
    cat("   -", file, "\n")
  }
  
  # Filter available_2024 to only include missing files
  missing_indices <- which(available_clean_names %in% missing_files)
  files_to_download <- available_2024[missing_indices, ]
  
  cat("\n4. DOWNLOADING AND IMPORTING MISSING FILES...\n")
  cat("🔄 Starting download of", nrow(files_to_download), "missing files...\n")
  
  # Use batch download with force_redownload=FALSE to skip existing tables
  results <- batch_download_ipeds_files(
    files_to_download,
    force_redownload = FALSE,  # Don't redownload existing tables
    verbose = TRUE
  )
  
  cat("\n5. PROCESSING RESULTS...\n")
  successful_downloads <- sum(results$download_success)
  successful_imports <- sum(results$import_success)
  
  cat("📥 Downloads completed:", successful_downloads, "/", nrow(files_to_download), "\n")
  cat("📊 Imports completed:", successful_imports, "/", nrow(files_to_download), "\n")
  
  # Show any failures
  failures <- results[!results$import_success, ]
  if (nrow(failures) > 0) {
    cat("\n⚠️  Failed imports:\n")
    for (i in seq_len(nrow(failures))) {
      cat("   -", failures$table_name[i], ":", failures$error_message[i], "\n")
    }
  }
  
  # Show successful imports with row counts
  successes <- results[results$import_success, ]
  if (nrow(successes) > 0) {
    cat("\n✅ Successfully imported:\n")
    for (i in seq_len(nrow(successes))) {
      cat("   -", successes$table_name[i], "(", format(successes$row_count[i], big.mark = ","), "rows)\n")
    }
  }
  
} else {
  cat("✅ All available 2024 files are already in the database!\n")
}

cat("\n6. FINAL VERIFICATION...\n")
# Re-check database status
final_tables <- DBI::dbListTables(ensure_connection())
final_2024 <- grep("2024", final_tables, value = TRUE)

cat("📊 Total 2024 tables after processing:", length(final_2024), "\n")
cat("🎯 Expected:", nrow(available_2024), "Available:", length(final_2024), "\n")

if (length(final_2024) == nrow(available_2024)) {
  cat("🎉 SUCCESS: All available 2024 files are now in the database!\n")
  
  total_rows <- 0
  cat("\n📊 Final 2024 data summary:\n")
  for (table in sort(final_2024)) {
    row_count <- DBI::dbGetQuery(ensure_connection(), paste("SELECT COUNT(*) as n FROM", table))$n
    total_rows <- total_rows + row_count
    cat("   ", table, ":", format(row_count, big.mark = ","), "rows\n")
  }
  cat("\n📊 Total 2024 records:", format(total_rows, big.mark = ","), "\n")
  
} else {
  missing_count <- nrow(available_2024) - length(final_2024)
  cat("⚠️  Still missing", missing_count, "files from the complete set\n")
}

cat("\n=== DOWNLOAD COMPLETION PROCESS FINISHED ===\n")