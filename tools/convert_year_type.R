# Convert YEAR columns from DOUBLE to INTEGER
# This script demonstrates how to safely convert YEAR column types

library(devtools)
load_all()

# 1. FIRST: Create a backup (RECOMMENDED)
message("Step 1: Creating backup before conversion...")
ipeds_data_manager("backup")

# 2. Test on a few tables first
message("\nStep 2: Testing on a few tables first...")
test_tables <- c("ADM2022", "sfa1819_p1", "valuesets24")
result <- convert_year_to_integer(tables = test_tables, verbose = TRUE)
print(result)

# 3. Verify the conversion worked
message("\nStep 3: Verifying conversion...")
con <- ensure_connection()
for (tbl in test_tables) {
  schema_query <- paste("PRAGMA table_info(", tbl, ")")
  schema <- DBI::dbGetQuery(con, schema_query)
  year_row <- schema[grep("^year$", schema$name, ignore.case = TRUE), ]
  if (nrow(year_row) > 0) {
    message("  ", tbl, ": YEAR is ", year_row$type)
  }
}

# 4. If test looks good, run on ALL tables
message("\nStep 4: Ready to convert all tables? (Uncomment the line below)")
message("# result <- convert_year_to_integer(verbose = TRUE)")

# Uncomment this line when ready to convert all tables:
# result <- convert_year_to_integer(verbose = TRUE)

# 5. After conversion, run validation to verify
message("\nStep 5: After conversion, run validation:")
message("# ipeds_data_manager('validate')")
