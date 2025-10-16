# get_ipeds_table() Refactoring: Use vartable_all and valuesets_all

## Changes Made

Refactored `get_ipeds_table()` to use `vartable_all` and `valuesets_all` instead of year-specific tables (`vartable##` and `valuesets##`).

## Rationale

1. **Single source of truth**: All variable definitions and value mappings are in one place
2. **Year-specific data**: Both `_all` tables include a YEAR column for filtering year-specific definitions
3. **Consistency**: Matches the pattern used in other functions (e.g., `get_cipcodes()`, `get_cip2_counts()`)
4. **Maintainability**: No need to construct and check for year-specific table names

## Technical Details

### Old approach:
```r
# Construct year-specific table names
values_tname <- stringr::str_c("valuesets", year2)  # e.g., "valuesets23"
vars_tname <- stringr::str_c("vartable", year2)     # e.g., "vartable23"

# Query year-specific tables
my_values <- dplyr::tbl(idbc, values_tname) %>%
  dplyr::filter(TableName == table_name) %>%
  ...

my_cols <- dplyr::tbl(idbc, vars_tname) %>%
  dplyr::filter(TableName == table_name) %>%
  ...
```

### New approach:
```r
# Convert 2-digit year to 4-digit year for filtering
year4 <- as.integer(year2)
year4 <- ifelse(year4 <= 50, 2000 + year4, 1900 + year4)

# Query _all tables with year filter
my_values <- dplyr::tbl(idbc, "valuesets_all") %>%
  dplyr::filter(TableName == table_name_upper & YEAR == year4) %>%
  ...

my_cols <- dplyr::tbl(idbc, "vartable_all") %>%
  dplyr::filter(TableName == table_name_upper & YEAR == year4) %>%
  ...
```

## Benefits

1. **Handles year changes**: Variable definitions can change year-to-year, and filtering by YEAR ensures we get the correct definitions for that specific year
2. **Simpler code**: No string concatenation for table names
3. **Better error handling**: If a year doesn't exist, the query returns 0 rows rather than failing on missing table
4. **Future-proof**: Adding new years only requires updating `_all` tables, not creating new year-specific tables

## Testing

Verified functionality with:
- `get_ipeds_table("eap2023", "23")` - Employee data with friendly column names ✓
- `get_ipeds_table("hd2023", "23")` - Directory data with friendly column names ✓
- `get_employees()` - End-to-end test, returns correct results ✓

All functions using `get_ipeds_table()` continue to work correctly.

## Date
October 16, 2025
