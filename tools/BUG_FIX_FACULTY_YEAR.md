# Bug Fix: get_faculty() Missing 2023 Data

**Date:** October 16, 2025  
**Status:** ✅ FIXED

---

## Problem

The `get_faculty()` function was only returning data up to 2022, even though the database contained tables with 2023 data (`s2023_is`).

### User Report:
```r
get_faculty() |> arrange(UNITID, Rank, Tenure, Year) |> print(n=25)
# Only showed data through 2022, not 2023
```

---

## Root Cause

**Line 28 in original code:**
```r
year <- as.integer(substr(tname, 2,5)) - 1
```

The function was:
1. Extracting year from table name (e.g., `s2023_is` → 2023)
2. **Subtracting 1** from it (2023 → 2022)
3. Using this incorrect year as the Year column in results

### Investigation Results:

| Table Name | Year in Name | Name - 1 | Actual YEAR Column | Mismatch? |
|------------|--------------|----------|-------------------|-----------|
| `s2011_f` | 2011 | **2010** | 2011 | ✗ |
| `s2012_is` | 2012 | **2011** | 2012 | ✗ |
| `s2022_is` | 2022 | **2021** | 2022 | ✗ |
| `s2023_is` | 2023 | **2022** | 2023 | ✗ |

**The `-1` calculation didn't match the actual YEAR column in ANY table!**

The data tables themselves contain a `YEAR` column with the correct year. The function was ignoring this column and using a hardcoded calculation that was off by one year.

---

## Solution

Changed the function to use the actual `YEAR` column from the data instead of calculating from the table name.

### Code Changes:

**Before:**
```r
for(tname in tnames) {
  # use the fall near, not the year on the table name
  year <- as.integer(substr(tname, 2,5)) - 1  # WRONG!

  if(year < 2011 & !before_2011) next
  
  df <- dplyr::tbl(idbc, tname)
  # ... process data ...
  df <- df %>% dplyr::mutate(Year = year)  # Uses incorrect year
}
```

**After:**
```r
for(tname in tnames) {
  # Extract year from table name for filtering logic only
  year_from_name <- as.integer(substr(tname, 2,5))

  if(year_from_name < 2011 & !before_2011) next
  
  df <- dplyr::tbl(idbc, tname)
  # ... collect and process data ...
  
  # Extract the actual year from the YEAR column in the data
  year <- unique(df$YEAR)
  if(length(year) != 1) {
    warning("Multiple or no YEAR values in table ", tname, 
            ". Using year from table name.")
    year <- year_from_name
  }
  
  df <- df %>% dplyr::mutate(Year = year)  # Uses correct year from data
}
```

### Additional Fix:

Fixed conditional join logic for tables without `FACSTAT` column (older tables like `s2011_f`):

```r
# When there's no FACSTAT column, df0 only has UNITID (no Row column)
if( !is.na( match("FACSTAT", names(df)) )) {
  # Has FACSTAT - df0 has both UNITID and Row
  df <- df1 %>%
     dplyr::left_join(df0, by = c("UNITID", "Row")) %>%
     dplyr::left_join(df2, by = c("UNITID", "Row")) %>%
     dplyr::mutate(Year = year)
} else {
  # No FACSTAT - df0 only has UNITID, no Tenure column created
  df <- df1 %>%
     dplyr::left_join(df2, by = c("UNITID", "Row")) %>%
     dplyr::mutate(Year = year)
}
```

---

## Testing Results

### Before Fix:
```
Years: 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022
Range: 2011 to 2022
Total rows: 247
```

### After Fix:
```
Years: 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023
Range: 2011 to 2023  ✅
Total rows: 261
```

### Sample 2023 Data:
```r
# A tibble: 12 × 4
   UNITID  Year Rank                 Tenure                                     
    <int> <int> <chr>                <chr>                                      
 1 218070  2023 All ranks            All full-time instructional staff          
 2 218070  2023 All ranks            With faculty status not on tenure track/No…
 3 218070  2023 All ranks            With faculty status, on tenure track       
 4 218070  2023 All ranks            With faculty status, tenured               
... (etc)
```

---

## Key Insights

1. **Always trust the data over calculations** - The YEAR column in the data is authoritative
2. **The `-1` calculation was mysterious** - No clear reason why it was there
3. **Tables self-document** - If a table has a YEAR column, use it!
4. **Off-by-one errors are subtle** - The function appeared to work, just with wrong years

---

## Impact

- **Severity**: Medium - Function worked but returned incorrect years and missed latest data
- **Scope**: Only affected `get_faculty()` function
- **User Impact**: Users couldn't access 2023 faculty data and had all years off-by-one
- **Data Integrity**: No data corruption, just mislabeling and missing recent year

---

## Recommendation for Other Functions

Check if other data retrieval functions have similar year calculation bugs. Look for:
- `year <- as.integer(substr(tname, X,Y)) - 1` patterns
- Functions that calculate year from table name instead of using data's YEAR column
- Any hardcoded year adjustments without clear documentation

---

## Files Modified

- `R/ipeds_personnel.R` - `get_faculty()` function

---

**Status: ✅ FIXED AND TESTED**  
**Version**: 0.3.0  
**Fix Date**: October 16, 2025
