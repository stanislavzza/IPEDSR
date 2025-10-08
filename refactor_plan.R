# Simple function refactoring helper script
# This script will help batch update the basic function signatures

library(stringr)

# List of files to update
files_to_update <- c(
  "ipeds_cohorts.R",
  "ipeds_completions.R", 
  "ipeds_programs.R"
)

# For each file, we need to:
# 1. Remove 'idbc' parameter from function definitions
# 2. Add 'idbc <- ensure_connection()' at the start
# 3. Update my_dbListTables calls to remove idbc parameter

# This will be done manually for now to ensure accuracy
cat("Files identified for refactoring:\n")
for(f in files_to_update) {
  cat("-", f, "\n")
}

cat("\nNext steps:\n")
cat("1. Update function signatures\n")
cat("2. Add ensure_connection() calls\n") 
cat("3. Update my_dbListTables calls\n")
cat("4. Replace bare dplyr functions with dplyr:: prefix\n")
cat("5. Test each function\n")