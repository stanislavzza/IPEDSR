# Bug Fix: get_ipeds_table() Case Sensitivity Issue

## Problem
`get_ipeds_table()` was failing to decode column names and values for all tables because of a case sensitivity mismatch.

## Root Cause
1. The function converts table name to lowercase: `table_name <- tolower(table_name)` (line 244)
2. It then filters vartable and valuesets using this lowercase name
3. BUT the TableName column in vartable and valuesets is stored in UPPERCASE (e.g., "EAP2023", "HD2023")
4. The filter `TableName == !!table_name` compares "EAP2023" == "eap2023" which fails
5. Result: 0 rows returned, so no column names or values get decoded

## Impact
- **ALL calls to `get_ipeds_table()` were broken** - returning raw column codes instead of friendly names
- `get_employees()` failed with "object 'Faculty and tenure status' not found"
- Any function relying on decoded column names would fail

## Fix
Changed the function to maintain both lowercase and uppercase versions:
- `table_name_lower` - for accessing the actual database table (tables are lowercase)
- `table_name_upper` - for filtering metadata tables (TableName is uppercase)

### Changes in R/ipeds_utilities.R

Line 244-246:
```r
# OLD
table_name <- tolower(table_name)

# NEW  
table_name_lower <- tolower(table_name)
table_name_upper <- toupper(table_name)
```

Line 249:
```r
# OLD
my_data   <- dplyr::tbl(idbc, table_name) %>%

# NEW
my_data   <- dplyr::tbl(idbc, table_name_lower) %>%
```

Line 263:
```r
# OLD
dplyr::filter(TableName == !!table_name) %>%

# NEW
dplyr::filter(TableName == !!table_name_upper) %>%
```

Line 284:
```r
# OLD
dplyr::filter(TableName == !!table_name) %>%

# NEW
dplyr::filter(TableName == !!table_name_upper) %>%
```

## Testing
Verified the fix works with multiple table types:
- `get_ipeds_table("eap2023", "23")` - Employee tables
- `get_ipeds_table("hd2023", "23")` - Directory tables
- `get_employees()` now works correctly

## Date
October 16, 2025
