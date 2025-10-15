# Bug #7: Schema Inconsistency in Tables Consolidation

**Date Discovered:** October 15, 2024  
**Severity:** HIGH - Blocking all data updates  
**Status:** ✅ FIXED

## Problem Description

When running `update_data()`, the consolidation of metadata tables (tables_all, vartable_all, valuesets_all) failed with two different errors:

**Error 1 - tables_all:**
```
Error: Binder Error: Referenced column 'Release date' not found in table
Candidate bindings: "Release", "TableName", "Description", "TableTitle"
```

**Error 2 - vartable_all/valuesets_all:**
```
Error: Binder Error: Set operations can only apply to expressions with the same number of result columns
```

## Root Cause

### Problem 1: tables_all - Column Count Heuristic

The code used a **column count heuristic** to determine table schema:

```r
if (length(cols) <= 10) {
  # Assumed "early format" without "Release date"
} else {
  # Assumed "later format" with "Release date"
}
```

**This assumption was INCORRECT** because:
- Some early tables (tables06-tables14) have ≤10 columns and no "Release date" ✓
- But some mid-era tables (tables15-tables21) have ≤10 columns WITH "Release date" ✗
- The column count doesn't reliably indicate which columns are present

### Problem 2: vartable_all/valuesets_all - SELECT * with Different Schemas

The code naively used `SELECT *, YEAR FROM table` for all tables:

```r
query <- sprintf('SELECT *, %d as YEAR FROM %s', year_4digit, table)
```

**This FAILED** because:
- vartable06: 4 columns (varName, varTitle, TableName, Tablenumber)
- vartable15: 6 columns (added varType, varLength)
- vartable22: 8+ columns (added DataType, Format, etc.)
- **UNION ALL requires all SELECTs to have the same number of columns**

## Impact

- **Blocked all data updates** - consolidation runs after every import
- **Failed UNION ALL query** - tried to select non-existent "Release date" column from some tables
- **Prevented 2025 data updates** - even though no 2025 data exists yet, consolidation step failed

## Solution

### Solution 1: tables_all - Check Actual Column Names

Changed from **column count check** to **actual column name detection**:

**Before (Lines 974-979):**
```r
if (length(cols) <= 10) {
  # Early format
  query <- sprintf('SELECT ... "Release date" ... FROM %s', table)
} else {
  # Later format  
  query <- sprintf('SELECT ... "Release date" ... FROM %s', table)
}
```

**After (Lines 974-1008):**
```r
# Get actual column names for this table
cols <- DBI::dbListFields(con, table)

# Check which optional columns exist
has_release_date <- any(grepl("^release.?date$", cols, ignore.case = TRUE))
has_f_cols <- any(grepl("^f[0-9]{2}$", cols, ignore.case = TRUE))

# Build SELECT with only columns that exist
if (has_release_date) {
  release_date_col <- cols[grepl("^release.?date$", cols, ignore.case = TRUE)][1]
  select_parts <- c(select_parts, sprintf('"%s"', release_date_col))
} else {
  select_parts <- c(select_parts, "NULL as \"Release date\"")
}

# Similar logic for F11-F16 columns
```

### Solution 2: vartable_all/valuesets_all - Collect All Columns + NULL Placeholders

Changed from **SELECT *** to **explicit column list with NULLs**:

**Before:**
```r
query <- sprintf('SELECT *, %d as YEAR FROM %s', year_4digit, table)
# FAILS because different tables have different column counts
```

**After (Two-Pass Approach):**
```r
# PASS 1: Collect all unique columns across all tables
all_vartable_columns <- list()
for (table in vartable_tables) {
  all_vartable_columns[[table]] <- DBI::dbListFields(con, table)
}
all_unique_vartable_cols <- unique(unlist(all_vartable_columns))

# PASS 2: Build queries with NULL placeholders for missing columns
for (table in vartable_tables) {
  cols <- all_vartable_columns[[table]]
  
  select_parts <- c()
  for (col in all_unique_vartable_cols) {
    if (col %in% cols) {
      select_parts <- c(select_parts, col)
    } else {
      select_parts <- c(select_parts, sprintf("NULL as %s", col))
    }
  }
  select_parts <- c(select_parts, sprintf("%d as YEAR", year_4digit))
  
  query <- sprintf('SELECT %s FROM %s', paste(select_parts, collapse=", "), table)
}
# Now all SELECTs have the same columns, UNION ALL works!
```

## Key Changes

1. **Column Detection:** Uses `DBI::dbListFields()` to get actual column names
2. **Pattern Matching:** `grepl("^release.?date$", cols, ignore.case = TRUE)` finds "Release date" column
3. **Conditional SELECT:** Includes actual column if present, NULL placeholder if not
4. **F Columns Check:** Also checks for F11-F16 columns (later format addition)
5. **Case Insensitive:** Handles variations like "ReleaseDate", "Release date", etc.

## Files Modified

- **R/data_updates.R** (Lines 965-1105):
  - Updated `tables_all` consolidation with actual column detection
  - Implemented `vartable_all` consolidation with two-pass NULL placeholder approach
  - Implemented `valuesets_all` consolidation with two-pass NULL placeholder approach

## Verification

Created test scripts:
- `tools/test_schema_fix.R` - Tests tables_all consolidation
- `tools/test_vartable_schema.R` - Tests vartable_all consolidation  
- `tools/test_complete_consolidation.R` - Tests all three consolidated tables

**Test Results from test_complete_consolidation.R:**
```
✓ tables_all created (3 tables with varying schemas)
✓ vartable_all created (3 tables: 4, 6, and 8 columns)
✓ valuesets_all created (3 tables: 3, 4, and 6 columns)

tables_all output shows:
  - tables06: NULL for "Release date" and F columns
  - tables15: Actual "Release date", NULL for F columns
  - tables22: All columns populated

vartable_all output shows:
  - vartable06: NULL for varType, varLength, DataType, Format
  - vartable15: NULL for DataType, Format only
  - vartable22: All columns populated

valuesets_all output shows:
  - valuesets06: NULL for TableName, Tablenumber, codeDesc
  - valuesets15: NULL for Tablenumber, codeDesc
  - valuesets22: All columns populated

✅ ALL CONSOLIDATION TESTS PASSED!
```

## Schema Variations Across Years

| Year Range | Schema Type | Columns Present |
|------------|-------------|-----------------|
| 2006-2014 | Early | No "Release date", No F columns |
| 2015-2021 | Mid | Has "Release date", No F columns |
| 2022+ | Later | Has "Release date", Has F11-F16 |

Note: These are approximate ranges; actual schema can vary by specific table.

## Why This Bug Occurred

1. **Schema evolution** - IPEDS metadata tables added columns over time
2. **Non-uniform changes** - Not all tables updated in the same year
3. **Brittle heuristic** - Column count is unreliable indicator of schema
4. **UNION ALL strictness** - DuckDB requires all queries to have same columns

## Best Practice Going Forward

✅ **DO:** Check for actual column existence with `%in%` or `grepl()`  
✅ **DO:** Use NULL placeholders for missing columns in UNION queries  
✅ **DO:** Handle case variations with `ignore.case = TRUE`  
❌ **DON'T:** Assume column count indicates schema version  
❌ **DON'T:** Hard-code column lists without checking existence  

## Related Bugs

This is Bug #7 in the series:
1. Bug #1: VARCHAR vs TEXT validation false positives
2. Bug #2: Mixed case table names breaking lookups
3. Bug #3: add_year_column() undefined columns error
4. Bug #4: Unicode encoding preventing imports
5. Bug #5: YEAR as DOUBLE instead of INTEGER
6. Bug #6: Metadata table naming after lowercase standardization
7. **Bug #7: Schema inconsistency in consolidation** ← THIS BUG

## Migration Instructions

The fix is already in `R/data_updates.R`. No database migration needed - the consolidation tables will be rebuilt correctly on next `update_data()` run.

To apply immediately:
```r
devtools::load_all()
# Then run update_data() or just:
con <- get_con()
update_consolidated_dictionaries_new(con, verbose = TRUE)
DBI::dbDisconnect(con)
```

## Statistics

- **Lines Changed:** 104 lines (replacing 21 lines of code)
- **Functions Modified:** `update_consolidated_dictionaries_new()`
- **Test Coverage:** ✅ Verified with tools/test_schema_fix.R
- **User Impact:** HIGH - blocks all updates until fixed

---

**Resolution Status:** ✅ FIXED and TESTED
