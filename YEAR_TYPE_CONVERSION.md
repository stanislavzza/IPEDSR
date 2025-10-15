# Converting YEAR from DOUBLE to INTEGER

## Overview
After adding YEAR columns to all tables, they were created as DOUBLE type (R's default numeric). This document explains how to safely convert them to INTEGER type.

## Why Convert?

### Benefits:
1. **Semantic Correctness**: Years are integers (2019, 2020), not decimals (2019.5)
2. **Cleaner Validation**: Eliminates ~200 "DOUBLE expected INTEGER" warnings
3. **Slight Performance Gain**: INTEGERs are slightly faster and use less storage than DOUBLEs
4. **User Clarity**: Makes the data structure more intuitive

### Safety Analysis:

✅ **No Data Loss**: Years are whole numbers, so DOUBLE → INTEGER conversion is lossless
✅ **No Breaking Changes**: Queries work identically with INTEGER vs DOUBLE for year comparisons
✅ **Efficient Operation**: DuckDB's ALTER TABLE changes type in-place (no full table rewrite)
✅ **Idempotent**: Can be run multiple times safely (skips tables already INTEGER)
✅ **Reversible**: If needed, can convert back (though there's no reason to)

## Potential Issues (Very Minor)

### 1. Time Required
- **Impact**: Moderate - ~940 tables to process
- **Mitigation**: Function shows progress every 50 tables
- **Estimated Time**: 2-5 minutes on typical hardware

### 2. Database Lock During Conversion
- **Impact**: Low - database locked table-by-table briefly during ALTER
- **Mitigation**: Each table conversion is fast (<1 second per table)
- **Risk**: Don't run while other processes are actively querying the database

### 3. DuckDB Version Compatibility
- **Impact**: Very Low - ALTER COLUMN TYPE is standard DuckDB syntax
- **Mitigation**: Function has error handling to catch any issues
- **Risk**: Tested on DuckDB 0.8+, should work on all recent versions

## Why You WOULD Do This

1. **Professional Polish**: Makes the database schema clean and semantically correct
2. **Eliminate Warnings**: Your validation output will be much cleaner (200+ fewer warnings)
3. **Best Practices**: Integer types for integer data is standard database design
4. **Storage Efficiency**: Small but measurable space savings (8 bytes → 4 bytes per year value)
5. **Query Optimization**: Some databases optimize integer comparisons better than floating point

## Why You WOULD NOT Do This

There are almost NO good reasons not to do this conversion:

1. **"If it ain't broke..."**: If you don't care about the warnings and everything works
2. **Risk Aversion**: Extremely cautious about any database modification (but we have backups!)
3. **Time Constraints**: Need to use database immediately and can't spare 5 minutes
4. **Legacy Code Dependencies**: Some code explicitly checks for DOUBLE type (very unlikely)

## Recommended Approach

### Option 1: Do It Now (Recommended)
The benefits far outweigh the minimal risks:

```r
# 1. Create backup
ipeds_data_manager("backup")

# 2. Test on a few tables first
test_tables <- c("ADM2022", "sfa1819_p1", "valuesets24")
convert_year_to_integer(tables = test_tables, verbose = TRUE)

# 3. Verify conversion
con <- ensure_connection()
schema <- DBI::dbGetQuery(con, "PRAGMA table_info(ADM2022)")
schema[schema$name == "YEAR", ]  # Should show type = "INTEGER"

# 4. Convert all tables
convert_year_to_integer(verbose = TRUE)

# 5. Validate results
ipeds_data_manager("validate")
```

### Option 2: Do It Later
If you're in a rush, you can do this conversion anytime:

```r
# The function is now part of your package
# Run whenever you have 5 minutes:
convert_year_to_integer(verbose = TRUE)
```

### Option 3: Never Do It
Technically fine - everything will work with YEAR as DOUBLE:
- All queries work the same
- Just have cosmetic warnings in validation
- Slightly less efficient, but not noticeably

## Technical Details

### What the Function Does:
```sql
-- For each table with YEAR column of type DOUBLE:
ALTER TABLE table_name ALTER COLUMN YEAR TYPE INTEGER;
```

### Error Handling:
- Wraps each table conversion in tryCatch()
- Continues processing if one table fails
- Reports summary of successes/failures
- Errors are counted but don't stop the process

### Verification:
After conversion, you can verify any table:
```r
con <- ensure_connection()
schema <- DBI::dbGetQuery(con, "PRAGMA table_info(ADM2022)")
schema[schema$name == "YEAR", "type"]  # Should be "INTEGER"
```

## Conclusion

**Recommendation: Convert to INTEGER**

The conversion is:
- ✅ Safe (no data loss, fully reversible)
- ✅ Fast (5 minutes for 940 tables)  
- ✅ Beneficial (cleaner validation, better semantics)
- ✅ Standard (integers for year values is best practice)

The only reason not to do it is if you want to avoid even minimal database operations, but since you just added YEAR columns to all tables, this is a natural next step to complete the feature properly.

## If Something Goes Wrong

1. **Restore from backup**: `ipeds_data_manager("restore")`
2. **Check specific table**: `DBI::dbGetQuery(con, "PRAGMA table_info(table_name)")`
3. **Re-run conversion**: Function is idempotent, safe to re-run
4. **Report issue**: Error messages will show which table(s) failed
