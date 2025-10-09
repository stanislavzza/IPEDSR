# FIX 2024 TABLE NAMES: Create lowercase versions and drop uppercase
# This script will properly handle DuckDB's case-insensitive table naming

cat("=== FIXING 2024 TABLE NAMES ===\n")

library(IPEDSR)

con <- ensure_connection()

cat("\n1. CHECKING CURRENT 2024 TABLES...\n")
all_tables <- DBI::dbListTables(con)
tables_2024 <- grep("2024", all_tables, value = TRUE)

cat("Current 2024 tables (", length(tables_2024), "):\n")
for (table in tables_2024) {
  row_count <- DBI::dbGetQuery(con, paste("SELECT COUNT(*) as n FROM", table))$n
  cat("  ", table, "(", format(row_count, big.mark = ","), "rows)\n")
}

cat("\n2. CREATING LOWERCASE COPIES...\n")
# For each uppercase table, create a lowercase copy with CREATE TABLE AS SELECT
success_count <- 0
error_count <- 0

for (table in tables_2024) {
  lowercase_name <- tolower(table)
  
  # Skip if already lowercase
  if (table == lowercase_name) {
    cat("  ✓ Skipping", table, "(already lowercase)\n")
    next
  }
  
  cat("  Creating", lowercase_name, "from", table, "...")
  
  tryCatch({
    # Create the lowercase table as a copy of the uppercase one
    sql <- paste("CREATE TABLE", lowercase_name, "AS SELECT * FROM", table)
    DBI::dbExecute(con, sql)
    
    # Verify the copy worked
    new_count <- DBI::dbGetQuery(con, paste("SELECT COUNT(*) as n FROM", lowercase_name))$n
    old_count <- DBI::dbGetQuery(con, paste("SELECT COUNT(*) as n FROM", table))$n
    
    if (new_count == old_count) {
      cat(" ✅ Success (", format(new_count, big.mark = ","), "rows)\n")
      success_count <- success_count + 1
    } else {
      cat(" ❌ Row count mismatch:", new_count, "vs", old_count, "\n")
      error_count <- error_count + 1
    }
    
  }, error = function(e) {
    cat(" ❌ Error:", e$message, "\n")
    error_count <- error_count + 1
  })
}

cat("\n3. VERIFICATION BEFORE DROPPING UPPERCASE TABLES...\n")
# Re-check all tables to verify we have both versions
all_tables_after <- DBI::dbListTables(con)
tables_2024_after <- grep("2024", all_tables_after, value = TRUE)

cat("Tables after creating lowercase copies (", length(tables_2024_after), "):\n")
for (table in sort(tables_2024_after)) {
  row_count <- DBI::dbGetQuery(con, paste("SELECT COUNT(*) as n FROM", table))$n
  cat("  ", table, "(", format(row_count, big.mark = ","), "rows)\n")
}

# Identify uppercase tables that have lowercase equivalents
uppercase_to_drop <- c()
for (table in tables_2024) {
  lowercase_name <- tolower(table)
  if (table != lowercase_name && lowercase_name %in% tables_2024_after) {
    uppercase_to_drop <- c(uppercase_to_drop, table)
  }
}

if (length(uppercase_to_drop) > 0) {
  cat("\n4. DROPPING UPPERCASE TABLES...\n")
  cat("Tables to drop (", length(uppercase_to_drop), "):\n")
  for (table in uppercase_to_drop) {
    cat("  -", table, "\n")
  }
  
  cat("\nProceeding with drops...\n")
  
  for (table in uppercase_to_drop) {
    cat("  Dropping", table, "...")
    tryCatch({
      DBI::dbExecute(con, paste("DROP TABLE", table))
      cat(" ✅ Dropped\n")
    }, error = function(e) {
      cat(" ❌ Error:", e$message, "\n")
    })
  }
  
} else {
  cat("\n4. NO UPPERCASE TABLES TO DROP\n")
  cat("Either no uppercase tables found or lowercase copies failed\n")
}

cat("\n5. FINAL VERIFICATION...\n")
final_tables <- DBI::dbListTables(con)
final_2024 <- grep("2024", final_tables, value = TRUE)

cat("Final 2024 tables (", length(final_2024), "):\n")
total_rows <- 0
for (table in sort(final_2024)) {
  row_count <- DBI::dbGetQuery(con, paste("SELECT COUNT(*) as n FROM", table))$n
  total_rows <- total_rows + row_count
  is_lowercase <- table == tolower(table)
  case_indicator <- if (is_lowercase) "✅" else "⚠️ "
  cat("  ", case_indicator, table, "(", format(row_count, big.mark = ","), "rows)\n")
}

cat("\nTotal 2024 records:", format(total_rows, big.mark = ","), "\n")

# Check if all are lowercase now
all_lowercase <- all(final_2024 == tolower(final_2024))
cat("All tables lowercase?", if (all_lowercase) "✅ YES" else "❌ NO", "\n")

cat("\n=== TABLE NAME FIXING COMPLETE ===\n")