library(IPEDSR)

# Test the new database management system
cat("Testing IPEDSR database infrastructure...\n")

# Check if database exists
cat("Database exists:", ipeds_database_exists(), "\n")

# Get database info (will be NULL if not downloaded yet)
info <- get_database_info()
if (!is.null(info)) {
  cat("Database download date:", as.character(info$download_date), "\n")
  cat("Database version:", info$version, "\n")
} else {
  cat("No database metadata found\n")
}

# Test a simple function
cat("\nTesting my_dbListTables function...\n")
tryCatch({
  hd_tables <- my_dbListTables("^HD\\d{4}$")
  cat("Found", length(hd_tables), "HD tables\n")
  cat("Recent HD tables:", tail(hd_tables, 3), "\n")
}, error = function(e) {
  cat("Error:", e$message, "\n")
  cat("This is expected if database hasn't been downloaded yet\n")
})

cat("\nTest complete!\n")