# DROP UPPERCASE 2024 TABLES (since lowercase versions already exist and work)
# This handles the DuckDB case-insensitivity issue

cat("=== DROPPING UPPERCASE 2024 TABLES ===\n")

library(IPEDSR)

# Connect to database with write permissions
con <- ensure_connection(read_only = FALSE)

# Get uppercase 2024 tables
all_tables <- DBI::dbListTables(con)
tables_2024 <- grep("2024", all_tables, value = TRUE)
uppercase_2024 <- tables_2024[grepl("[A-Z]", tables_2024)]

cat("Found", length(uppercase_2024), "uppercase 2024 tables to drop:\n")
for (table in uppercase_2024) {
  cat(" -", table, "\n")
}

cat("\n=== VERIFYING LOWERCASE TABLES EXIST ===\n")
for (upper_table in uppercase_2024) {
  lower_table <- tolower(upper_table)
  
  tryCatch({
    # Check if lowercase version exists and has data
    result <- DBI::dbGetQuery(con, paste0('SELECT COUNT(*) as n FROM "', lower_table, '"'))
    cat("✅", lower_table, "exists with", format(result$n, big.mark = ","), "rows\n")
  }, error = function(e) {
    cat("❌", lower_table, "does not exist or has error:", e$message, "\n")
  })
}

cat("\n=== DROPPING UPPERCASE TABLES ===\n")
dropped_count <- 0
errors <- character(0)

for (upper_table in uppercase_2024) {
  cat("Dropping:", upper_table, "\n")
  
  tryCatch({
    sql_drop <- paste0('DROP TABLE "', upper_table, '"')
    DBI::dbExecute(con, sql_drop)
    cat("  ✅ Successfully dropped\n")
    dropped_count <- dropped_count + 1
  }, error = function(e) {
    errors <- c(errors, paste0(upper_table, ": ", e$message))
    cat("  ❌ Error:", e$message, "\n")
  })
}

cat("\n=== CLEANUP SUMMARY ===\n")
cat("Tables successfully dropped:", dropped_count, "/", length(uppercase_2024), "\n")

if (length(errors) > 0) {
  cat("\nErrors encountered:\n")
  for (error in errors) {
    cat(" -", error, "\n")
  }
}

# Verify final state
cat("\n=== VERIFICATION ===\n")
final_tables <- DBI::dbListTables(con)
final_2024 <- grep("2024", final_tables, value = TRUE)
remaining_uppercase <- final_2024[grepl("[A-Z]", final_2024)]

cat("2024 tables after cleanup:", length(final_2024), "\n")
cat("Remaining uppercase 2024 tables:", length(remaining_uppercase), "\n")

if (length(remaining_uppercase) > 0) {
  cat("Still uppercase:\n")
  for (table in remaining_uppercase) {
    cat(" -", table, "\n")
  }
} else {
  cat("✅ All uppercase 2024 tables removed!\n")
}

# Test lowercase table access
cat("\nTesting lowercase table access:\n")
lowercase_2024 <- c("hd2024", "effy2024", "c2024_a")
for (table in lowercase_2024) {
  tryCatch({
    result <- DBI::dbGetQuery(con, paste0('SELECT COUNT(*) as n FROM "', table, '"'))
    cat("  ✅", table, "(", format(result$n, big.mark = ","), "rows)\n")
  }, error = function(e) {
    cat("  ❌", table, "error:", e$message, "\n")
  })
}

cat("\n=== TASK 1.1 COMPLETE ===\n")