# Test HD2022 Import Fix
# This script tests the fixed add_year_column function

library(devtools)
load_all()

cat("=" %>% rep(70) %>% paste(collapse=""), "\n")
cat("TESTING HD2022 IMPORT FIX\n")
cat("=" %>% rep(70) %>% paste(collapse=""), "\n\n")

# Read the HD2022 CSV file
downloads_dir <- file.path(rappdirs::user_data_dir('IPEDSR'), 'downloads')
zip_file <- file.path(downloads_dir, 'HD2022.zip')

if (!file.exists(zip_file)) {
  cat("ERROR: HD2022.zip not found\n")
  quit(save = "no", status = 1)
}

# Extract
temp_dir <- tempdir()
extract_dir <- file.path(temp_dir, 'test_hd2022')
dir.create(extract_dir, showWarnings = FALSE, recursive = TRUE)
unzip(zip_file, exdir = extract_dir, overwrite = TRUE)

csv_file <- list.files(extract_dir, pattern = "\\.csv$", full.names = TRUE, ignore.case = TRUE)[1]

cat("Step 1: Reading CSV file...\n")
data <- read.csv(csv_file, stringsAsFactors = FALSE)
cat("✓ Read successfully:", nrow(data), "rows,", ncol(data), "columns\n\n")

cat("Step 2: Cleaning Unicode issues...\n")
# Apply aggressive ASCII cleaning
char_cols <- sapply(data, is.character)
if (any(char_cols)) {
  for (col in names(data)[char_cols]) {
    data[[col]] <- iconv(data[[col]], to = "ASCII", sub = " ")
    data[[col]] <- gsub("[\001-\010\013-\014\016-\037\177]", "", data[[col]])
    data[[col]] <- trimws(data[[col]])
  }
  cat("✓ Cleaned", sum(char_cols), "character columns\n\n")
}

cat("Step 3: Testing add_year_column function...\n")
tryCatch({
  data_with_year <- add_year_column(data, "hd2022")
  cat("✓ add_year_column succeeded!\n")
  cat("  Result:", nrow(data_with_year), "rows,", ncol(data_with_year), "columns\n")
  cat("  YEAR column added:", "YEAR" %in% names(data_with_year), "\n")
  
  if ("YEAR" %in% names(data_with_year)) {
    cat("  YEAR values (unique):", paste(unique(data_with_year$YEAR), collapse=", "), "\n")
    cat("  YEAR position:", which(names(data_with_year) == "YEAR"), "\n")
    cat("  Columns around YEAR:", paste(names(data_with_year)[1:5], collapse=", "), "\n")
  }
  
  cat("\nStep 4: Testing database write...\n")
  con <- ensure_connection()
  
  # Remove existing hd2022 table if it exists
  if (DBI::dbExistsTable(con, "hd2022")) {
    cat("  Removing existing hd2022 table...\n")
    DBI::dbRemoveTable(con, "hd2022")
  }
  
  cat("  Writing to database...\n")
  DBI::dbWriteTable(con, "hd2022", data_with_year, overwrite = TRUE)
  cat("✓ Database write succeeded!\n\n")
  
  # Verify
  cat("Step 5: Verifying import...\n")
  row_count <- DBI::dbGetQuery(con, "SELECT COUNT(*) as n FROM hd2022")$n
  col_info <- DBI::dbGetQuery(con, "PRAGMA table_info(hd2022)")
  
  cat("  Rows in database:", row_count, "\n")
  cat("  Columns in database:", nrow(col_info), "\n")
  cat("  YEAR column present:", "YEAR" %in% col_info$name, "\n")
  
  if ("YEAR" %in% col_info$name) {
    year_info <- col_info[col_info$name == "YEAR", ]
    cat("  YEAR column type:", year_info$type, "\n")
    cat("  YEAR column position:", year_info$cid + 1, "\n")
  }
  
  cat("\n✓✓✓ SUCCESS! HD2022 can now be imported!\n")
  
}, error = function(e) {
  cat("\n✗ ERROR:\n")
  cat("  ", e$message, "\n")
  cat("\nThe fix did not work. Additional debugging needed.\n")
})

cat("\n")
cat("=" %>% rep(70) %>% paste(collapse=""), "\n")
cat("TEST COMPLETE\n")
cat("=" %>% rep(70) %>% paste(collapse=""), "\n")
