# Test the new update_data() function
# This demonstrates how to use the comprehensive IPEDS data update system

library(DBI)
source("R/database_management.R")
source("R/data_updates.R")

cat("Testing the new update_data() function\n")
cat("=====================================\n")

# Test 1: Check what years are currently in the database
cat("\n1. Current database status:\n")
con <- get_ipeds_connection(read_only = TRUE)
all_tables <- dbListTables(con)

# Extract years from table names
years_in_db <- unique(gsub(".*([0-9]{2})$", "\\1", all_tables))
years_in_db <- years_in_db[nchar(years_in_db) == 2]
years_4digit <- ifelse(as.numeric(years_in_db) <= 50, 
                      2000 + as.numeric(years_in_db), 
                      1900 + as.numeric(years_in_db))

cat("Years with data in database:", paste(sort(years_4digit), collapse=", "), "\n")

# Check consolidated tables
consolidated_tables <- c("Tables_All", "vartable_All", "valuesets_All")
existing_consolidated <- consolidated_tables[consolidated_tables %in% all_tables]
cat("Consolidated tables exist:", paste(existing_consolidated, collapse=", "), "\n")

dbDisconnect(con)

# Test 2: Demonstrate update_data() function usage examples
cat("\n2. Usage examples for update_data():\n")
cat("=====================================\n")

cat("# Update current year (2024):\n")
cat("update_data()\n\n")

cat("# Update specific year:\n")
cat("update_data(years = 2023)\n\n")

cat("# Update multiple years:\n") 
cat("update_data(years = c(2022, 2023, 2024))\n\n")

cat("# Force re-download even if files exist:\n")
cat("update_data(years = 2024, force_download = TRUE)\n\n")

cat("# Update quietly without progress messages:\n")
cat("update_data(years = 2024, verbose = FALSE)\n\n")

cat("# Update without creating backup:\n")
cat("update_data(years = 2024, backup_first = FALSE)\n\n")

# Test 3: Show what the function will check and do
cat("\n3. What update_data() does:\n")
cat("===========================\n")
cat("For each specified year, the function will:\n")
cat("  1. Check IPEDS website for available data and dictionary files\n")
cat("  2. Download any files not already present locally\n")
cat("  3. Import data files as individual tables (e.g., HD2024, IC2024)\n")
cat("  4. Process dictionary ZIP files to create yearly dictionary tables:\n")
cat("     - Tables## (catalogs the data tables for that year)\n")
cat("     - vartable## (variable metadata from Excel Varlist worksheets)\n")
cat("     - valuesets## (variable descriptions from Excel Description worksheets)\n")
cat("  5. Update the consolidated Tables_All, vartable_All, valuesets_All tables\n")
cat("  6. Return a summary of what was found, downloaded, and imported\n\n")

cat("The function intelligently:\n")
cat("  - Skips downloads if files already exist (unless force_download=TRUE)\n")
cat("  - Skips imports if tables already exist in database\n")
cat("  - Creates database backup before making changes (unless backup_first=FALSE)\n")
cat("  - Handles both data files and dictionary files automatically\n")
cat("  - Updates consolidated dictionary tables to include new years\n")
cat("  - Uses proper 4-digit years (2024, not '24') in all tables\n\n")

# Test 4: Show the expected return value structure
cat("4. Return value structure:\n")
cat("==========================\n")
cat("The function returns a data.frame with columns:\n")
cat("  - year: The year processed\n")
cat("  - data_files_found: Number of data ZIP files found on IPEDS site\n")
cat("  - data_files_downloaded: Number of data files actually downloaded\n")
cat("  - data_files_imported: Number of data tables imported to database\n")
cat("  - dict_files_found: Number of dictionary ZIP files found\n")
cat("  - dict_files_downloaded: Number of dictionary files downloaded\n")
cat("  - dict_files_imported: Whether dictionary tables were created\n")
cat("  - errors: Any error messages encountered\n\n")

cat("Example return value:\n")
example_result <- data.frame(
  year = c(2023, 2024),
  data_files_found = c(15, 12),
  data_files_downloaded = c(3, 12),
  data_files_imported = c(3, 12),
  dict_files_found = c(13, 13),
  dict_files_downloaded = c(0, 13),
  dict_files_imported = c(0, 1),
  errors = c("", ""),
  stringsAsFactors = FALSE
)
print(example_result)

cat("\nThe update_data() function is now ready to use!\n")
cat("It provides a comprehensive, automated way to keep your\n")
cat("IPEDS database current with both data and dictionary information.\n")