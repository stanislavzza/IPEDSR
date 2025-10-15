# Table Name Case Standardization

## The Problem

### Symptom:
```r
> get_characteristics(year = 2022)
Error: Invalid year specified. Available: 2023, 2024, 2004-2021
```

Even though HD2022 data exists in the database, `get_characteristics()` can't find it!

### Root Cause:
**IPEDS changed their filename conventions** between 2021 and 2023:

**Historical (2004-2021):**
- Filenames: `hd2004.zip`, `hd2005.zip`, ..., `hd2021.zip` (lowercase)
- Table names: `hd2004`, `hd2005`, ..., `hd2021` (lowercase)

**Recent (2023-2024):**
- Filenames: `HD2023.zip`, `HD2024.zip` (UPPERCASE)
- Table names: `HD2023`, `HD2024` (UPPERCASE)

**Impact:**
- Database has ~777 lowercase tables and ~105 uppercase tables
- Functions that search for tables by year patterns fail
- Example: `^HD\\d{4}$` matches `HD2023` but not `hd2004`
- Example: `^hd[0-9]{4}$` matches `hd2004` but not `HD2023`

### Why HD2022 is Missing:
Separate issue - the import failed with "undefined columns selected" error, possibly due to:
1. Column name changes in the HD2022.csv file
2. Encoding issues in the source data
3. Structural changes in the 2022 data format

## The Solution

### 1. Standardize Existing Tables (One-Time Fix)

Run the standardization script to rename all uppercase tables to lowercase:

```r
library(devtools)
load_all()

# This will:
# 1. Create a backup
# 2. Rename HD2023 → hd2023, HD2024 → hd2024, etc.
# 3. Verify the changes
standardize_table_names_to_lowercase()
```

Or use the interactive script:
```r
source("tools/fix_table_name_case.R")
```

### 2. Prevent Future Issues (Permanent Fix)

**Already Fixed!** The code now automatically converts all new table names to lowercase:

```r
# In process_data_files_new() function:
table_name <- tolower(gsub("\\.zip$", "", filename, ignore.case = TRUE))
```

This means:
- ✓ Future imports of `HD2025.zip` will create table `hd2025`
- ✓ Future imports of `IC2025_PY.zip` will create table `ic2025_py`
- ✓ Consistent lowercase naming going forward

## What Changes

### Before Standardization:
```r
> DBI::dbListTables(con) %>% grep("^[Hh][Dd][0-9]{4}$", ., value=TRUE) %>% sort()
[1] "hd2004" "hd2005" ... "hd2021" "HD2023" "HD2024"

> get_characteristics(year = 2023)
Error: Invalid year specified
```

### After Standardization:
```r
> DBI::dbListTables(con) %>% grep("^hd[0-9]{4}$", ., value=TRUE) %>% sort()
[1] "hd2004" "hd2005" ... "hd2021" "hd2023" "hd2024"

> get_characteristics(year = 2023)
# Returns data successfully!
```

## Technical Details

### Safe Operation:
- Uses DuckDB's `ALTER TABLE ... RENAME TO` (atomic operation)
- Each table renamed individually (errors don't cascade)
- Idempotent (safe to run multiple times)
- Checks for naming conflicts before renaming

### What Gets Renamed:
All tables with uppercase letters, typically:
- `HD2023` → `hd2023`
- `HD2024` → `hd2024`
- `IC2023_PY` → `ic2023_py`
- `EF2023A` → `ef2023a`
- `FLAGS2023` → `flags2023`
- And ~100 other recent tables

### What Doesn't Change:
- Table contents (data unchanged)
- Column names (unchanged)
- Table structure (unchanged)
- Performance (no data movement)

### Error Handling:
If lowercase name already exists:
```
⚠ Cannot rename HD2023 → hd2023 (target already exists)
```
This is rare but handled gracefully - the conflict is logged and skipped.

## Testing After Fix

### 1. Verify Table Names:
```r
con <- ensure_connection()
all_tables <- DBI::dbListTables(con)

# Should be 0 or very few
uppercase_count <- sum(grepl("[A-Z]", all_tables))
cat("Uppercase tables remaining:", uppercase_count, "\n")

# Should show hd2004-hd2024 (except hd2022 if import failed)
hd_tables <- grep("^hd[0-9]{4}$", all_tables, value = TRUE)
print(sort(hd_tables))
```

### 2. Test Year-Based Functions:
```r
# Should work for all available years
get_characteristics(year = 2023)
get_characteristics(year = 2021)
get_characteristics(year = 2019)

# Should show correct available years
my_dbListTables(search_string = "^hd\\d{4}$")
```

### 3. Test New Imports:
```r
# Import new year - should create lowercase table automatically
update_data(years = 2024, force_download = FALSE)

# Verify it's lowercase
"hd2024" %in% DBI::dbListTables(con)  # Should be TRUE
"HD2024" %in% DBI::dbListTables(con)  # Should be FALSE
```

## Fixing HD2022 Import Failure

The HD2022 import failed with "undefined columns selected". To investigate:

### 1. Check the CSV File:
```r
# Extract and inspect
zip_file <- "~/Library/Application Support/IPEDSR/downloads/HD2022.zip"
temp_dir <- tempdir()
unzip(zip_file, exdir = temp_dir)

csv_file <- list.files(temp_dir, pattern = "hd2022.*\\.csv$", 
                       full.names = TRUE, ignore.case = TRUE)[1]

# Read just the header
header <- read.csv(csv_file, nrows = 1, stringsAsFactors = FALSE)
names(header)  # Check for unusual column names

# Check for duplicates
sum(duplicated(names(header)))  # Should be 0
```

### 2. Compare with HD2021 and HD2023:
```r
# Get column names from working tables
con <- ensure_connection()

hd2021_schema <- DBI::dbGetQuery(con, "PRAGMA table_info(hd2021)")
hd2023_schema <- DBI::dbGetQuery(con, "PRAGMA table_info(hd2023)")

# See what changed
setdiff(hd2021_schema$name, hd2023_schema$name)  # Removed in 2023
setdiff(hd2023_schema$name, hd2021_schema$name)  # Added in 2023
```

### 3. Manual Import (if needed):
```r
# Read the CSV manually with error handling
csv_file <- "path/to/HD2022.csv"

data <- read.csv(csv_file, stringsAsFactors = FALSE, 
                 check.names = FALSE,  # Preserve original names
                 row.names = NULL)     # Avoid row name issues

# Clean column names if needed
names(data) <- make.names(names(data), unique = TRUE)

# Add YEAR column
data$YEAR <- 2022

# Write to database
con <- ensure_connection()
DBI::dbWriteTable(con, "hd2022", data, overwrite = TRUE)
```

## Prevention for Future

### Code Changes Made:
1. **Import Process** (`process_data_files_new`):
   - Automatically converts all table names to lowercase
   - Applies to all new imports going forward

2. **Standardization Function** (`standardize_table_names_to_lowercase`):
   - Available to fix existing databases
   - Can be run anytime to normalize naming

### Best Practices:
1. **Always use lowercase** when referring to tables in code
2. **Use case-insensitive search** patterns when necessary:
   ```r
   # Instead of: grep("^HD", tables)
   # Use: grep("^hd", tables, ignore.case = TRUE)
   ```
3. **Test with multiple years** after any schema changes
4. **Backup before bulk operations** like standardization

## Rollback (if needed)

If you need to undo the standardization:

```r
# Restore from backup
ipeds_data_manager("restore")

# Or manually rename back to uppercase:
con <- ensure_connection()
tables_to_rename <- c("hd2023", "hd2024")  # etc.

for (old_name in tables_to_rename) {
  new_name <- toupper(old_name)
  query <- sprintf("ALTER TABLE %s RENAME TO %s", old_name, new_name)
  DBI::dbExecute(con, query)
}
```

## Summary

**Problem**: Mixed case table names broke year-based lookup functions

**Solution**: 
- ✅ Standardize existing tables to lowercase (one-time fix)
- ✅ Modified import code to use lowercase automatically (permanent fix)

**Result**: 
- All tables use consistent lowercase naming
- Functions like `get_characteristics()` work correctly
- Future imports maintain consistency

**Remaining Issue**: HD2022 import failure needs separate investigation (data format issue, not naming issue)
