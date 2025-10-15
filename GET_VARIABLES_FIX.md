# Bug #8: get_variables() and get_valueset() Parameter Mismatch

**Date Discovered:** October 15, 2025  
**Severity:** HIGH - User-facing API broken  
**Status:** ✅ FIXED

## Problem Description

Users encountered multiple issues when trying to use `get_variables()` and `get_valueset()`:

```r
# README showed this usage:
variables <- get_variables(year = 2023, table_name = "HD")

# But the actual function signature was:
get_variables(my_table)  # Only accepted a single table name

# This caused errors:
> get_variables(year = 2023, table_name = "HD")
Error: unused arguments (year = 2023, table_name = "HD")

> get_variables("STABBR")  # No year in table name
Error: Table with name vartableNA does not exist!
```

## Root Causes

### Issue 1: Parameter Mismatch
- README documented: `get_variables(year = 2023, table_name = "HD")`
- Actual function: `get_variables(my_table)` - only accepts combined table name like "HD2023"
- No flexibility for separate year parameter

### Issue 2: Poor Error Handling
- If table name had no year (e.g., "STABBR"), function tried to use `vartableNA`
- No fallback to `vartable_all` consolidated table
- Cryptic error messages

### Issue 3: Case Sensitivity
- Functions expected uppercase table names ("HD2023")
- But we standardized to lowercase ("hd2023")
- No handling of case variations

### Issue 4: Limited Filtering
- `get_valueset()` returned all value sets for a table (thousands of rows)
- No way to filter to specific variable (e.g., just "SECTOR" codes)

## Solution

### Enhanced Function Signatures

**Before:**
```r
get_variables(my_table)
get_valueset(my_table)
```

**After:**
```r
get_variables(my_table, year = NULL)
get_valueset(my_table, year = NULL, variable_name = NULL)
```

### Key Improvements

1. **Flexible Year Parameter**
   ```r
   # All of these now work:
   get_variables("HD2023")           # Combined table name
   get_variables("hd2023")           # Lowercase
   get_variables("HD", year = 2023)  # Separate parameters
   ```

2. **Case Insensitive**
   ```r
   # Automatically handles both:
   my_table_lower <- tolower(my_table)
   my_table_upper <- toupper(my_table)
   # Then filters: TableName == my_table_upper | TableName == my_table_lower
   ```

3. **Fallback to Consolidated Tables**
   ```r
   # If year-specific table (vartable23) doesn't exist:
   if (fname %in% all_tables) {
     # Use year-specific table
   } else {
     # Fall back to vartable_all with YEAR filter
   }
   ```

4. **Variable Filtering for get_valueset()**
   ```r
   # Now you can filter to specific variable:
   get_valueset("HD2023", variable_name = "SECTOR")
   # Returns only SECTOR codes instead of all 4000+ value sets
   ```

5. **Better Error Messages**
   ```r
   if (nrow(result) == 0) {
     warning("No variables found for table '", my_table, "' (year: ", yr, "). ",
             "Check if table name is correct.")
   }
   ```

## Code Changes

### get_variables() - Lines 40-118

**New Features:**
- Accepts optional `year` parameter
- Handles table names with or without year suffix
- Case-insensitive table name matching
- Falls back to `vartable_all` if year-specific table doesn't exist
- Better error messages with helpful hints

**Example Implementation:**
```r
get_variables <- function(my_table, year = NULL){
  # Handle year parameter if provided
  if (!is.null(year)) {
    table_prefix <- gsub("\\d{4}|\\d{2}$", "", my_table, perl = TRUE)
    my_table <- paste0(table_prefix, year)
  }
  
  # Normalize to both cases
  my_table_lower <- tolower(my_table)
  my_table_upper <- toupper(my_table)
  
  # Try to extract year (4-digit or 2-digit)
  yr_4digit <- stringr::str_extract(my_table, "\\d{4}")
  yr_2digit <- stringr::str_extract(my_table, "\\d{2}$")
  
  # Build query with case-insensitive filter
  # Fallback to vartable_all if needed
  ...
}
```

### get_valueset() - Lines 121-228

**New Features:**
- All features from `get_variables()` plus:
- Optional `variable_name` parameter for filtering
- Returns only specified variable's codes (e.g., "SECTOR", "CONTROL")

**Example Usage:**
```r
# Get all value sets
all_vals <- get_valueset("HD2023")  # 4000+ rows

# Get just SECTOR codes
sector_codes <- get_valueset("HD2023", variable_name = "SECTOR")  # 11 rows
```

## Files Modified

1. **R/ipeds_utilities.R:**
   - Lines 40-118: Enhanced `get_variables()`
   - Lines 121-228: Enhanced `get_valueset()`

2. **README.md:**
   - Updated example usage to match new API
   - Removed incorrect `year =` and `table_name =` parameter names

3. **man/get_variables.Rd:** (auto-generated)
   - Updated documentation with new parameters
   - Added usage examples

4. **man/get_valueset.Rd:** (auto-generated)
   - Updated documentation with new parameters
   - Added usage examples

## Testing

Created test script: `tools/test_get_variables.R`

**All 7 tests passed:**
```
Test 1: get_variables('HD2023')                                    ✓
Test 2: get_variables('hd2023') - lowercase                        ✓
Test 3: get_variables('HD', year = 2023)                           ✓
Test 4: get_valueset('HD2023')                                     ✓
Test 5: get_valueset('HD2023', variable_name = 'SECTOR')           ✓
Test 6: get_valueset('HD', year = 2023, variable_name = 'CONTROL') ✓
Test 7: get_variables('HD', year = 2015)                           ✓
```

## Usage Examples

### get_variables()

```r
# Method 1: Combined table name (traditional)
vars <- get_variables("HD2023")
vars <- get_variables("hd2023")  # case-insensitive

# Method 2: Separate year parameter (more intuitive)
vars <- get_variables("HD", year = 2023)

# Result has 3 columns:
# - varName: Variable code (e.g., "UNITID", "INSTNM")
# - varTitle: Short description
# - longDescription: Detailed explanation
```

### get_valueset()

```r
# Get all value sets for a table
all_vals <- get_valueset("HD2023")
# Returns 4000+ rows with all codes for all variables

# Get codes for specific variable (recommended)
sector_codes <- get_valueset("HD2023", variable_name = "SECTOR")
# Returns 11 rows:
#   varName Codevalue valueLabel
#   SECTOR  0         Administrative Unit
#   SECTOR  1         Public, 4-year or above
#   SECTOR  2         Private not-for-profit, 4-year or above
#   ...

control_codes <- get_valueset("HD", year = 2023, variable_name = "CONTROL")
# Returns 4 rows:
#   varName Codevalue valueLabel
#   CONTROL 1         Public
#   CONTROL 2         Private not-for-profit
#   CONTROL 3         Private for-profit
#   CONTROL -3        {Not available}
```

## Benefits

1. **User-Friendly:** Matches intuitive API shown in README
2. **Backward Compatible:** Old usage `get_variables("HD2023")` still works
3. **Efficient:** `variable_name` filter prevents loading thousands of unnecessary rows
4. **Robust:** Falls back to consolidated tables if year-specific tables missing
5. **Flexible:** Works with uppercase, lowercase, 4-digit or 2-digit years

## Migration Notes

**No breaking changes!** Old code continues to work:
```r
# This still works:
get_variables("HD2023")
get_valueset("HD2023")

# But now these also work:
get_variables("HD", year = 2023)
get_valueset("HD", year = 2023, variable_name = "SECTOR")
```

## Related Issues

This is Bug #8 in the series. All previous bugs (1-7) also fixed.

---

**Resolution Status:** ✅ FIXED and TESTED
