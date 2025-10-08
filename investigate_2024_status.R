# Step 3 INVESTIGATION: Where Are the Files and Data?
# Let's find out exactly what happened and where everything is

cat("=== INVESTIGATING 2024 DOWNLOAD AND IMPORT STATUS ===\n")

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
    row_count <- DBI::dbGetQuery(con, paste("SELECT COUNT(*) as n FROM", table))$n
    cat("   -", table, "(", format(row_count, big.mark = ","), "rows)\n")
  }
} else {
  cat("❌ NO 2024 tables found in database!\n")
}

cat("\n2. CHECKING DOWNLOAD DIRECTORIES...\n")

# Check the persistent downloads directory
persistent_dir <- get_ipeds_downloads_path()
cat("📁 Persistent downloads directory:", persistent_dir, "\n")
if (dir.exists(persistent_dir)) {
  persistent_files <- list.files(persistent_dir, full.names = FALSE)
  cat("📄 Files in persistent dir:", length(persistent_files), "\n")
  if (length(persistent_files) > 0) {
    for (f in head(persistent_files, 10)) {
      cat("   -", f, "\n")
    }
  }
} else {
  cat("❌ Persistent downloads directory doesn't exist\n")
}

# Check the old project-relative directory  
project_dir <- file.path(getwd(), "data", "downloads")
cat("\n📁 Project downloads directory:", project_dir, "\n")
if (dir.exists(project_dir)) {
  project_files <- list.files(project_dir, full.names = FALSE)
  cat("📄 Files in project dir:", length(project_files), "\n")
  if (length(project_files) > 0) {
    for (f in head(project_files, 10)) {
      cat("   -", f, "\n")
    }
  }
} else {
  cat("❌ Project downloads directory doesn't exist\n")
}

# Check for any 2024 files anywhere in the system
cat("\n3. SEARCHING FOR 2024 FILES SYSTEM-WIDE...\n")
cat("🔍 Searching common locations for 2024 files...\n")

# Check temp directories that might have been used
temp_dirs <- c(
  tempdir(),
  "/var/folders",
  "~/Downloads"
)

found_2024_files <- character(0)
for (dir in temp_dirs) {
  if (dir.exists(dir)) {
    tryCatch({
      files <- list.files(dir, pattern = "2024.*\\.(csv|zip)$", recursive = TRUE, full.names = TRUE)
      if (length(files) > 0) {
        found_2024_files <- c(found_2024_files, files)
      }
    }, error = function(e) {
      # Skip directories we can't access
    })
  }
}

if (length(found_2024_files) > 0) {
  cat("✅ Found 2024 files:\n")
  for (f in head(found_2024_files, 10)) {
    cat("   -", f, "\n")
  }
} else {
  cat("❌ No 2024 files found in common locations\n")
}

cat("\n4. TESTING A MANUAL DOWNLOAD...\n")
cat("🧪 Let's try downloading one file manually to see what happens:\n")

files_2024 <- scrape_ipeds_files_enhanced(2024)
if (nrow(files_2024) > 0) {
  test_file <- files_2024[1, ]
  cat("📋 Testing with:", test_file$table_name, "\n")
  
  csv_path <- download_ipeds_csv(test_file, verbose = TRUE)
  
  if (!is.null(csv_path)) {
    cat("✅ Download path returned:", csv_path, "\n")
    if (file.exists(csv_path)) {
      cat("✅ File exists at returned path\n")
      cat("📏 File size:", round(file.size(csv_path) / 1024 / 1024, 2), "MB\n")
    } else {
      cat("❌ File does NOT exist at returned path\n")
    }
  } else {
    cat("❌ Download returned NULL\n")
  }
}

cat("\n=== INVESTIGATION COMPLETE ===\n")
cat("Now we know exactly where we stand!\n")