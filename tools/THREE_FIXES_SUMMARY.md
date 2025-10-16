# Bug Fixes: Database Path, Case Sensitivity, and Refactoring

## Summary

Fixed three critical issues in IPEDSR v0.3.0 related to database access and metadata handling.

## 1. Database Re-Download Issue ✅

**Problem**: Package was re-downloading the 2.7GB database unnecessarily.

**Root Cause**: During development with `devtools::load_all()`, the function `get_ipeds_db_path()` was checking for a local stub database file first (11KB empty file in `/data/`), which failed validation, triggering re-download.

**Fix**: Simplified `get_ipeds_db_path()` to always use the persistent user data directory:
- Path: `~/Library/Application Support/IPEDSR/ipeds_2004-2023.duckdb`
- This location is where the database is initially downloaded
- Users won't change this location (and if they do, they deserve a re-download)

**Result**: Database is correctly located and validated, no re-downloads.

---

## 2. get_ipeds_table() Case Sensitivity Bug ✅

**Problem**: `get_ipeds_table()` was returning raw column codes instead of friendly names, causing failures like:
- `get_employees()` error: "object 'Faculty and tenure status' not found"
- All decoded column names were missing

**Root Cause**: 
1. Function converts table name to lowercase: `table_name <- tolower(table_name)`
2. Metadata tables store TableName in UPPERCASE: "EAP2023", "HD2023"
3. Filter `TableName == !!table_name` failed (comparing "EAP2023" == "eap2023")
4. Result: 0 rows returned from vartable and valuesets, no decoding happened

**Fix**: Maintain separate lowercase and uppercase versions:
```r
table_name_lower <- tolower(table_name)  # For accessing data tables
table_name_upper <- toupper(table_name)  # For filtering metadata tables

# Use lowercase for data access
my_data <- dplyr::tbl(idbc, table_name_lower) %>% ...

# Use uppercase for metadata filters
my_values <- dplyr::tbl(idbc, "valuesets_all") %>%
  dplyr::filter(TableName == !!table_name_upper & ...) %>% ...

my_cols <- dplyr::tbl(idbc, "vartable_all") %>%
  dplyr::filter(TableName == !!table_name_upper & ...) %>% ...
```

**Impact**: Fixed **all** calls to `get_ipeds_table()` across the entire package.

---

## 3. Refactor to Use vartable_all and valuesets_all ✅

**Problem**: Function was using year-specific metadata tables (`vartable##`, `valuesets##`) which required:
- String concatenation to build table names
- Assumption that year-specific tables exist
- Different pattern than other functions in the package

**Solution**: Refactored to use `vartable_all` and `valuesets_all` with YEAR filtering:

```r
# Convert 2-digit year to 4-digit for filtering
year4 <- as.integer(year2)
year4 <- ifelse(year4 <= 50, 2000 + year4, 1900 + year4)

# Query _all tables with year and table filters
my_values <- dplyr::tbl(idbc, "valuesets_all") %>%
  dplyr::filter(TableName == !!table_name_upper & YEAR == !!year4) %>%
  dplyr::select(varName, Codevalue, valueLabel) %>%
  dplyr::collect()

my_cols <- dplyr::tbl(idbc, "vartable_all") %>%
  dplyr::select(varName, varTitle, TableName, longDescription, YEAR) %>%
  dplyr::filter(TableName == !!table_name_upper & YEAR == !!year4) %>%
  dplyr::collect() %>%
  dplyr::select(-TableName, -YEAR)
```

**Benefits**:
1. **Year-specific accuracy**: Variable definitions can change year-to-year
2. **Consistency**: Matches pattern used in `get_cipcodes()`, `get_cip2_counts()`
3. **Simpler code**: No table name construction
4. **Single source of truth**: All metadata in one place
5. **Better error handling**: Missing year returns 0 rows instead of table not found error

---

## Testing

All three fixes verified working:

```r
# Test 1: Database location
get_ipeds_db_path()
# Returns: ~/Library/Application Support/IPEDSR/ipeds_2004-2023.duckdb
ipeds_database_exists()  # TRUE

# Test 2 & 3: Column name decoding and refactoring
get_ipeds_table("eap2023", "23")  
# Returns: Friendly column names like "Faculty and tenure status"

get_ipeds_table("hd2023", "23")
# Returns: Friendly column names like "State abbreviation"

get_employees(UNITIDs = c(166027))
# Returns: 72 rows with proper column names (Year, UNITID, Occupation, FacultyStatus, N, N_PT)
```

---

## Files Modified

### R/database_management.R
- Simplified `get_ipeds_db_path()` to always use user data directory

### R/ipeds_utilities.R
- Fixed case sensitivity in `get_ipeds_table()` (lines 244-287)
- Refactored to use `vartable_all` and `valuesets_all` with YEAR filtering

---

## Documentation Created

1. `GET_IPEDS_TABLE_CASE_BUG.md` - Details of case sensitivity bug and fix
2. `GET_IPEDS_TABLE_REFACTOR.md` - Details of refactoring to use _all tables
3. `THREE_FIXES_SUMMARY.md` - This comprehensive summary

---

## Date
October 16, 2025

## Related Issues
- Employee function bug (get_employees failing)
- Survey registry refactoring (17 functions completed)
- Faculty year calculation bug (previously fixed)
