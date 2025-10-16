# ValueSets vs VarTable Analysis and Proposed Fix

## Current Confusing State

### What We Have in the Database:

| Table Name | Column Structure | Actual Content | What It Should Be |
|------------|------------------|----------------|-------------------|
| `vartable##` | varNumber, varName, DataType, FieldWidth, format, varTitle | **Variable definitions** | ✅ CORRECT |
| `vartable_all` | Same + more metadata | **Variable definitions (all years)** | ✅ CORRECT |
| `valuesets##` | varNumber, varName, longDescription | **Variable definitions** (duplicates vartable!) | ❌ WRONG |
| `valuesets_all` | varName, Codevalue, valueLabel, Frequency, Percent | **Code-to-label mappings** | ✅ CORRECT |

### The Problem:

**`valuesets##` tables contain variable definitions, NOT value sets!**

- `valuesets24` has columns: `YEAR, varNumber, varName, longDescription, source_file`
- This is basically a subset of `vartable24` data
- It does NOT contain `Codevalue` or `valueLabel` columns
- Only `valuesets_all` has the actual code mappings we need

### Impact on Code:

The `get_cipcodes()` function was trying to use:
```r
tname <- my_dbListTables(search_string = "^valuesets\\d\\d$") %>% max()
```

But `valuesets24` doesn't have `Codevalue` or `valueLabel` columns, so the query fails!

---

## Root Cause Investigation

Looking at `tools/download_process_dictionaries.R`:

```r
} else if (grepl("valuesets?", sheet_lower)) {
  # This is a valuesets worksheet
  cat("      → Adding to valuesets data\n")
  all_valuesets_data <- rbind(all_valuesets_data, sheet_data)
```

The script identifies worksheets by name pattern. IPEDS dictionary Excel files likely have:
- Worksheets named "Variables" or "vartable" → loaded into `vartable##`
- Worksheets named "Valuesets" → loaded into `valuesets##`

**BUT:** It appears the IPEDS "Valuesets" worksheets in some years contain variable definitions, not code mappings!

---

## Proposed Solutions

### Option 1: Use `valuesets_all` for Everything (Simplest)

**Change:** Functions that need code mappings should ALWAYS use `valuesets_all` instead of `valuesets##`

**Pros:**
- Minimal code changes
- `valuesets_all` has the data we need
- Works immediately

**Cons:**
- `valuesets##` tables remain misleading/useless
- Wastes database space with duplicate data
- Doesn't fix the underlying confusion

**Implementation:**
```r
# In get_cipcodes():
# OLD (broken):
tname <- my_dbListTables(search_string = "^valuesets\\d\\d$") %>% max()

# NEW (working):
# Always use valuesets_all for code mappings
tdf <- dplyr::tbl(idbc, "valuesets_all") %>%
  dplyr::filter(varName == "CIPCODE")
# Then filter by year if needed
```

### Option 2: Rebuild `valuesets##` Tables with Correct Data

**Change:** Reprocess the source IPEDS dictionaries to populate `valuesets##` with actual code mappings

**Pros:**
- Tables would have semantically correct names
- Year-specific code lookups available
- Cleaner database structure

**Cons:**
- Requires data reprocessing
- Need to understand original IPEDS file structure
- More complex fix
- May not be possible if IPEDS doesn't provide year-specific code maps

**Implementation:**
- Modify `download_process_dictionaries.R` to extract code mappings
- Rebuild database from source
- Update all code to use `valuesets##` appropriately

### Option 3: Rename Tables to Reflect Reality

**Change:** Rename existing tables to match their actual content

**Pros:**
- Names would match content
- No data reprocessing needed
- Clear what each table contains

**Cons:**
- Breaking change for existing code
- Doesn't solve the "no year-specific code maps" issue
- Still need to update all functions

**Implementation:**
```sql
-- Rename valuesets## to something else (e.g., varinfo##)
ALTER TABLE valuesets06 RENAME TO varinfo06;
ALTER TABLE valuesets07 RENAME TO varinfo07;
...
ALTER TABLE valuesets24 RENAME TO varinfo24;

-- Keep valuesets_all as is (it has the right data)
```

### Option 4: Drop Useless `valuesets##` Tables

**Change:** Delete `valuesets##` tables since they duplicate `vartable##` data

**Pros:**
- Removes confusion
- Saves database space
- Forces use of correct table (valuesets_all)

**Cons:**
- Breaking change if anyone's using them
- Loses year-specific info (though it's duplicated in vartable anyway)

**Implementation:**
```sql
DROP TABLE valuesets06;
DROP TABLE valuesets07;
...
DROP TABLE valuesets24;
```

---

## My Recommendation: **Option 1 + Option 4**

**Short-term (immediate fix):**
1. Update all functions to use `valuesets_all` for code mappings
2. Update survey registry to reflect this pattern
3. Document that `valuesets_all` is the source for code lookups

**Medium-term (cleanup):**
4. Drop the misleading `valuesets##` tables
5. Update documentation to clarify:
   - `vartable##` and `vartable_all` = variable definitions
   - `valuesets_all` = code-to-label mappings (no year-specific versions)

**Why this approach:**
- Fixes the immediate issue (refactoring can continue)
- Removes confusion source
- Minimal breaking changes (most code already uses `valuesets_all` via `get_valueset()`)
- Database becomes cleaner and more maintainable

---

## Code Changes Required

### 1. Update `get_cipcodes()`:

```r
get_cipcodes <- function(digits = NULL){
  idbc <- ensure_connection()

  # Use valuesets_all for code-to-label mappings
  # Note: No year-specific code tables exist; CIPCODE mappings are
  # relatively stable across years
  tdf <- dplyr::tbl(idbc, "valuesets_all") %>%
    dplyr::filter(varName == "CIPCODE") %>%
    dplyr::select(CIPCODE = Codevalue, Subject = valueLabel) %>%
    dplyr::collect() %>%
    unique()

  if(!is.null(digits)) {
    tdf <- tdf %>%
      dplyr::filter(nchar(CIPCODE) == digits)
  }

  return(tdf)
}
```

### 2. Update Survey Registry:

```r
# Remove this misleading entry:
valuesets = list(
  pattern = "^valuesets\\d\\d$",
  description = "Value Sets (Code to Label Mappings)",
  ...
)

# Keep/clarify this:
# Code mappings are in valuesets_all (no year-specific versions)
```

### 3. Verify `get_valueset()` and `get_variables()`:

These already handle year-specific lookups correctly by falling back to `_all` tables. Just verify they work as expected.

---

## Questions for You:

1. **Do you want to keep `valuesets##` tables even though they're misleading?**
   - If yes, we work around them
   - If no, we can drop them (cleaner but potentially breaking)

2. **Is there external code depending on `valuesets##` tables?**
   - If unknown, we should check package usage first

3. **Should we investigate rebuilding `valuesets##` with correct data?**
   - Only worth it if IPEDS provides year-specific code maps
   - May not be possible if they only provide aggregated mappings

4. **Preferred approach?**
   - Quick fix (Option 1): Use `valuesets_all`, document limitation
   - Clean fix (Option 1 + 4): Use `valuesets_all` + drop misleading tables
   - Rebuild (Option 2): Reprocess source data (most work)

---

## My Vote:

**Option 1 + 4 (Quick fix + cleanup):**

1. ✅ Fix `get_cipcodes()` to use `valuesets_all` (immediate)
2. ✅ Update survey registry to remove `valuesets` entry (document pattern)
3. ✅ Continue refactoring with correct approach
4. ✅ Drop `valuesets##` tables in next database rebuild (prevent future confusion)

This gets us unblocked immediately, removes the confusion source, and sets up a cleaner database structure going forward.

**What do you think?**
