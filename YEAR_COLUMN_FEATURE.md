# Automatic YEAR Column Feature

## Overview

The IPEDSR package now automatically adds a `YEAR` column to all IPEDS tables during data import. This standardizes year information across all tables and makes multi-year analysis much easier.

## How It Works

### During Data Import (Automatic)

When you run `update_data()`, the package now:

1. **Extracts year from table name** - Recognizes multiple year formats:
   - 4-digit years: `ADM2022`, `C2023_A` → 2022, 2023
   - 2-digit year ranges: `sfa1819_p1`, `ef2010d` → 2019, 2010  
   - 2-digit years at end: `ef19` → 2019

2. **Adds YEAR column** - Automatically inserts a `YEAR` column:
   - After `UNITID` if that column exists
   - As the first column otherwise
   - Skips if a year column already exists

3. **Preserves existing data** - No data is lost or modified, just enhanced with year information

### For Existing Databases (Manual)

If you have an existing database downloaded before this feature was added, you can upgrade it:

```r
# Add YEAR columns to all tables in your existing database
add_year_columns_to_database()

# Or update specific tables only
add_year_columns_to_database(tables = c("ADM2022", "ADM2023", "C2022_A"))
```

This will:
- Scan all tables (or specified tables)
- Add YEAR column where missing
- Skip tables that already have a YEAR column
- Skip tables with no year in the name
- Show progress for every 50 tables

## Benefits

### 1. Consistent Data Structure
All tables now have a standard `YEAR` column, making queries more predictable:

```r
# Before: Year might be in table name, column, or nowhere
data <- get_ipeds_table("ADM2022")  # Year only in table name

# After: Year is always available as a column
data <- get_ipeds_table("ADM2022")
head(data$YEAR)  # [1] 2022 2022 2022 2022 2022 2022
```

### 2. Easier Multi-Year Analysis
Combine data from multiple years without manual year tracking:

```r
# Get admission data for multiple years
admissions <- rbind(
  get_ipeds_table("ADM2022"),
  get_ipeds_table("ADM2023"),
  get_ipeds_table("ADM2024")
)

# Year column is automatically included
library(ggplot2)
ggplot(admissions, aes(x = YEAR, y = APPLCN)) +
  geom_boxplot() +
  labs(title = "Applications by Year")
```

### 3. Better Data Validation
The validation system now properly checks for year consistency:

```r
ipeds_data_manager("validate")
# Now gives meaningful feedback about year columns
```

## Technical Details

### Year Extraction Patterns

The `extract_year_from_table_name()` function recognizes:

1. **4-digit years** (2000-2099): `20[0-9]{2}`
   - Examples: `ADM2022`, `EFFY2023`, `C2024_A`

2. **2-digit year ranges**: `([0-9]{2})([0-9]{2})`
   - Examples: `sfa1819_p1` → 2019, `ef0910` → 2010
   - Takes the ending year of the range

3. **Trailing 2-digit years**: `[0-9]{2}$`
   - Examples: `ef19` → 2019, `gr22` → 2022

### Column Positioning

The YEAR column is intelligently positioned:
- **If UNITID exists**: YEAR is placed immediately after UNITID
- **If no UNITID**: YEAR becomes the first column

This ensures the most important identifying columns are at the front.

### Data Integrity

The feature is safe for existing data:
- Never modifies existing year columns
- Only adds columns to tables without year information
- Uses database transactions for atomicity
- Handles encoding and Unicode issues properly

## Examples

### Example 1: New Data Import

```r
# Download and import latest data
update_data()

# All tables now have YEAR columns automatically
chars_2023 <- get_ipeds_table("HD2023")
head(chars_2023[, 1:3])
#   UNITID YEAR           INSTNM
# 1 100654 2023 Alabama A & M...
# 2 100663 2023 University of...
# 3 100690 2023 Amridge Unive...
```

### Example 2: Upgrading Existing Database

```r
# You have an old database from before this feature
library(IPEDSR)

# Check how many tables need YEAR columns
result <- add_year_columns_to_database()

# Output:
# Checking 960 tables for YEAR columns...
# Processing table 1/960: ADM2022
# Processing table 50/960: C2022_A
# Processing table 100/960: ef0910
# ...
# 
# YEAR column addition complete:
#   Tables updated: 847
#   Tables skipped: 113 (already have YEAR or no year in name)
#   Errors: 0
```

### Example 3: Selective Update

```r
# Update only admission tables
adm_tables <- c("ADM2020", "ADM2021", "ADM2022", "ADM2023", "ADM2024")
add_year_columns_to_database(tables = adm_tables, verbose = TRUE)

# Output:
# Checking 5 tables for YEAR columns...
# Processing table 1/5: ADM2020
# Processing table 5/5: ADM2024
# 
# YEAR column addition complete:
#   Tables updated: 5
#   Tables skipped: 0
#   Errors: 0
```

## Migration Path

### For New Users
No action needed! Just use `update_data()` as normal and all tables will have YEAR columns.

### For Existing Users

**Option 1: Update Existing Database (Faster)**
```r
# Add YEAR columns to your current database
add_year_columns_to_database()
```
- ⏱️ Takes 2-5 minutes for 960 tables
- ✅ Preserves all existing data
- ✅ No re-download needed

**Option 2: Fresh Download (Slower)**
```r
# Re-download all data
update_data()
```
- ⏱️ Takes 30-60 minutes depending on internet speed
- ✅ Gets latest data from IPEDS
- ✅ YEAR columns added automatically

## Validation Changes

The validation system now treats missing YEAR columns differently:

**Before this feature:**
- Warning: "Table name contains year but no year columns found"
- This was expected and ignored

**After this feature:**
- Fail: "Table name contains year but YEAR column is missing"
- Suggests running `update_data()` or `add_year_columns_to_database()`

This helps identify tables that haven't been upgraded yet.

## FAQ

**Q: Will this break my existing code?**  
A: No. Adding a column doesn't affect existing queries. Your code will continue to work, and you can optionally use the new YEAR column.

**Q: What if a table already has a year column?**  
A: The function detects existing year columns (case-insensitive) and skips those tables.

**Q: What about tables with no year in the name?**  
A: They're skipped. Only tables with recognizable year patterns get YEAR columns added.

**Q: Can I customize which tables get updated?**  
A: Yes, use the `tables` parameter: `add_year_columns_to_database(tables = c("table1", "table2"))`

**Q: Is this reversible?**  
A: You can remove the YEAR columns with SQL if needed, or restore from a backup. But there's no harm in keeping them.

**Q: Does this affect database performance?**  
A: Minimal impact. Adding one integer column per table is negligible compared to table sizes.

## Support

For issues or questions:
- GitHub Issues: https://github.com/stanislavzza/IPEDSR/issues
- Check validation with: `ipeds_data_manager("validate")`
- View table structure with: `get_ipeds_table("tablename") %>% str()`
