# TASK 1.1: RENAME 2024 UPPERCASE TABLES TO LOWERCASE
# Fix naming consistency by converting all 2024 tables to lowercase

cat("=== RENAMING 2024 UPPERCASE TABLES TO LOWERCASE ===\n")

library(IPEDSR)

# Connect to database with write permissions
con <- ensure_connection(read_only = FALSE)

# Get all tables in database
all_tables <- DBI::dbListTables(con)

# Find 2024 tables that are uppercase
tables_2024 <- grep("2024", all_tables, value = TRUE)
uppercase_2024 <- tables_2024[grepl("[A-Z]", tables_2024)]

cat("Found", length(uppercase_2024), "uppercase 2024 tables to rename:\n")
for (table in uppercase_2024) {
  cat(" -", table, "\n")
}

if (length(uppercase_2024) == 0) {
  cat("No uppercase 2024 tables found. All tables already follow lowercase convention.\n")
} else {
  cat("\n=== STARTING RENAMING PROCESS ===\n")
  
  renamed_count <- 0
  errors <- character(0)
  
  for (old_name in uppercase_2024) {
    # Convert to lowercase
    new_name <- tolower(old_name)
    
    cat("Renaming:", old_name, "->", new_name, "\n")
    
    tryCatch({
      # Create new table with lowercase name
      sql_create <- paste0('CREATE TABLE "', new_name, '" AS SELECT * FROM "', old_name, '"')
      DBI::dbExecute(con, sql_create)
      
      # Verify the new table exists and has the same row count
      old_count <- DBI::dbGetQuery(con, paste0('SELECT COUNT(*) as n FROM "', old_name, '"'))$n
      new_count <- DBI::dbGetQuery(con, paste0('SELECT COUNT(*) as n FROM "', new_name, '"'))$n
      
      if (old_count == new_count) {
        # Drop the old uppercase table
        sql_drop <- paste0('DROP TABLE "', old_name, '"')
        DBI::dbExecute(con, sql_drop)
        
        cat("  ✅ Successfully renamed (", format(new_count, big.mark = ","), "rows)\n")
        renamed_count <- renamed_count + 1
      } else {
        errors <- c(errors, paste0(old_name, ": Row count mismatch (", old_count, " vs ", new_count, ")"))
        cat("  ❌ Row count mismatch, keeping original table\n")
      }
      
    }, error = function(e) {
      errors <- c(errors, paste0(old_name, ": ", e$message))
      cat("  ❌ Error:", e$message, "\n")
    })
  }
  
  cat("\n=== RENAMING SUMMARY ===\n")
  cat("Tables successfully renamed:", renamed_count, "/", length(uppercase_2024), "\n")
  
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
  
  cat("2024 tables after renaming:", length(final_2024), "\n")
  cat("Remaining uppercase 2024 tables:", length(remaining_uppercase), "\n")
  
  if (length(remaining_uppercase) > 0) {
    cat("Still uppercase:\n")
    for (table in remaining_uppercase) {
      cat(" -", table, "\n")
    }
  } else {
    cat("✅ All 2024 tables now follow lowercase convention!\n")
  }
  
  # Show final list of 2024 tables
  cat("\nFinal 2024 table list:\n")
  for (table in sort(final_2024)) {
    row_count <- DBI::dbGetQuery(con, paste0('SELECT COUNT(*) as n FROM "', table, '"'))$n
    cat(" -", table, "(", format(row_count, big.mark = ","), "rows)\n")
  }
}

cat("\n=== TASK 1.1 COMPLETE ===\n")