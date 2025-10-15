# Metadata Table Naming Fix

## Problem

After standardizing data tables to lowercase (hd2022, ic2023, etc.), **metadata tables** still had mixed case references in the code:

**Metadata tables affected:**
- `Tables06` through `Tables24` → should be `tables06` through `tables24`
- `vartable06` through `vartable24` (already lowercase, no change needed)
- `valuesets06` through `valuesets24` (already lowercase, no change needed)
- `Tables_All` → should be `tables_all`
- `vartable_All` → should be `vartable_all` 
- `valuesets_All` → should be `valuesets_all`

**Code issues:**
1. **Hard-coded uppercase references**: `Tables_All`, `Tables22`, etc.
2. **Case-sensitive grep patterns**: `^Tables[0-9]{2}$` wouldn't match lowercase
3. **Table creation**: New tables created with uppercase prefix

## Fixes Applied

### 1. Updated Table Creation (Lines 846-848)

**Before:**
```r
tables_name <- paste0("Tables", year_2digit)  # Creates Tables22, Tables23, etc.
```

**After:**
```r
tables_name <- paste0("tables", year_2digit)  # Creates tables22, tables23, etc.
```

### 2. Updated Grep Patterns (Lines 957-959)

**Before:**
```r
tables_tables <- grep('^Tables[0-9]{2}$', all_tables, value = TRUE)  # Case-sensitive
```

**After:**
```r
tables_tables <- grep('^tables[0-9]{2}$', all_tables, value = TRUE, ignore.case = TRUE)
```

### 3. Updated Consolidated Table Names (Line 982)

**Before:**
```r
CREATE OR REPLACE TABLE Tables_All AS ...
```

**After:**
```r
CREATE OR REPLACE TABLE tables_all AS ...
```

### 4. Updated Exclusion Patterns

**Before:**
```r
tables <- all_tables[!grepl("^(ipeds_|sqlite_|Tables|vartable|valuesets)", all_tables)]
```

**After:**
```r
tables <- all_tables[!grepl("^(ipeds_|sqlite_|tables|vartable|valuesets)", all_tables, ignore.case = TRUE)]
```

## Migration Plan

### Step 1: Identify Existing Uppercase Metadata Tables

```r
library(devtools)
load_all()

con <- ensure_connection()
all_tables <- DBI::dbListTables(con)

# Find uppercase metadata tables
uppercase_meta <- grep("^(Tables|Valuesets|Vartable)", all_tables, value = TRUE)
cat("Uppercase metadata tables:\n")
print(uppercase_meta)
```

### Step 2: Rename Existing Tables to Lowercase

The `standardize_table_names_to_lowercase()` function will handle this:

```r
# This will rename Tables22 → tables22, Tables_All → tables_all, etc.
standardize_table_names_to_lowercase(verbose = TRUE)
```

### Step 3: Verify and Rebuild Consolidated Tables

After renaming, rebuild the consolidated tables:

```r
# Rebuild consolidated dictionary tables with new lowercase names
update_consolidated_dictionary_tables(verbose = TRUE)
```

### Step 4: Update Any Custom Code

If you have custom scripts that reference these tables, update them:

```r
# OLD:
DBI::dbReadTable(con, "Tables_All")
DBI::dbReadTable(con, "Tables23")

# NEW:
DBI::dbReadTable(con, "tables_all")
DBI::dbReadTable(con, "tables23")
```

## Complete Migration Script

```r
library(devtools)
load_all()

cat("=" %>% rep(70) %>% paste(collapse=""), "\n")
cat("METADATA TABLE NAMING STANDARDIZATION\n")
cat("=" %>% rep(70) %>% paste(collapse=""), "\n\n")

# Step 1: Backup
cat("Step 1: Creating backup...\n")
ipeds_data_manager("backup")

# Step 2: Identify uppercase metadata tables
cat("\nStep 2: Identifying uppercase metadata tables...\n")
con <- ensure_connection()
all_tables <- DBI::dbListTables(con)
uppercase_meta <- grep("^Tables", all_tables, value = TRUE)
cat("Found", length(uppercase_meta), "uppercase metadata tables:\n")
print(uppercase_meta)

# Step 3: Standardize all table names
cat("\nStep 3: Standardizing all table names to lowercase...\n")
result <- standardize_table_names_to_lowercase(verbose = TRUE)

# Step 4: Rebuild consolidated tables
cat("\nStep 4: Rebuilding consolidated dictionary tables...\n")
update_consolidated_dictionary_tables(verbose = TRUE)

# Step 5: Verify
cat("\nStep 5: Verifying...\n")
all_tables_after <- DBI::dbListTables(con)
uppercase_remaining <- grep("^Tables", all_tables_after, value = TRUE)

cat("Uppercase metadata tables remaining:", length(uppercase_remaining), "\n")
if (length(uppercase_remaining) > 0) {
  cat("WARNING: These tables still have uppercase:\n")
  print(uppercase_remaining)
} else {
  cat("✓ All metadata tables now lowercase!\n")
}

# Check for consolidated tables
cat("\nConsolidated tables:\n")
cat("  tables_all exists:", "tables_all" %in% all_tables_after, "\n")
cat("  vartable_all exists:", "vartable_all" %in% all_tables_after, "\n")
cat("  valuesets_all exists:", "valuesets_all" %in% all_tables_after, "\n")

cat("\n✓ Migration complete!\n")
```

## What Changed in Your Database

### Before Standardization:
```
Tables06, Tables07, ..., Tables24    (uppercase T)
vartable06, vartable07, ..., vartable24  (lowercase)
valuesets06, valuesets07, ..., valuesets24  (lowercase)
Tables_All    (uppercase T)
vartable_All  (uppercase A)
valuesets_All (uppercase A)
```

### After Standardization:
```
tables06, tables07, ..., tables24    (all lowercase)
vartable06, vartable07, ..., vartable24  (unchanged)
valuesets06, valuesets07, ..., valuesets24  (unchanged)
tables_all    (all lowercase)
vartable_all  (all lowercase)
valuesets_all (all lowercase)
```

## Impact on Package Functions

### Functions that Use Metadata Tables

Most functions in the package don't directly reference these tables. The main users are:

1. **`update_consolidated_dictionary_tables()`** - Now creates/updates lowercase tables
2. **Dictionary import functions** - Now create lowercase yearly tables
3. **Validation functions** - Use case-insensitive grep (no impact)

### User-Facing Impact

**Minimal!** Most users don't directly query metadata tables. Those who do will need to update:

```r
# If you have code like this:
results <- DBI::dbGetQuery(con, "SELECT * FROM Tables_All WHERE YEAR = 2023")

# Change to:
results <- DBI::dbGetQuery(con, "SELECT * FROM tables_all WHERE YEAR = 2023")
```

## Testing After Migration

```r
library(devtools)
load_all()

con <- ensure_connection()

# Test 1: Check tables exist (lowercase)
stopifnot("tables_all" %in% DBI::dbListTables(con))
stopifnot("vartable_all" %in% DBI::dbListTables(con))
stopifnot("valuesets_all" %in% DBI::dbListTables(con))

# Test 2: Check they have data
tables_all_count <- DBI::dbGetQuery(con, "SELECT COUNT(*) as n FROM tables_all")$n
cat("tables_all rows:", tables_all_count, "\n")
stopifnot(tables_all_count > 0)

# Test 3: Check yearly tables exist
tables_23 <- DBI::dbGetQuery(con, "SELECT * FROM tables23 LIMIT 5")
cat("tables23 sample rows:", nrow(tables_23), "\n")

# Test 4: Check case-insensitive grep works
meta_tables <- grep("^(tables|vartable|valuesets)[0-9]{2}$", 
                    DBI::dbListTables(con), 
                    value = TRUE, 
                    ignore.case = TRUE)
cat("Found", length(meta_tables), "metadata table sets\n")

cat("\n✓ All tests passed!\n")
```

## Summary

**Problem**: Mixed case metadata table names broke after lowercase standardization  
**Solution**: Updated code to create and search for lowercase metadata tables  
**Migration**: Use `standardize_table_names_to_lowercase()` to rename existing tables  
**Impact**: Minimal - most users don't directly access these tables  
**Status**: ✅ Fixed in code, user needs to run migration once  

All new imports will now create consistently lowercase tables!
