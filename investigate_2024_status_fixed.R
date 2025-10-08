# FIXED INVESTIGATION: Check actual 2024 data status
# This script will properly handle the ZIP -> CSV table naming issue

cat("=== INVESTIGATING 2024 DOWNLOAD AND IMPORT STATUS (FIXED) ===\n")

library(IPEDSR)

cat("\n1. CHECKING DATABASE TABLES for 2024 data...\n")
con <- ensure_connection()
all_tables <- DBI::dbListTables(con)
tables_2024 <- grep("2024", all_tables, value = TRUE)

cat("📊 Total tables in database:", length(all_tables), "\n")
cat("📊 Tables with '2024' in name:", length(tables_2024), "\n")

if (length(tables_2024) > 0) {
  cat("✅ Found 2024 tables:\n")
  for (table in tables_2024) {
    # Handle table names safely - quote them for SQL
    safe_table <- paste0('"', table, '"')
    tryCatch({
      row_count <- DBI::dbGetQuery(con, paste("SELECT COUNT(*) as n FROM", safe_table))$n
      cat("   -", table, "(", format(row_count, big.mark = ","), "rows)\n")
    }, error = function(e) {
      cat("   - ERROR querying", table, ":", e$message, "\n")
    })
  }
} else {
  cat("❌ NO 2024 tables found in database!\n")
}

cat("\n2. CHECKING DOWNLOADS DIRECTORY...\n")
downloads_dir <- get_ipeds_downloads_path()
cat("📁 Downloads directory:", downloads_dir, "\n")

if (dir.exists(downloads_dir)) {
  files_in_downloads <- list.files(downloads_dir, full.names = FALSE)
  cat("📄 Files in downloads directory:", length(files_in_downloads), "\n")
  
  if (length(files_in_downloads) > 0) {
    cat("   Files found:\n")
    for (file in files_in_downloads) {
      cat("   -", file, "\n")
    }
  } else {
    cat("   (directory is empty)\n")
  }
} else {
  cat("❌ Downloads directory does not exist!\n")
}

cat("\n3. SEARCHING FOR 2024 FILES IN PROJECT DIRECTORY...\n")
project_files <- list.files(".", pattern = "2024", recursive = TRUE, full.names = TRUE)
if (length(project_files) > 0) {
  cat("📄 Files with '2024' in project:\n")
  for (file in project_files) {
    cat("   -", file, "\n")
  }
} else {
  cat("❌ No files with '2024' found in project directory\n")
}

cat("\n4. CHECKING WHAT TABLES SHOULD EXIST FOR 2024...\n")
tryCatch({
  # Get the list of files that should exist for 2024
  available_2024 <- scrape_ipeds_files_enhanced(2024, verbose = FALSE)
  if (nrow(available_2024) > 0) {
    cat("🌐 Available 2024 files online:", nrow(available_2024), "\n")
    cat("   Expected table names (after ZIP->CSV conversion):\n")
    clean_names <- gsub("\\.zip$", "", available_2024$table_name)
    for (name in clean_names) {
      exists_in_db <- name %in% all_tables
      status <- if (exists_in_db) "✅ EXISTS" else "❌ MISSING"
      cat("   -", name, status, "\n")
    }
  } else {
    cat("❌ No 2024 files found online\n")
  }
}, error = function(e) {
  cat("❌ Error checking online files:", e$message, "\n")
})

cat("\n5. DATABASE SUMMARY...\n")
years <- get_database_years()
cat("📅 Years in database:", paste(years, collapse = ", "), "\n")
cat("📊 Total years:", length(years), "\n")

# Check for any malformed table names (with .zip extension)
malformed_tables <- grep("\\.zip$", all_tables, value = TRUE)
if (length(malformed_tables) > 0) {
  cat("\n⚠️  FOUND MALFORMED TABLE NAMES (with .zip extension):\n")
  for (table in malformed_tables) {
    cat("   -", table, "(should be cleaned)\n")
  }
} else {
  cat("\n✅ No malformed table names found\n")
}

cat("\n=== INVESTIGATION COMPLETE ===\n")