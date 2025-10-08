#!/usr/bin/env Rscript
# Initialize version tracking with current database contents
# This creates baseline metadata for all existing tables

library(DBI)
library(duckdb)

cat("Initializing version tracking with current database contents...\n\n")

# Load the package functions
if (file.exists("DESCRIPTION")) {
  devtools::load_all()
} else {
  library(IPEDSR)
}

# Ensure connection and initialize tracking
cat("1. Setting up version tracking tables...\n")

# First, disconnect any existing connections to release locks
tryCatch({
  disconnect_ipeds()
  cat("   Disconnected existing connections\n")
}, error = function(e) {
  cat("   No existing connections to disconnect\n")
})

# Wait a moment for locks to clear
Sys.sleep(1)

# Need write access for creating tables, so don't use ensure_connection() which is read-only
library(rappdirs)
db_dir <- user_data_dir("IPEDSR")
db_path <- file.path(db_dir, "ipeds_2004-2023.duckdb")

if (!file.exists(db_path)) {
  cat("   ❌ Database not found at:", db_path, "\n")
  quit(status = 1)
}

# Connect with write access
tryCatch({
  db_connection <- DBI::dbConnect(duckdb::duckdb(), db_path, read_only = FALSE)
  cat("   Connected to database with write access\n")
}, error = function(e) {
  cat("   ❌ Could not connect with write access:", e$message, "\n")
  cat("   This may be because the database is open in RStudio or another process.\n")
  cat("   Please close any database connections in RStudio and try again.\n")
  quit(status = 1)
})

initialize_result <- initialize_version_tracking(db_connection)

if (initialize_result) {
  cat("   ✅ Version tracking tables created successfully\n\n")
} else {
  cat("   ❌ Failed to create version tracking tables\n")
  quit(status = 1)
}

# Get all existing tables
cat("2. Analyzing existing database tables...\n")
all_tables <- DBI::dbListTables(db_connection)
data_tables <- all_tables[!grepl("^ipeds_", all_tables)]  # Exclude metadata tables

cat("   Found", length(data_tables), "data tables to catalog\n\n")

# Function to extract metadata from table name and content
extract_table_metadata <- function(table_name, db_connection) {
  tryCatch({
    # Extract year from table name
    year_match <- regmatches(table_name, regexpr("[0-9]{4}", table_name))
    data_year <- if (length(year_match) > 0) as.integer(year_match) else NA
    
    # Get table info
    table_info <- DBI::dbGetQuery(db_connection, paste0("SELECT COUNT(*) as row_count FROM ", table_name))
    row_count <- table_info$row_count[1]
    
    # Get column info
    column_info <- DBI::dbGetQuery(db_connection, paste0("PRAGMA table_info(", table_name, ")"))
    column_count <- nrow(column_info)
    
    # Determine survey component from table name prefix
    survey_component <- if (grepl("^adm", table_name)) {
      "Admissions"
    } else if (grepl("^al", table_name)) {
      "Academic Libraries"
    } else if (grepl("^c[0-9]", table_name)) {
      "Completions"
    } else if (grepl("^eap", table_name)) {
      "Employees by Assigned Position"
    } else if (grepl("^ef", table_name)) {
      "Fall Enrollment"
    } else if (grepl("^f[0-9]", table_name)) {
      "Finance"
    } else if (grepl("^gr", table_name)) {
      "Graduation Rates"
    } else if (grepl("^hd", table_name)) {
      "Institutional Characteristics"
    } else if (grepl("^ic", table_name)) {
      "Institutional Characteristics"
    } else if (grepl("^om", table_name)) {
      "Outcome Measures"
    } else if (grepl("^s", table_name)) {
      "Student Financial Aid"
    } else if (grepl("^sfav", table_name)) {
      "Student Financial Aid"
    } else {
      "Unknown"
    }
    
    # Generate description
    description <- paste0("IPEDS ", survey_component, " data for ", 
                         if (!is.na(data_year)) data_year else "unknown year")
    
    return(list(
      table_name = table_name,
      data_year = data_year,
      survey_component = survey_component,
      description = description,
      source_url = NA,  # Unknown for existing data
      download_date = NA,  # Unknown for existing data  
      file_size = NA,  # Unknown for existing data
      row_count = row_count,
      column_count = column_count,
      checksum = NA,  # Could calculate but expensive
      version = "baseline",
      status = "existing",
      notes = "Cataloged from existing database during initialization"
    ))
    
  }, error = function(e) {
    warning("Error processing table ", table_name, ": ", e$message)
    return(NULL)
  })
}

# Process tables in batches to avoid overwhelming output
cat("3. Cataloging table metadata...\n")
batch_size <- 50
total_batches <- ceiling(length(data_tables) / batch_size)
cataloged_count <- 0

for (batch_num in 1:total_batches) {
  start_idx <- (batch_num - 1) * batch_size + 1
  end_idx <- min(batch_num * batch_size, length(data_tables))
  batch_tables <- data_tables[start_idx:end_idx]
  
  cat(sprintf("   Processing batch %d/%d (%d tables)...\n", 
              batch_num, total_batches, length(batch_tables)))
  
  for (table_name in batch_tables) {
    metadata <- extract_table_metadata(table_name, db_connection)
    
    if (!is.null(metadata)) {
      # Insert metadata into tracking table
      record_table_metadata(
        table_name = metadata$table_name,
        data_year = metadata$data_year,
        survey_component = metadata$survey_component,
        description = metadata$description,
        source_url = metadata$source_url,
        download_date = metadata$download_date,
        file_size = metadata$file_size,
        row_count = metadata$row_count,
        column_count = metadata$column_count,
        checksum = metadata$checksum,
        version = metadata$version,
        status = metadata$status,
        notes = metadata$notes,
        db_connection = db_connection
      )
      
      cataloged_count <- cataloged_count + 1
    }
  }
}

cat("\n4. Summarizing results...\n")
cat("   ✅ Successfully cataloged", cataloged_count, "tables\n")

# Get summary statistics
summary_sql <- "
SELECT 
  data_year,
  COUNT(*) as table_count,
  SUM(row_count) as total_rows
FROM ipeds_metadata 
WHERE data_year IS NOT NULL
GROUP BY data_year 
ORDER BY data_year DESC
"

summary_results <- DBI::dbGetQuery(db_connection, summary_sql)

if (nrow(summary_results) > 0) {
  cat("\n   Data Summary by Year:\n")
  for (i in seq_len(nrow(summary_results))) {
    year <- summary_results$data_year[i]
    tables <- summary_results$table_count[i]
    rows <- summary_results$total_rows[i]
    cat(sprintf("   %d: %d tables, %s rows\n", year, tables, format(rows, big.mark = ",")))
  }
}

# Check for tables without years
no_year_count <- DBI::dbGetQuery(db_connection, "SELECT COUNT(*) as count FROM ipeds_metadata WHERE data_year IS NULL")$count

if (no_year_count > 0) {
  cat(sprintf("\n   ⚠️  %d tables could not be assigned to a year\n", no_year_count))
}

cat("\n", paste(rep("=", 60), collapse = ""), "\n")
cat("VERSION TRACKING INITIALIZATION COMPLETE\n")
cat(paste(rep("=", 60), collapse = ""), "\n")
cat("Initialization completed at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
cat("Database now has baseline version tracking for all existing tables.\n")