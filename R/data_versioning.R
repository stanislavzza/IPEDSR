#' IPEDS Data Versioning and Change Tracking System
#' 
#' Functions for tracking data versions, detecting changes, and maintaining compatibility

#' Create database metadata table for version tracking
#' @param db_connection Database connection
#' @return TRUE if successful
#' @export
initialize_version_tracking <- function(db_connection = NULL) {
  
  if (is.null(db_connection)) {
    db_connection <- ensure_connection()
  }
  
  # Create metadata table to track data versions
  create_metadata_sql <- "
    CREATE TABLE IF NOT EXISTS ipeds_metadata (
      table_name TEXT PRIMARY KEY,
      data_year INTEGER,
      survey_component TEXT,
      description TEXT,
      source_url TEXT,
      download_date TEXT,
      file_size INTEGER,
      row_count INTEGER,
      column_count INTEGER,
      checksum TEXT,
      version TEXT,
      status TEXT,
      notes TEXT
    )
  "
  
  # Create schema changes tracking table
  create_schema_sql <- "
    CREATE TABLE IF NOT EXISTS ipeds_schema_changes (
      id INTEGER PRIMARY KEY,
      table_name TEXT,
      change_date TEXT,
      change_type TEXT,
      column_name TEXT,
      old_value TEXT,
      new_value TEXT,
      description TEXT
    )
  "
  
  # Create data quality tracking table
  create_quality_sql <- "
    CREATE TABLE IF NOT EXISTS ipeds_data_quality (
      id INTEGER PRIMARY KEY,
      table_name TEXT,
      check_date TEXT,
      check_type TEXT,
      status TEXT,
      details TEXT,
      row_count INTEGER,
      issue_count INTEGER
    )
  "
  
  tryCatch({
    DBI::dbExecute(db_connection, create_metadata_sql)
    DBI::dbExecute(db_connection, create_schema_sql)
    DBI::dbExecute(db_connection, create_quality_sql)
    
    message("Version tracking tables initialized successfully")
    return(TRUE)
    
  }, error = function(e) {
    warning("Error initializing version tracking: ", e$message)
    return(FALSE)
  })
}

#' Record metadata for a newly imported table
#' @param table_name Name of the table
#' @param file_info Information about the source file
#' @param db_connection Database connection
#' @return TRUE if successful
#' @export
record_table_metadata <- function(table_name, file_info, db_connection = NULL) {
  
  if (is.null(db_connection)) {
    db_connection <- ensure_connection()
  }
  
  # Initialize version tracking if not already done
  if (!"ipeds_metadata" %in% DBI::dbListTables(db_connection)) {
    initialize_version_tracking(db_connection)
  }
  
  # Get table statistics
  stats <- get_table_statistics(table_name, db_connection)
  
  # Calculate checksum for data integrity
  checksum <- calculate_table_checksum(table_name, db_connection)
  
  # Prepare metadata record
  metadata <- data.frame(
    table_name = table_name,
    data_year = file_info$year,
    survey_component = file_info$survey_component,
    description = file_info$description,
    source_url = file_info$source_url,
    download_date = as.character(Sys.time()),
    file_size = ifelse(is.null(file_info$file_size), 0, file_info$file_size),
    row_count = stats$row_count,
    column_count = stats$column_count,
    checksum = checksum,
    version = generate_version_string(),
    status = "active",
    notes = "",
    stringsAsFactors = FALSE
  )
  
  tryCatch({
    # Remove existing metadata for this table
    DBI::dbExecute(
      db_connection,
      "DELETE FROM ipeds_metadata WHERE table_name = ?",
      params = list(table_name)
    )
    
    # Insert new metadata
    DBI::dbWriteTable(
      db_connection,
      "ipeds_metadata",
      metadata,
      append = TRUE
    )
    
    return(TRUE)
    
  }, error = function(e) {
    warning("Error recording metadata for ", table_name, ": ", e$message)
    return(FALSE)
  })
}

#' Get statistics for a database table
#' @param table_name Name of the table
#' @param db_connection Database connection
#' @return List with table statistics
get_table_statistics <- function(table_name, db_connection) {
  
  tryCatch({
    # Get row count
    row_count_query <- paste("SELECT COUNT(*) as n FROM", table_name)
    row_count <- DBI::dbGetQuery(db_connection, row_count_query)$n
    
    # Get column count by querying table structure
    # In DuckDB, we can use PRAGMA table_info
    col_info_query <- paste("PRAGMA table_info(", table_name, ")")
    col_info <- DBI::dbGetQuery(db_connection, col_info_query)
    column_count <- nrow(col_info)
    
    return(list(
      row_count = row_count,
      column_count = column_count,
      columns = col_info
    ))
    
  }, error = function(e) {
    warning("Error getting statistics for ", table_name, ": ", e$message)
    return(list(row_count = 0, column_count = 0, columns = data.frame()))
  })
}

#' Calculate checksum for data integrity verification
#' @param table_name Name of the table
#' @param db_connection Database connection
#' @return Checksum string
calculate_table_checksum <- function(table_name, db_connection) {
  
  tryCatch({
    # Create a hash of a sample of the data for integrity checking
    # For large tables, we'll sample some rows to make this efficient
    sample_query <- paste("SELECT * FROM", table_name, "LIMIT 1000")
    sample_data <- DBI::dbGetQuery(db_connection, sample_query)
    
    # Convert to string and calculate hash
    data_string <- paste(apply(sample_data, 1, paste, collapse = "|"), collapse = "\n")
    checksum <- digest::digest(data_string, algo = "md5")
    
    return(checksum)
    
  }, error = function(e) {
    warning("Error calculating checksum for ", table_name, ": ", e$message)
    return("")
  })
}

#' Generate version string based on current date and time
#' @return Version string
generate_version_string <- function() {
  paste0("v", format(Sys.time(), "%Y%m%d_%H%M%S"))
}

#' Compare table schemas between versions
#' @param table_name Name of the table to compare
#' @param db_connection Database connection
#' @return Data frame with schema differences
#' @export
detect_schema_changes <- function(table_name, db_connection = NULL) {
  
  if (is.null(db_connection)) {
    db_connection <- ensure_connection()
  }
  
  # Get current schema
  current_schema <- get_table_schema(table_name, db_connection)
  
  # Get previous schema from metadata (if exists)
  previous_schema <- get_previous_schema(table_name, db_connection)
  
  if (is.null(previous_schema)) {
    # No previous schema to compare
    return(data.frame(
      table_name = character(0),
      change_type = character(0),
      column_name = character(0),
      old_value = character(0),
      new_value = character(0),
      stringsAsFactors = FALSE
    ))
  }
  
  # Compare schemas
  changes <- compare_schemas(current_schema, previous_schema, table_name)
  
  # Record changes in tracking table
  if (nrow(changes) > 0) {
    record_schema_changes(changes, db_connection)
  }
  
  return(changes)
}

#' Get current table schema
#' @param table_name Name of the table
#' @param db_connection Database connection
#' @return Data frame with schema information
get_table_schema <- function(table_name, db_connection) {
  
  tryCatch({
    # Use DuckDB's table_info pragma
    schema_query <- paste("PRAGMA table_info(", table_name, ")")
    schema <- DBI::dbGetQuery(db_connection, schema_query)
    
    return(schema)
    
  }, error = function(e) {
    warning("Error getting schema for ", table_name, ": ", e$message)
    return(NULL)
  })
}

#' Get previous schema from stored metadata
#' @param table_name Name of the table
#' @param db_connection Database connection
#' @return Data frame with previous schema or NULL
get_previous_schema <- function(table_name, db_connection) {
  
  # This would retrieve previously stored schema information
  # For now, return NULL (would be enhanced with actual storage)
  return(NULL)
}

#' Compare two schemas and identify differences
#' @param current_schema Current schema data frame
#' @param previous_schema Previous schema data frame
#' @param table_name Table name for context
#' @return Data frame with changes
compare_schemas <- function(current_schema, previous_schema, table_name) {
  
  changes <- data.frame(
    table_name = character(0),
    change_type = character(0),
    column_name = character(0),
    old_value = character(0),
    new_value = character(0),
    stringsAsFactors = FALSE
  )
  
  # Compare column names
  current_cols <- current_schema$name
  previous_cols <- previous_schema$name
  
  # New columns
  new_cols <- setdiff(current_cols, previous_cols)
  if (length(new_cols) > 0) {
    new_changes <- data.frame(
      table_name = table_name,
      change_type = "column_added",
      column_name = new_cols,
      old_value = "",
      new_value = "column_added",
      stringsAsFactors = FALSE
    )
    changes <- rbind(changes, new_changes)
  }
  
  # Removed columns
  removed_cols <- setdiff(previous_cols, current_cols)
  if (length(removed_cols) > 0) {
    removed_changes <- data.frame(
      table_name = table_name,
      change_type = "column_removed",
      column_name = removed_cols,
      old_value = "column_existed",
      new_value = "",
      stringsAsFactors = FALSE
    )
    changes <- rbind(changes, removed_changes)
  }
  
  # Type changes for existing columns
  common_cols <- intersect(current_cols, previous_cols)
  for (col in common_cols) {
    current_type <- current_schema$type[current_schema$name == col]
    previous_type <- previous_schema$type[previous_schema$name == col]
    
    if (current_type != previous_type) {
      type_change <- data.frame(
        table_name = table_name,
        change_type = "type_changed",
        column_name = col,
        old_value = previous_type,
        new_value = current_type,
        stringsAsFactors = FALSE
      )
      changes <- rbind(changes, type_change)
    }
  }
  
  return(changes)
}

#' Record schema changes in tracking table
#' @param changes Data frame with schema changes
#' @param db_connection Database connection
#' @return TRUE if successful
record_schema_changes <- function(changes, db_connection) {
  
  if (nrow(changes) == 0) return(TRUE)
  
  # Add metadata to changes
  changes$id <- seq_len(nrow(changes))
  changes$change_date <- as.character(Sys.time())
  changes$description <- paste(changes$change_type, "for column", changes$column_name)
  
  tryCatch({
    DBI::dbWriteTable(
      db_connection,
      "ipeds_schema_changes",
      changes,
      append = TRUE
    )
    
    message("Recorded ", nrow(changes), " schema changes")
    return(TRUE)
    
  }, error = function(e) {
    warning("Error recording schema changes: ", e$message)
    return(FALSE)
  })
}

#' Get version history for a table
#' @param table_name Name of the table (optional, NULL for all tables)
#' @param db_connection Database connection
#' @return Data frame with version history
#' @export
get_version_history <- function(table_name = NULL, db_connection = NULL) {
  
  if (is.null(db_connection)) {
    db_connection <- ensure_connection()
  }
  
  if (!"ipeds_metadata" %in% DBI::dbListTables(db_connection)) {
    return(data.frame())
  }
  
  query <- "SELECT * FROM ipeds_metadata"
  params <- list()
  
  if (!is.null(table_name)) {
    query <- paste(query, "WHERE table_name = ?")
    params <- list(table_name)
  }
  
  query <- paste(query, "ORDER BY download_date DESC")
  
  tryCatch({
    history <- DBI::dbGetQuery(db_connection, query, params = params)
    return(history)
    
  }, error = function(e) {
    warning("Error getting version history: ", e$message)
    return(data.frame())
  })
}

#' Check for data inconsistencies between years
#' @param table_pattern Pattern to match table names (e.g., "HD" for all HD tables)
#' @param db_connection Database connection
#' @return Data frame with inconsistency reports
#' @export
check_cross_year_consistency <- function(table_pattern, db_connection = NULL) {
  
  if (is.null(db_connection)) {
    db_connection <- ensure_connection()
  }
  
  # Find tables matching the pattern
  all_tables <- DBI::dbListTables(db_connection)
  matching_tables <- all_tables[grepl(table_pattern, all_tables)]
  
  if (length(matching_tables) < 2) {
    return(data.frame(
      issue_type = character(0),
      table_name = character(0),
      description = character(0),
      severity = character(0),
      stringsAsFactors = FALSE
    ))
  }
  
  issues <- data.frame(
    issue_type = character(0),
    table_name = character(0),
    description = character(0),
    severity = character(0),
    stringsAsFactors = FALSE
  )
  
  # Check for schema consistency across years
  for (i in seq_len(length(matching_tables) - 1)) {
    table1 <- matching_tables[i]
    table2 <- matching_tables[i + 1]
    
    schema1 <- get_table_schema(table1, db_connection)
    schema2 <- get_table_schema(table2, db_connection)
    
    if (!is.null(schema1) && !is.null(schema2)) {
      schema_issues <- compare_schemas(schema1, schema2, paste(table1, "vs", table2))
      
      if (nrow(schema_issues) > 0) {
        new_issues <- data.frame(
          issue_type = "schema_difference",
          table_name = paste(table1, table2, sep = " vs "),
          description = paste("Schema differences found:", nrow(schema_issues), "changes"),
          severity = "medium",
          stringsAsFactors = FALSE
        )
        issues <- rbind(issues, new_issues)
      }
    }
  }
  
  return(issues)
}

#' Generate data quality report
#' @param table_names Vector of table names to check (NULL for all)
#' @param db_connection Database connection
#' @return Data frame with quality assessment
#' @export
generate_quality_report <- function(table_names = NULL, db_connection = NULL) {
  
  if (is.null(db_connection)) {
    db_connection <- ensure_connection()
  }
  
  if (is.null(table_names)) {
    table_names <- DBI::dbListTables(db_connection)
    # Exclude metadata tables
    table_names <- table_names[!grepl("^ipeds_", table_names)]
  }
  
  quality_report <- data.frame(
    table_name = character(0),
    check_type = character(0),
    status = character(0),
    details = character(0),
    row_count = integer(0),
    issue_count = integer(0),
    stringsAsFactors = FALSE
  )
  
  for (table_name in table_names) {
    # Check for basic data quality issues
    table_checks <- run_quality_checks(table_name, db_connection)
    quality_report <- rbind(quality_report, table_checks)
  }
  
  return(quality_report)
}

#' Run quality checks on a single table
#' @param table_name Name of the table
#' @param db_connection Database connection
#' @return Data frame with check results
run_quality_checks <- function(table_name, db_connection) {
  
  checks <- data.frame(
    table_name = character(0),
    check_type = character(0),
    status = character(0),
    details = character(0),
    row_count = integer(0),
    issue_count = integer(0),
    stringsAsFactors = FALSE
  )
  
  tryCatch({
    # Get basic table info
    stats <- get_table_statistics(table_name, db_connection)
    
    # Check 1: Empty table
    if (stats$row_count == 0) {
      checks <- rbind(checks, data.frame(
        table_name = table_name,
        check_type = "empty_table",
        status = "warning",
        details = "Table is empty",
        row_count = 0,
        issue_count = 1,
        stringsAsFactors = FALSE
      ))
    }
    
    # Check 2: UNITID coverage (if UNITID column exists)
    unitid_check <- check_unitid_coverage(table_name, db_connection)
    if (!is.null(unitid_check)) {
      checks <- rbind(checks, unitid_check)
    }
    
    # Check 3: Duplicate records
    duplicate_check <- check_duplicates(table_name, db_connection)
    if (!is.null(duplicate_check)) {
      checks <- rbind(checks, duplicate_check)
    }
    
  }, error = function(e) {
    checks <- rbind(checks, data.frame(
      table_name = table_name,
      check_type = "error",
      status = "error",
      details = paste("Quality check failed:", e$message),
      row_count = 0,
      issue_count = 1,
      stringsAsFactors = FALSE
    ))
  })
  
  return(checks)
}

#' Check UNITID coverage in a table
#' @param table_name Name of the table
#' @param db_connection Database connection
#' @return Data frame with check result or NULL
check_unitid_coverage <- function(table_name, db_connection) {
  
  # Check if UNITID column exists
  schema <- get_table_schema(table_name, db_connection)
  if (is.null(schema) || !"UNITID" %in% schema$name) {
    return(NULL)
  }
  
  tryCatch({
    # Count total rows and rows with missing UNITID
    total_query <- paste("SELECT COUNT(*) as total FROM", table_name)
    missing_query <- paste("SELECT COUNT(*) as missing FROM", table_name, "WHERE UNITID IS NULL")
    
    total_rows <- DBI::dbGetQuery(db_connection, total_query)$total
    missing_rows <- DBI::dbGetQuery(db_connection, missing_query)$missing
    
    status <- if (missing_rows == 0) "pass" else if (missing_rows / total_rows < 0.01) "warning" else "error"
    
    return(data.frame(
      table_name = table_name,
      check_type = "unitid_coverage",
      status = status,
      details = paste(missing_rows, "missing UNITIDs out of", total_rows, "total rows"),
      row_count = total_rows,
      issue_count = missing_rows,
      stringsAsFactors = FALSE
    ))
    
  }, error = function(e) {
    return(NULL)
  })
}

#' Check for duplicate records
#' @param table_name Name of the table
#' @param db_connection Database connection
#' @return Data frame with check result or NULL
check_duplicates <- function(table_name, db_connection) {
  
  tryCatch({
    # Simple duplicate check - count total vs distinct rows
    total_query <- paste("SELECT COUNT(*) as total FROM", table_name)
    distinct_query <- paste("SELECT COUNT(DISTINCT *) as distinct_count FROM", table_name)
    
    total_rows <- DBI::dbGetQuery(db_connection, total_query)$total
    distinct_rows <- DBI::dbGetQuery(db_connection, distinct_query)$distinct_count
    
    duplicates <- total_rows - distinct_rows
    status <- if (duplicates == 0) "pass" else "warning"
    
    return(data.frame(
      table_name = table_name,
      check_type = "duplicate_rows",
      status = status,
      details = paste(duplicates, "duplicate rows found"),
      row_count = total_rows,
      issue_count = duplicates,
      stringsAsFactors = FALSE
    ))
    
  }, error = function(e) {
    return(NULL)
  })
}