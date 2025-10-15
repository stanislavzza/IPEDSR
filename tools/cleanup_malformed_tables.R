# CLEANUP SCRIPT: Fix malformed table names (remove .zip extensions)
# This will rename the existing 2024 tables to have proper names

cat("=== CLEANING UP MALFORMED 2024 TABLE NAMES ===\n")

library(IPEDSR)

con <- ensure_connection(read_only = FALSE)

# Find all tables with .zip extension
all_tables <- DBI::dbListTables(con)
malformed_tables <- grep("\\.zip$", all_tables, value = TRUE)

cat("Found", length(malformed_tables), "malformed table names:\n")

if (length(malformed_tables) > 0) {
  for (malformed_name in malformed_tables) {
    clean_name <- gsub("\\.zip$", "", malformed_name)
    
    cat("Renaming:", malformed_name, "->", clean_name, "\n")
    
    tryCatch({
      # Create new table with clean name
      sql_create <- paste0('CREATE TABLE "', clean_name, '" AS SELECT * FROM "', malformed_name, '"')
      DBI::dbExecute(con, sql_create)
      
      # Drop old malformed table
      sql_drop <- paste0('DROP TABLE "', malformed_name, '"')
      DBI::dbExecute(con, sql_drop)
      
      cat("  ✅ Successfully renamed\n")
      
    }, error = function(e) {
      cat("  ❌ Error:", e$message, "\n")
    })
  }
  
  cat("\n=== CLEANUP COMPLETE ===\n")
  
  # Verify the cleanup
  cat("\nVerifying cleanup...\n")
  new_tables <- DBI::dbListTables(con)
  new_malformed <- grep("\\.zip$", new_tables, value = TRUE)
  new_2024_tables <- grep("2024", new_tables, value = TRUE)
  
  cat("Remaining malformed tables:", length(new_malformed), "\n")
  cat("Total 2024 tables:", length(new_2024_tables), "\n")
  
  if (length(new_2024_tables) > 0) {
    cat("2024 tables:\n")
    for (table in new_2024_tables) {
      row_count <- DBI::dbGetQuery(con, paste('SELECT COUNT(*) as n FROM "', table, '"'))$n
      cat("  -", table, "(", format(row_count, big.mark = ","), "rows)\n")
    }
  }
  
} else {
  cat("No malformed tables found!\n")
}

# Final verification
cat("\nFinal database status:\n")
years <- get_database_years()
cat("Years in database:", paste(years, collapse = ", "), "\n")