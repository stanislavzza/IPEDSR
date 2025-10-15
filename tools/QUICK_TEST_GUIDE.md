# Quick Test Guide for add_year_columns_to_database()

## The Problems You Encountered

### 1. Wrong Table Names
The table names you tested don't exist in the database:
- ❌ `ADM2022` - No ADM tables in this database
- ❌ `ef1920` - Table is actually `ef2020` (4-digit year)
- ✅ `sfa1819_p1` - This one exists!

### 2. Column Insertion Bug
The code was trying to reference `ncol(data) + 1` before creating that column, causing "undefined columns selected" error.

**Fixed:** Now properly creates data frame with YEAR inserted at correct position.

### 3. Error Counter Not Working  
The `errors` variable inside the error handler wasn't updating the parent scope count.

**Fixed:** Changed `errors <- errors + 1` to `errors <<- errors + 1`

## Proper Test Tables

Here are actual tables from your database you can test with:

### Tables WITH 4-digit years (should work):
```r
test_tables <- c(
  "ef2020",      # Enrollment - 4 digit year
  "ef2023",      # Enrollment - recent
  "HD2019",      # Directory - 4 digit year  
  "IC2020"       # Institutional characteristics
)
```

### Tables WITH 2-digit year ranges (the tricky ones):
```r
test_tables <- c(
  "sfa1819_p1",  # Financial aid 2018-19, part 1 → should extract 2019
  "sfa1819_p2",  # Financial aid 2018-19, part 2 → should extract 2019
  "ef2010d",     # Has 2010 but ends with 'd'
  "ef2023d"      # Has 2023 but ends with 'd'
)
```

## Recommended Testing Sequence

### Step 1: Test with one simple table
```r
library(IPEDSR)

# Test on a single table first
add_year_columns_to_database(
  tables = "ef2020",
  verbose = TRUE
)

# Check the result
con <- get_ipeds_connection()
DBI::dbGetQuery(con, "PRAGMA table_info(ef2020)")
# Should see YEAR column in the schema

# Check the actual data
head(DBI::dbGetQuery(con, "SELECT * FROM ef2020 LIMIT 5"))
# Should see YEAR column with value 2020
```

### Step 2: Test with year range tables
```r
# Test the tricky 2-digit year range extraction
add_year_columns_to_database(
  tables = c("sfa1819_p1", "sfa1819_p2"),
  verbose = TRUE
)

# Verify
con <- get_ipeds_connection()
head(DBI::dbGetQuery(con, "SELECT * FROM sfa1819_p1 LIMIT 5"))
# Should see YEAR = 2019 (ending year of 2018-19 range)
```

### Step 3: Test error handling
```r
# Test with a mix of good and bad table names
add_year_columns_to_database(
  tables = c("ef2020", "FAKE_TABLE", "sfa1819_p1"),
  verbose = TRUE
)

# Should show:
# - ef2020: either updated or skipped if already done
# - FAKE_TABLE: error (table doesn't exist)
# - sfa1819_p1: either updated or skipped
# And the error count should be 1
```

### Step 4: Test idempotency
```r
# Run on the same table twice
add_year_columns_to_database(tables = "ef2020", verbose = TRUE)
# First run: "Tables updated: 1" (or 0 if already had YEAR)

add_year_columns_to_database(tables = "ef2020", verbose = TRUE)
# Second run: "Tables skipped: 1" (already has YEAR)
```

## Finding Valid Table Names

To see what tables actually exist:

```r
con <- get_ipeds_connection()
all_tables <- DBI::dbListTables(con)

# Find enrollment tables
grep("^ef", all_tables, value = TRUE)

# Find financial aid tables  
grep("^sfa", all_tables, value = TRUE)

# Find recent years (2020-2023)
grep("202[0-3]", all_tables, value = TRUE)

# Find tables with UNITID (most data tables)
has_unitid <- sapply(all_tables[1:20], function(tbl) {
  schema <- DBI::dbGetQuery(con, paste("PRAGMA table_info(", tbl, ")"))
  "UNITID" %in% schema$name
})
names(has_unitid[has_unitid])
```

## What the Output Should Look Like

### Successful update:
```
Checking 3 tables for YEAR columns...
Processing table 1/3: ef2020

YEAR column addition complete:
  Tables updated: 1
  Tables skipped: 2 (already have YEAR or no year in name)
  Errors: 0
```

### With errors:
```
Checking 3 tables for YEAR columns...
Processing table 1/3: ef2020
  Error processing FAKE_TABLE: Table with name FAKE_TABLE does not exist!
Processing table 3/3: sfa1819_p1

YEAR column addition complete:
  Tables updated: 2
  Tables skipped: 0 (already have YEAR or no year in name)
  Errors: 1
```

### Already have YEAR:
```
Checking 3 tables for YEAR columns...
Processing table 1/3: ef2020
Processing table 3/3: sfa1819_p1

YEAR column addition complete:
  Tables updated: 0
  Tables skipped: 3 (already have YEAR or no year in name)
  Errors: 0
```

## Verification Queries

After adding YEAR columns, verify with:

```r
con <- get_ipeds_connection()

# Check schema
DBI::dbGetQuery(con, "PRAGMA table_info(ef2020)")

# Check data
DBI::dbGetQuery(con, "
  SELECT UNITID, YEAR, INSTNM 
  FROM ef2020 
  LIMIT 10
")

# Check year value is correct
DBI::dbGetQuery(con, "
  SELECT DISTINCT YEAR 
  FROM ef2020
")
# Should return: 2020

# For year range tables
DBI::dbGetQuery(con, "
  SELECT DISTINCT YEAR 
  FROM sfa1819_p1
")
# Should return: 2019 (ending year of 2018-19)
```

## Common Issues

1. **"Table does not exist"** → Use correct table names from database
2. **"undefined columns selected"** → Fixed in latest version
3. **Errors = 0 but had errors** → Fixed in latest version  
4. **YEAR = 1920 instead of 2020** → Check year extraction logic
5. **Duplicate YEAR columns** → Shouldn't happen, function checks first

## Ready to Test?

Reload the package and try:

```r
devtools::load_all()

# Start simple
add_year_columns_to_database(
  tables = "ef2020",
  verbose = TRUE
)
```
