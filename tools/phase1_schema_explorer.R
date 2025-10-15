# PHASE 1: COMPREHENSIVE DATABASE SCHEMA EXPLORATION
# Build complete understanding of IPEDS database structure and contents

cat("=== IPEDS DATABASE SCHEMA EXPLORER ===\n")

library(IPEDSR)

# Connect to database
con <- ensure_connection()

cat("\n🔍 DATABASE OVERVIEW\n")
cat("=====================================\n")

# Get basic database info
all_tables <- DBI::dbListTables(con)
total_tables <- length(all_tables)

cat("📊 Total tables in database:", total_tables, "\n")

# Analyze table naming patterns
years_found <- sort(unique(as.numeric(stringr::str_extract(all_tables, "\\d{4}"))))
years_found <- years_found[!is.na(years_found)]

cat("📅 Years represented:",
    paste(range(years_found), collapse = " - "),
    "(", length(years_found), "years)\n")

# Count tables by year
cat("\n📋 TABLES BY YEAR\n")
cat("=====================================\n")
for (year in years_found) {
  year_tables <- grep(paste0(year, "\\b"), all_tables, value = TRUE)
  cat(sprintf("%d: %2d tables\n", year, length(year_tables)))
}

cat("\n🏷️  TABLE NAMING PATTERNS\n")
cat("=====================================\n")

# Extract table prefixes/types (everything before the year)
table_prefixes <- unique(gsub("\\d{4}.*$", "", all_tables))
table_prefixes <- table_prefixes[table_prefixes != ""]
table_prefixes <- sort(table_prefixes)

cat("Survey components found:\n")
for (prefix in table_prefixes) {
  matching_tables <- grep(paste0("^", prefix),
                          all_tables,
                          value = TRUE)
  years_with_prefix <- unique(stringr::str_extract(matching_tables, "\\d{4}"))
  years_with_prefix <- years_with_prefix[!is.na(years_with_prefix)]
  
  cat(sprintf("  %s: %d tables across %d years (%s)\n", 
              prefix, 
              length(matching_tables),
              length(years_with_prefix),
              if(length(years_with_prefix) <= 5) paste(years_with_prefix, collapse=",") else paste(c(years_with_prefix[1:3], "...", tail(years_with_prefix,1)), collapse=",")
  ))
}

cat("\n📊 DATABASE SIZE AND SCOPE\n")
cat("=====================================\n")

# Calculate total records and database scope
total_records <- 0
largest_tables <- data.frame(
  table_name = character(0),
  row_count = integer(0),
  year = character(0),
  stringsAsFactors = FALSE
)

# Sample first 20 tables to get size estimates (full scan would take too long)
sample_tables <- head(all_tables, 20)

for (table in sample_tables) {
  tryCatch({
    row_count <- DBI::dbGetQuery(con, paste("SELECT COUNT(*) as n FROM", table))$n
    total_records <- total_records + row_count
    
    year_match <- stringr::str_extract(table, "\\d{4}")
    
    largest_tables <- rbind(largest_tables, data.frame(
      table_name = table,
      row_count = row_count,
      year = ifelse(is.na(year_match), 
                    "unknown", 
                    year_match),
      stringsAsFactors = FALSE
    ))
  }, error = function(e) {
    cat("Error with table",
        table, ":", e$message, "\n")
  })
}

# Show largest tables from sample
largest_tables <- largest_tables[order(-largest_tables$row_count), ]
cat("Sample of largest tables (first 20 tables only):\n")
head(largest_tables, 10) |> 
  apply(1, function(row) {
    cat(sprintf("  %s (%s): %s rows\n",
                row["table_name"],
                row["year"],
                format(as.numeric(row["row_count"]), big.mark = ",")))
  })

cat(sprintf("\nEstimated total records (sample): %s\n",
            format(total_records, big.mark = ",")))

cat("\n🔍 RECENT DATA ANALYSIS (2024)\n")
cat("=====================================\n")

# Focus on 2024 data we just imported
tables_2024 <- grep("2024", all_tables, value = TRUE)
cat("2024 tables:", length(tables_2024), "\n")

total_2024_records <- 0
for (table in tables_2024) {
  tryCatch({
    row_count <-
      DBI::dbGetQuery(con,
                      paste("SELECT COUNT(*) as n FROM", table))$n
    total_2024_records <- total_2024_records + row_count
    cat(sprintf("  %s: %s rows\n",
                table,
                format(row_count, big.mark = ",")))
  }, error = function(e) {
    cat("  Error with", table, "\n")
  })
} # end of for loop

cat(sprintf("\nTotal 2024 records: %s\n",
            format(total_2024_records, big.mark = ",")))

cat("\n🏗️  TABLE STRUCTURE PATTERNS\n")
cat("=====================================\n")

# Analyze a few representative tables to understand structure
representative_tables <- c(
  if("HD2024" %in% all_tables) "HD2024",
  if("EFFY2024" %in% all_tables) "EFFY2024", 
  if("C2024_A" %in% all_tables) "C2024_A"
)

for (table in representative_tables) {
  if (table %in% all_tables) {
    cat(sprintf("\n📋 %s Structure:\n", table))

    # Get column information
    columns <- DBI::dbGetQuery(con, paste("PRAGMA table_info(", table, ")"))
    cat(sprintf("  Columns: %d\n", nrow(columns)))

    # Show first few columns with their types
    cat("  Sample columns:\n")
    head(columns, 8) |> 
      apply(1, function(row) {
        cat(sprintf("    %s (%s)\n", row["name"], row["type"]))
      })

    if (nrow(columns) > 8) {
      cat(sprintf("    ... and %d more columns\n", nrow(columns) - 8))
    }
  }
}

cat("\n🎯 NEXT STEPS FOR EXPLORATION\n")
cat("=====================================\n")
cat("1. Pick specific survey components to explore (HD, EFFY, C, etc.)\n")
cat("2. Understand UNITID as the primary key across tables\n")
cat("3. Explore longitudinal patterns across years\n")
cat("4. Learn DuckDB-specific SQL features and performance\n")
cat("5. Build reusable exploration functions\n")

cat("\n✅ SCHEMA EXPLORATION COMPLETE\n")
cat("Database contains",
    total_tables,
    "tables across",
    length(years_found),
    "years\n")
cat("Ready to dive deeper into specific components?\n")
