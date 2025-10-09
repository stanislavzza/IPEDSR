# STEP 1: CAREFUL INVENTORY OF WHAT WE ACTUALLY HAVE
# Let's be systematic and check what's really downloaded vs what we think we have

cat("=== CAREFUL INVENTORY OF ACTUAL STATUS ===\n")

library(IPEDSR)

# 1. Check downloads directory contents
cat("\n1. DOWNLOADS DIRECTORY CONTENTS:\n")
downloads_dir <- rappdirs::user_data_dir("IPEDSR", "IPEDSR") 
downloads_path <- file.path(downloads_dir, "downloads")

cat("Downloads directory:", downloads_path, "\n")
cat("Directory exists:", dir.exists(downloads_path), "\n")

if (dir.exists(downloads_path)) {
  files_in_downloads <- list.files(downloads_path, full.names = FALSE)
  cat("Files in downloads directory:", length(files_in_downloads), "\n")
  
  if (length(files_in_downloads) > 0) {
    cat("Files found:\n")
    for (file in files_in_downloads) {
      file_path <- file.path(downloads_path, file)
      file_size <- file.info(file_path)$size
      cat("  ", file, "(", file_size, "bytes )\n")
    }
  } else {
    cat("❌ Downloads directory is EMPTY\n")
  }
} else {
  cat("❌ Downloads directory does not exist\n")
}

# 2. Check what tables are actually in the database
cat("\n2. DATABASE CONTENTS CHECK:\n")
con <- ensure_connection()
all_tables <- DBI::dbListTables(con)

# 2024 data tables
tables_2024 <- grep("2024", all_tables, value = TRUE)
cat("2024 tables in database:", length(tables_2024), "\n")
for (table in sort(tables_2024)) {
  cat("  ", table, "\n")
}

# 2024 dictionary tables
dict_2024 <- grep("^(tables|valuesets|vartable)24$", all_tables, value = TRUE, ignore.case = TRUE)
cat("\n2024 dictionary tables in database:", length(dict_2024), "\n")
if (length(dict_2024) > 0) {
  for (table in dict_2024) {
    cat("  ✅", table, "\n")
  }
} else {
  cat("❌ NO 2024 dictionary tables found\n")
}

# 3. Check what our scraping function actually finds
cat("\n3. SCRAPING FUNCTION RESULTS:\n")
available_2024 <- scrape_ipeds_files_enhanced(2024, verbose = FALSE)
cat("Files found by scraping function:", nrow(available_2024), "\n")

cat("File names found:\n")
for (file in sort(available_2024$table_name)) {
  cat("  ", file, "\n")
}

# Look specifically for dictionary patterns
dict_patterns <- grep("dict|Dict", available_2024$table_name, ignore.case = TRUE, value = TRUE)
cat("\nDictionary patterns in scraped files:", length(dict_patterns), "\n")
if (length(dict_patterns) > 0) {
  for (file in dict_patterns) {
    cat("  ✅", file, "\n")
  }
} else {
  cat("❌ NO dictionary files found by scraping\n")
}

# 4. Reality check
cat("\n4. REALITY CHECK:\n")
cat("Status summary:\n")
cat("- Downloads directory: ", if (length(files_in_downloads) > 0) "HAS FILES" else "EMPTY", "\n")
cat("- 2024 data tables: ", length(tables_2024), "tables\n")
cat("- 2024 dictionary tables: ", length(dict_2024), "tables\n") 
cat("- Scraping finds dictionary files: ", if (length(dict_patterns) > 0) "YES" else "NO", "\n")

cat("\n=== INVENTORY COMPLETE ===\n")
cat("CONCLUSION: We need to start from scratch on dictionary file acquisition\n")