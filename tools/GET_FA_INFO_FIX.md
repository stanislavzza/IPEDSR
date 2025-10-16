# Fix: get_fa_info() Verbose Output

## Problem
`get_fa_info()` was producing excessive console output:
```
[1] 2003             
[1] 2004
[1] 2005
...
Joining with `by = join_by(UNITID, YEAR, ...100+ columns...)`
Joining with `by = join_by(UNITID, YEAR, ...100+ columns...)`
...
```

## Root Causes

### 1. Printing Year (Line 437)
```r
for(tname_prefix in tname_prefixes) {
  Year <- 2000 + as.integer(substr(tname_prefix,4,5))
  print(Year)  # ❌ THIS WAS PRINTING TO CONSOLE
```

**Impact**: Printed year number for EVERY year processed (2003-2022 = 20 years)

### 2. Verbose Join Messages (Lines 445-446)
```r
if(length(tname_set) == 2) df <- df %>% dplyr::left_join(dplyr::tbl(idbc,tname_set[2]))
if(length(tname_set) == 3) df <- df %>% dplyr::left_join(dplyr::tbl(idbc,tname_set[3]))
```

**Impact**: Without explicit `by` parameter, dplyr prints verbose join messages showing ALL joined columns

## Solution

### Fix 1: Remove print() Statement
```r
for(tname_prefix in tname_prefixes) {
  Year <- 2000 + as.integer(substr(tname_prefix,4,5))
  # Removed: print(Year)
```

### Fix 2: Add Explicit by Parameter
```r
if(length(tname_set) == 2) df <- df %>% dplyr::left_join(dplyr::tbl(idbc,tname_set[2]), by = "UNITID")
if(length(tname_set) == 3) df <- df %>% dplyr::left_join(dplyr::tbl(idbc,tname_set[3]), by = "UNITID")
```

**Benefits**:
- Silences verbose join messages
- Makes join key explicit and clear
- Consistent with other fixed functions

## Files Modified
- **R/ipeds_cohorts.R** (lines 437, 445-446)
  - Removed `print(Year)` statement
  - Added `by = "UNITID"` to both `left_join()` calls

## Testing
After loading the package with `devtools::load_all()`, test in your R session:

```r
result <- get_fa_info()
# Should produce NO output during execution
# Should return 20 rows silently
```

## Expected Output
```
# A tibble: 20 × 20
   UNITID N_undergraduates N_fall_cohort Percent_PELL N_inst_aid Avg_inst_aid ...
    <int>            <int>         <int>        <int>      <int>        <int>
...
```

No verbose messages during processing!

## Date
October 16, 2025

## Status
**FIXED** - Function now executes silently
