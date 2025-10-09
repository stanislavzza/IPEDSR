# Demonstrate incremental IPEDS survey release handling
# This shows how update_data() handles new surveys released throughout the year

library(DBI)
source("R/database_management.R")

cat("INCREMENTAL SURVEY RELEASE DEMONSTRATION\n")
cat("========================================\n\n")

# Check current 2024 data
cat("1. CURRENT 2024 DATA IN DATABASE:\n")
cat("---------------------------------\n")
con <- get_ipeds_connection(read_only = TRUE)
all_tables <- dbListTables(con)
tables_2024 <- grep('2024$', all_tables, value = TRUE)
data_tables_2024 <- setdiff(tables_2024, c("Tables24", "vartable24", "valuesets24"))

cat("Data tables for 2024:", length(data_tables_2024), "\n")
for (table in data_tables_2024) {
  count <- dbGetQuery(con, paste("SELECT COUNT(*) as count FROM", table))$count
  cat("  ", table, ":", count, "rows\n")
}

dbDisconnect(con)

cat("\n2. HOW UPDATE_DATA() HANDLES INCREMENTAL RELEASES:\n")
cat("--------------------------------------------------\n")

cat("When you run update_data(years = 2024):\n\n")

cat("STEP 1: Always scrapes IPEDS website fresh\n")
cat("  - Goes to https://nces.ed.gov/ipeds/datacenter/DataFiles.aspx?year=2024\n")
cat("  - Finds ALL currently available files (data + dictionary)\n")
cat("  - This includes any NEW surveys released since last check\n\n")

cat("STEP 2: Intelligent download decisions\n")
cat("  - Compares found files with local downloads directory\n")
cat("  - Downloads ONLY files that don't exist locally\n")
cat("  - Example: If SFA2024.zip was just released, it downloads it\n")
cat("  - Existing files (HD2024.zip, IC2024.zip, etc.) are skipped\n\n")

cat("STEP 3: Intelligent import decisions\n")
cat("  - Checks which tables exist in database\n")
cat("  - Imports ONLY new tables that don't exist\n")
cat("  - Example: Creates SFA2024 table if it doesn't exist\n")
cat("  - Existing tables (HD2024, IC2024, etc.) are left untouched\n\n")

cat("STEP 4: Updates consolidated tables\n")
cat("  - Regenerates Tables_All, vartable_All, valuesets_All\n")
cat("  - Includes data from any newly imported tables\n")
cat("  - Maintains all existing data + adds new survey data\n\n")

cat("3. PRACTICAL EXAMPLE SCENARIO:\n")
cat("------------------------------\n")

cat("JANUARY 2025: You run update_data(years = 2024)\n")
cat("  Result: Gets 7 surveys available at that time\n")
cat("  Tables: HD2024, IC2024, EFFY2024, FLAGS2024, EFIA2024, DRVC2024, DRVEF122024\n\n")

cat("JUNE 2025: New surveys released, you run update_data(years = 2024) again\n")
cat("  Discovery: Now finds 12 surveys on IPEDS website\n")
cat("  Downloads: Only the 5 NEW survey files (e.g., SFA2024.zip, GR2024.zip, etc.)\n") 
cat("  Imports: Only the 5 NEW tables\n")
cat("  Result: Database now has 12 tables for 2024\n")
cat("  Consolidated tables: Updated to include all 12 surveys\n\n")

cat("SEPTEMBER 2025: Even more surveys released\n")
cat("  Discovery: Now finds 15 surveys total\n")
cat("  Downloads: Only the 3 NEWEST survey files\n")
cat("  Imports: Only the 3 NEWEST tables\n")
cat("  Result: Database now has 15 tables for 2024\n\n")

cat("4. KEY BENEFITS:\n")
cat("----------------\n")
cat("✅ NO DUPLICATES: Existing data never duplicated or overwritten\n")
cat("✅ INCREMENTAL: Only new surveys are downloaded and imported\n")
cat("✅ EFFICIENT: Doesn't re-download or re-import existing data\n")
cat("✅ COMPREHENSIVE: Always gets the complete current picture\n")
cat("✅ AUTOMATIC: Consolidated tables automatically include new data\n")
cat("✅ SAFE: Creates backup before any changes\n\n")

cat("5. RECOMMENDED USAGE PATTERN:\n")
cat("-----------------------------\n")
cat("# Check for new 2024 surveys monthly:\n")
cat("update_data(years = 2024)\n\n")
cat("# Check multiple years if needed:\n")
cat("update_data(years = c(2023, 2024, 2025))\n\n")
cat("# Force complete re-download if something seems wrong:\n")
cat("update_data(years = 2024, force_download = TRUE)\n\n")

cat("The update_data() function is designed specifically to handle\n")
cat("the staggered release pattern of IPEDS surveys throughout the year!\n")