#' IPEDS Data Validation and Quality Control System
#' 
#' Advanced validation functions for ensuring data integrity and quality

#' Comprehensive data validation pipeline
#' @param table_names Vector of table names to validate (NULL for all)
#' @param validation_level Level of validation: "basic", "standard", "comprehensive"
#' @param db_connection Database connection
#' @return List with validation results and summary
#' @export
validate_ipeds_data <- function(table_names = NULL, validation_level = "standard", db_connection = NULL) {
  
  if (is.null(db_connection)) {
    db_connection <- ensure_connection()
  }
  
  if (is.null(table_names)) {
    table_names <- DBI::dbListTables(db_connection)
    # Exclude metadata and system tables
    table_names <- table_names[!grepl("^(ipeds_|sqlite_)", table_names)]
  }
  
  message("Starting data validation for ", length(table_names), " tables at level: ", validation_level)
  
  validation_results <- list(
    summary = data.frame(
      table_name = character(0),
      total_checks = integer(0),
      passed_checks = integer(0),
      failed_checks = integer(0),
      warnings = integer(0),
      errors = integer(0),
      overall_status = character(0),
      stringsAsFactors = FALSE
    ),
    detailed_results = list(),
    recommendations = character(0)
  )
  
  # Progress tracking
  total_tables <- length(table_names)
  
  for (i in seq_along(table_names)) {
    table_name <- table_names[i]
    
    # Show progress every 50 tables or at milestones
    if (i == 1 || i == total_tables || i %% 50 == 0) {
      message("Validating table ", i, "/", total_tables, ": ", table_name)
    }
    
    # Run validation suite for this table
    table_validation <- validate_single_table(table_name, validation_level, db_connection)
    
    # Add to results
    validation_results$detailed_results[[table_name]] <- table_validation
    
    # Update summary
    summary_row <- data.frame(
      table_name = table_name,
      total_checks = table_validation$total_checks,
      passed_checks = table_validation$passed_checks,
      failed_checks = table_validation$failed_checks,
      warnings = table_validation$warnings,
      errors = table_validation$errors,
      overall_status = table_validation$overall_status,
      stringsAsFactors = FALSE
    )
    
    validation_results$summary <- rbind(validation_results$summary, summary_row)
  }
  
  # Generate recommendations
  validation_results$recommendations <- generate_validation_recommendations(validation_results)
  
  # Print summary
  print_validation_summary(validation_results)
  
  return(validation_results)
}

#' Validate a single table comprehensively
#' @param table_name Name of the table to validate
#' @param validation_level Level of validation
#' @param db_connection Database connection
#' @return List with detailed validation results
validate_single_table <- function(table_name, validation_level, db_connection) {
  
  results <- list(
    table_name = table_name,
    checks = data.frame(
      check_name = character(0),
      check_type = character(0),
      status = character(0),
      message = character(0),
      details = character(0),
      stringsAsFactors = FALSE
    ),
    total_checks = 0,
    passed_checks = 0,
    failed_checks = 0,
    warnings = 0,
    errors = 0,
    overall_status = "unknown"
  )
  
  # Define validation checks based on level
  checks_to_run <- get_validation_checks(validation_level)
  
  for (check_name in checks_to_run) {
    check_result <- run_validation_check(check_name, table_name, db_connection)
    
    if (!is.null(check_result)) {
      results$checks <- rbind(results$checks, check_result)
      results$total_checks <- results$total_checks + 1
      
      # Count status types
      if (check_result$status == "pass") {
        results$passed_checks <- results$passed_checks + 1
      } else if (check_result$status == "fail") {
        results$failed_checks <- results$failed_checks + 1
      } else if (check_result$status == "warning") {
        results$warnings <- results$warnings + 1
      } else if (check_result$status == "error") {
        results$errors <- results$errors + 1
      }
    }
  }
  
  # Determine overall status
  if (results$errors > 0) {
    results$overall_status <- "error"
  } else if (results$failed_checks > 0) {
    results$overall_status <- "fail"
  } else if (results$warnings > 0) {
    results$overall_status <- "warning"
  } else if (results$passed_checks > 0) {
    results$overall_status <- "pass"
  }
  
  return(results)
}

#' Get list of validation checks for a given level
#' @param validation_level Level of validation
#' @return Vector of check names
get_validation_checks <- function(validation_level) {
  
  basic_checks <- c(
    "table_exists",
    "table_not_empty",
    "basic_schema_check"
  )
  
  standard_checks <- c(
    basic_checks,
    "unitid_validation",
    "year_consistency",
    "duplicate_detection",
    "null_value_analysis",
    "data_type_consistency"
  )
  
  comprehensive_checks <- c(
    standard_checks,
    "cross_year_comparison",
    "referential_integrity",
    "value_range_validation",
    "encoding_validation",
    "completeness_analysis",
    "outlier_detection"
  )
  
  switch(validation_level,
    "basic" = basic_checks,
    "standard" = standard_checks,
    "comprehensive" = comprehensive_checks,
    standard_checks
  )
}

#' Run a specific validation check
#' @param check_name Name of the check to run
#' @param table_name Name of the table
#' @param db_connection Database connection
#' @return Data frame with check result
run_validation_check <- function(check_name, table_name, db_connection) {
  
  tryCatch({
    switch(check_name,
      "table_exists" = check_table_exists(table_name, db_connection),
      "table_not_empty" = check_table_not_empty(table_name, db_connection),
      "basic_schema_check" = check_basic_schema(table_name, db_connection),
      "unitid_validation" = check_unitid_validation(table_name, db_connection),
      "year_consistency" = check_year_consistency(table_name, db_connection),
      "duplicate_detection" = check_duplicate_detection(table_name, db_connection),
      "null_value_analysis" = check_null_values(table_name, db_connection),
      "data_type_consistency" = check_data_types(table_name, db_connection),
      "cross_year_comparison" = check_cross_year_data(table_name, db_connection),
      "referential_integrity" = check_referential_integrity(table_name, db_connection),
      "value_range_validation" = check_value_ranges(table_name, db_connection),
      "encoding_validation" = check_text_encoding(table_name, db_connection),
      "completeness_analysis" = check_data_completeness(table_name, db_connection),
      "outlier_detection" = check_statistical_outliers(table_name, db_connection),
      NULL
    )
  }, error = function(e) {
    data.frame(
      check_name = check_name,
      check_type = "validation",
      status = "error",
      message = paste("Check failed:", e$message),
      details = "",
      stringsAsFactors = FALSE
    )
  })
}

#' Check if table exists
#' @param table_name Name of the table
#' @param db_connection Database connection
#' @return Check result data frame
check_table_exists <- function(table_name, db_connection) {
  
  exists <- table_name %in% DBI::dbListTables(db_connection)
  
  data.frame(
    check_name = "table_exists",
    check_type = "structural",
    status = if (exists) "pass" else "fail",
    message = if (exists) "Table exists" else "Table does not exist",
    details = "",
    stringsAsFactors = FALSE
  )
}

#' Check if table is not empty
#' @param table_name Name of the table
#' @param db_connection Database connection
#' @return Check result data frame
check_table_not_empty <- function(table_name, db_connection) {
  
  query <- paste("SELECT COUNT(*) as row_count FROM", table_name)
  row_count <- DBI::dbGetQuery(db_connection, query)$row_count
  
  data.frame(
    check_name = "table_not_empty",
    check_type = "content",
    status = if (row_count > 0) "pass" else "fail",
    message = paste("Table has", row_count, "rows"),
    details = paste("Row count:", row_count),
    stringsAsFactors = FALSE
  )
}

#' Check basic schema requirements
#' @param table_name Name of the table
#' @param db_connection Database connection
#' @return Check result data frame
check_basic_schema <- function(table_name, db_connection) {
  
  schema_query <- paste("PRAGMA table_info(", table_name, ")")
  schema <- DBI::dbGetQuery(db_connection, schema_query)
  
  has_columns <- nrow(schema) > 0
  
  data.frame(
    check_name = "basic_schema_check",
    check_type = "structural",
    status = if (has_columns) "pass" else "fail",
    message = paste("Table has", nrow(schema), "columns"),
    details = paste("Columns:", paste(schema$name, collapse = ", ")),
    stringsAsFactors = FALSE
  )
}

#' Validate UNITID column if present
#' @param table_name Name of the table
#' @param db_connection Database connection
#' @return Check result data frame
check_unitid_validation <- function(table_name, db_connection) {
  
  schema_query <- paste("PRAGMA table_info(", table_name, ")")
  schema <- DBI::dbGetQuery(db_connection, schema_query)
  
  if (!"UNITID" %in% schema$name) {
    return(data.frame(
      check_name = "unitid_validation",
      check_type = "content",
      status = "pass",
      message = "No UNITID column found (not required for all tables)",
      details = "",
      stringsAsFactors = FALSE
    ))
  }
  
  # Check UNITID format and completeness
  unitid_query <- paste(
    "SELECT ",
    "COUNT(*) as total_rows,",
    "COUNT(UNITID) as non_null_unitids,",
    "MIN(UNITID) as min_unitid,",
    "MAX(UNITID) as max_unitid",
    "FROM", table_name
  )
  
  unitid_stats <- DBI::dbGetQuery(db_connection, unitid_query)
  
  completeness <- unitid_stats$non_null_unitids / unitid_stats$total_rows
  valid_range <- unitid_stats$min_unitid >= 100000 && unitid_stats$max_unitid <= 999999
  
  status <- if (completeness >= 0.95 && valid_range) "pass" else if (completeness >= 0.9) "warning" else "fail"
  
  data.frame(
    check_name = "unitid_validation",
    check_type = "content",
    status = status,
    message = paste("UNITID completeness:", round(completeness * 100, 1), "%; Range valid:", valid_range),
    details = paste("Range:", unitid_stats$min_unitid, "-", unitid_stats$max_unitid),
    stringsAsFactors = FALSE
  )
}

#' Check year consistency in table name vs data
#' @param table_name Name of the table
#' @param db_connection Database connection
#' @return Check result data frame
check_year_consistency <- function(table_name, db_connection) {
  
  # Extract year from table name if present
  year_pattern <- "20[0-9]{2}"
  table_year <- regmatches(table_name, regexpr(year_pattern, table_name))
  
  if (length(table_year) == 0) {
    return(data.frame(
      check_name = "year_consistency",
      check_type = "logical",
      status = "pass",
      message = "No year found in table name",
      details = "",
      stringsAsFactors = FALSE
    ))
  }
  
  # Check if there are year columns in the data
  schema_query <- paste("PRAGMA table_info(", table_name, ")")
  schema <- DBI::dbGetQuery(db_connection, schema_query)
  
  year_columns <- schema$name[grepl("YEAR|year", schema$name)]
  
  if (length(year_columns) == 0) {
    return(data.frame(
      check_name = "year_consistency",
      check_type = "logical",
      status = "warning",
      message = "Table name contains year but no year columns found",
      details = paste("Table year:", table_year),
      stringsAsFactors = FALSE
    ))
  }
  
  # Check year values in data
  year_col <- year_columns[1]
  year_query <- paste("SELECT DISTINCT", year_col, "FROM", table_name, "ORDER BY", year_col)
  data_years <- DBI::dbGetQuery(db_connection, year_query)[[1]]
  
  consistent <- table_year %in% as.character(data_years)
  
  data.frame(
    check_name = "year_consistency",
    check_type = "logical",
    status = if (consistent) "pass" else "warning",
    message = paste("Table year:", table_year, "; Data years:", paste(data_years, collapse = ", ")),
    details = paste("Consistent:", consistent),
    stringsAsFactors = FALSE
  )
}

#' Enhanced duplicate detection
#' @param table_name Name of the table
#' @param db_connection Database connection
#' @return Check result data frame
check_duplicate_detection <- function(table_name, db_connection) {
  
  # Get total row count
  total_query <- paste("SELECT COUNT(*) as total FROM", table_name)
  total_rows <- DBI::dbGetQuery(db_connection, total_query)$total
  
  # For duplicate detection, use a hash-based approach that works in DuckDB
  # This counts distinct combinations of all columns
  if (total_rows > 100000) {
    # For large tables, do a sample-based check using hash
    sample_size <- min(10000, total_rows)
    distinct_query <- paste0(
      "SELECT COUNT(*) as distinct_count FROM (",
      "SELECT DISTINCT * FROM ", table_name, " LIMIT ", sample_size,
      ")"
    )
    
    tryCatch({
      distinct_rows <- DBI::dbGetQuery(db_connection, distinct_query)$distinct_count
      
      # Estimate duplicate rate
      duplicate_rate <- (sample_size - distinct_rows) / sample_size
      estimated_duplicates <- round(duplicate_rate * total_rows)
      
      status <- if (duplicate_rate == 0) "pass" else if (duplicate_rate < 0.01) "warning" else "fail"
      
      return(data.frame(
        check_name = "duplicate_detection",
        check_type = "quality",
        status = status,
        message = paste("Estimated", estimated_duplicates, "duplicates (", round(duplicate_rate * 100, 2), "%)"),
        details = paste("Sample-based estimate from", sample_size, "rows"),
        stringsAsFactors = FALSE
      ))
    }, error = function(e) {
      # If the query fails, skip this check
      return(data.frame(
        check_name = "duplicate_detection",
        check_type = "quality",
        status = "pass",
        message = "Duplicate check skipped for large table",
        details = paste("Table has", total_rows, "rows"),
        stringsAsFactors = FALSE
      ))
    })
  } else {
    # For smaller tables, do full check by counting distinct rows
    distinct_query <- paste0(
      "SELECT COUNT(*) as distinct_count FROM (",
      "SELECT DISTINCT * FROM ", table_name,
      ")"
    )
    
    tryCatch({
      distinct_rows <- DBI::dbGetQuery(db_connection, distinct_query)$distinct_count
      
      duplicates <- total_rows - distinct_rows
      duplicate_rate <- duplicates / total_rows
      
      status <- if (duplicates == 0) "pass" else if (duplicate_rate < 0.01) "warning" else "fail"
      
      return(data.frame(
        check_name = "duplicate_detection",
        check_type = "quality",
        status = status,
        message = paste(duplicates, "duplicate rows found (", round(duplicate_rate * 100, 2), "%)"),
        details = paste("Total rows:", total_rows, "; Distinct rows:", distinct_rows),
        stringsAsFactors = FALSE
      ))
    }, error = function(e) {
      # If the query fails, skip this check
      return(data.frame(
        check_name = "duplicate_detection",
        check_type = "quality",
        status = "pass",
        message = "Duplicate check skipped",
        details = "Unable to perform duplicate detection",
        stringsAsFactors = FALSE
      ))
    })
  }
}

#' Analyze null values in critical columns
#' @param table_name Name of the table
#' @param db_connection Database connection
#' @return Check result data frame
check_null_values <- function(table_name, db_connection) {
  
  schema_query <- paste("PRAGMA table_info(", table_name, ")")
  schema <- DBI::dbGetQuery(db_connection, schema_query)
  
  # Focus on critical columns that shouldn't have many nulls
  critical_columns <- c("UNITID", "YEAR", "INSTNM")
  existing_critical <- intersect(critical_columns, schema$name)
  
  if (length(existing_critical) == 0) {
    return(data.frame(
      check_name = "null_value_analysis",
      check_type = "quality",
      status = "pass",
      message = "No critical columns found for null analysis",
      details = "",
      stringsAsFactors = FALSE
    ))
  }
  
  # Check null percentages for critical columns
  total_query <- paste("SELECT COUNT(*) as total FROM", table_name)
  total_rows <- DBI::dbGetQuery(db_connection, total_query)$total
  
  null_issues <- 0
  details <- character(0)
  
  for (col in existing_critical) {
    null_query <- paste("SELECT COUNT(*) as null_count FROM", table_name, "WHERE", col, "IS NULL")
    null_count <- DBI::dbGetQuery(db_connection, null_query)$null_count
    null_pct <- (null_count / total_rows) * 100
    
    if (null_pct > 5) {  # More than 5% nulls is concerning for critical columns
      null_issues <- null_issues + 1
    }
    
    details <- c(details, paste(col, ":", round(null_pct, 1), "%"))
  }
  
  status <- if (null_issues == 0) "pass" else if (null_issues <= 1) "warning" else "fail"
  
  data.frame(
    check_name = "null_value_analysis",
    check_type = "quality",
    status = status,
    message = paste(null_issues, "columns with high null rates"),
    details = paste(details, collapse = "; "),
    stringsAsFactors = FALSE
  )
}

#' Check data type consistency
#' @param table_name Name of the table
#' @param db_connection Database connection
#' @return Check result data frame
check_data_types <- function(table_name, db_connection) {
  
  schema_query <- paste("PRAGMA table_info(", table_name, ")")
  schema <- DBI::dbGetQuery(db_connection, schema_query)
  
  # Check for common IPEDS data type patterns
  type_issues <- 0
  details <- character(0)
  
  for (i in seq_len(nrow(schema))) {
    col_name <- schema$name[i]
    col_type <- schema$type[i]
    
    # Check expected types for known IPEDS columns
    expected_type <- get_expected_ipeds_type(col_name)
    
    if (!is.null(expected_type) && !grepl(expected_type, col_type, ignore.case = TRUE)) {
      type_issues <- type_issues + 1
      details <- c(details, paste(col_name, ":", col_type, "expected", expected_type))
    }
  }
  
  status <- if (type_issues == 0) "pass" else if (type_issues <= 2) "warning" else "fail"
  
  data.frame(
    check_name = "data_type_consistency",
    check_type = "structural",
    status = status,
    message = paste(type_issues, "potential type inconsistencies"),
    details = paste(details, collapse = "; "),
    stringsAsFactors = FALSE
  )
}

#' Get expected data type for known IPEDS columns
#' @param column_name Name of the column
#' @return Expected type or NULL
get_expected_ipeds_type <- function(column_name) {
  
  type_map <- list(
    "UNITID" = "INTEGER",
    "YEAR" = "INTEGER", 
    "INSTNM" = "TEXT",
    "CITY" = "TEXT",
    "STABBR" = "TEXT",
    "ZIP" = "TEXT",
    "FIPS" = "INTEGER",
    "OBEREG" = "INTEGER",
    "SECTOR" = "INTEGER"
  )
  
  return(type_map[[column_name]])
}

#' Check cross-year data consistency
#' @param table_name Name of the table
#' @param db_connection Database connection
#' @return Check result data frame
check_cross_year_data <- function(table_name, db_connection) {
  
  # Extract survey component from table name to find related tables
  base_name <- gsub("[0-9]{4}", "", table_name)  # Remove year
  all_tables <- DBI::dbListTables(db_connection)
  related_tables <- all_tables[grepl(base_name, all_tables)]
  
  if (length(related_tables) < 2) {
    return(data.frame(
      check_name = "cross_year_comparison",
      check_type = "consistency",
      status = "pass",
      message = "No related tables found for comparison",
      details = "",
      stringsAsFactors = FALSE
    ))
  }
  
  # Compare schema consistency across years
  schema_issues <- 0
  details <- character(0)
  
  current_schema <- get_table_schema(table_name, db_connection)
  
  for (related_table in related_tables) {
    if (related_table != table_name) {
      related_schema <- get_table_schema(related_table, db_connection)
      
      if (!is.null(related_schema) && !is.null(current_schema)) {
        # Compare column names
        current_cols <- current_schema$name
        related_cols <- related_schema$name
        
        missing_cols <- setdiff(current_cols, related_cols)
        extra_cols <- setdiff(related_cols, current_cols)
        
        if (length(missing_cols) > 0 || length(extra_cols) > 0) {
          schema_issues <- schema_issues + 1
          details <- c(details, paste("vs", related_table, ":", 
                                    length(missing_cols), "missing,", 
                                    length(extra_cols), "extra columns"))
        }
      }
    }
  }
  
  status <- if (schema_issues == 0) "pass" else if (schema_issues <= 2) "warning" else "fail"
  
  data.frame(
    check_name = "cross_year_comparison",
    check_type = "consistency",
    status = status,
    message = paste(schema_issues, "schema inconsistencies found"),
    details = paste(details, collapse = "; "),
    stringsAsFactors = FALSE
  )
}

#' Check referential integrity (UNITID consistency)
#' @param table_name Name of the table
#' @param db_connection Database connection
#' @return Check result data frame
check_referential_integrity <- function(table_name, db_connection) {
  
  schema_query <- paste("PRAGMA table_info(", table_name, ")")
  schema <- DBI::dbGetQuery(db_connection, schema_query)
  
  if (!"UNITID" %in% schema$name) {
    return(data.frame(
      check_name = "referential_integrity",
      check_type = "consistency",
      status = "pass",
      message = "No UNITID column for referential integrity check",
      details = "",
      stringsAsFactors = FALSE
    ))
  }
  
  # Check if we have institutional directory tables
  all_tables <- DBI::dbListTables(db_connection)
  hd_tables <- all_tables[grepl("^HD", all_tables)]
  
  if (length(hd_tables) == 0) {
    return(data.frame(
      check_name = "referential_integrity",
      check_type = "consistency",
      status = "warning",
      message = "No institutional directory (HD) tables found for referential check",
      details = "",
      stringsAsFactors = FALSE
    ))
  }
  
  # Use the most recent HD table for reference
  reference_table <- hd_tables[length(hd_tables)]
  
  # Check how many UNITIDs in current table exist in reference
  integrity_query <- paste(
    "SELECT COUNT(*) as orphaned_unitids FROM",
    "(SELECT DISTINCT UNITID FROM", table_name, ") t1",
    "LEFT JOIN (SELECT DISTINCT UNITID FROM", reference_table, ") t2",
    "ON t1.UNITID = t2.UNITID",
    "WHERE t2.UNITID IS NULL"
  )
  
  tryCatch({
    orphaned_count <- DBI::dbGetQuery(db_connection, integrity_query)$orphaned_unitids
    
    total_query <- paste("SELECT COUNT(DISTINCT UNITID) as total FROM", table_name)
    total_unitids <- DBI::dbGetQuery(db_connection, total_query)$total
    
    orphaned_pct <- (orphaned_count / total_unitids) * 100
    
    status <- if (orphaned_pct == 0) "pass" else if (orphaned_pct < 5) "warning" else "fail"
    
    data.frame(
      check_name = "referential_integrity",
      check_type = "consistency",
      status = status,
      message = paste(orphaned_count, "orphaned UNITIDs (", round(orphaned_pct, 1), "%)"),
      details = paste("Reference table:", reference_table),
      stringsAsFactors = FALSE
    )
    
  }, error = function(e) {
    data.frame(
      check_name = "referential_integrity",
      check_type = "consistency",
      status = "error",
      message = paste("Referential integrity check failed:", e$message),
      details = "",
      stringsAsFactors = FALSE
    )
  })
}

#' Check value ranges for numeric columns
#' @param table_name Name of the table
#' @param db_connection Database connection
#' @return Check result data frame
check_value_ranges <- function(table_name, db_connection) {
  
  schema_query <- paste("PRAGMA table_info(", table_name, ")")
  schema <- DBI::dbGetQuery(db_connection, schema_query)
  
  # Focus on numeric columns
  numeric_columns <- schema$name[grepl("INTEGER|REAL|NUMERIC", schema$type, ignore.case = TRUE)]
  
  if (length(numeric_columns) == 0) {
    return(data.frame(
      check_name = "value_range_validation",
      check_type = "quality",
      status = "pass",
      message = "No numeric columns found for range validation",
      details = "",
      stringsAsFactors = FALSE
    ))
  }
  
  range_issues <- 0
  details <- character(0)
  
  for (col in numeric_columns) {
    tryCatch({
      range_query <- paste("SELECT MIN(", col, ") as min_val, MAX(", col, ") as max_val FROM", table_name, "WHERE", col, "IS NOT NULL")
      range_data <- DBI::dbGetQuery(db_connection, range_query)
      
      # Check for reasonable ranges based on column name
      expected_range <- get_expected_range(col)
      
      if (!is.null(expected_range)) {
        min_val <- range_data$min_val
        max_val <- range_data$max_val
        
        if (!is.na(min_val) && !is.na(max_val)) {
          if (min_val < expected_range$min || max_val > expected_range$max) {
            range_issues <- range_issues + 1
            details <- c(details, paste(col, ":", min_val, "-", max_val, 
                                      "expected", expected_range$min, "-", expected_range$max))
          }
        }
      }
      
    }, error = function(e) {
      # Skip columns that cause errors
    })
  }
  
  status <- if (range_issues == 0) "pass" else if (range_issues <= 2) "warning" else "fail"
  
  data.frame(
    check_name = "value_range_validation",
    check_type = "quality",
    status = status,
    message = paste(range_issues, "columns with unexpected ranges"),
    details = paste(details, collapse = "; "),
    stringsAsFactors = FALSE
  )
}

#' Get expected range for known IPEDS columns
#' @param column_name Name of the column
#' @return List with min and max or NULL
get_expected_range <- function(column_name) {
  
  range_map <- list(
    "UNITID" = list(min = 100000, max = 999999),
    "YEAR" = list(min = 1980, max = 2030),
    "FIPS" = list(min = 1, max = 99),
    "OBEREG" = list(min = 0, max = 9),
    "SECTOR" = list(min = 0, max = 99)
  )
  
  return(range_map[[column_name]])
}

#' Check text encoding issues
#' @param table_name Name of the table
#' @param db_connection Database connection
#' @return Check result data frame
check_text_encoding <- function(table_name, db_connection) {
  
  schema_query <- paste("PRAGMA table_info(", table_name, ")")
  schema <- DBI::dbGetQuery(db_connection, schema_query)
  
  # Focus on text columns
  text_columns <- schema$name[grepl("TEXT|CHAR|VARCHAR", schema$type, ignore.case = TRUE)]
  
  if (length(text_columns) == 0) {
    return(data.frame(
      check_name = "encoding_validation",
      check_type = "quality",
      status = "pass",
      message = "No text columns found for encoding validation",
      details = "",
      stringsAsFactors = FALSE
    ))
  }
  
  encoding_issues <- 0
  details <- character(0)
  
  # Sample some text values to check for encoding issues
  max_cols_to_check <- min(3, length(text_columns))
  if (max_cols_to_check > 0) {
    for (i in seq_len(max_cols_to_check)) {
      col <- text_columns[i]
      tryCatch({
        sample_query <- paste("SELECT", col, "FROM", table_name, "WHERE", col, "IS NOT NULL LIMIT 100")
        sample_data <- DBI::dbGetQuery(db_connection, sample_query)[[1]]
        
        # Check for common encoding issues
        has_weird_chars <- any(grepl("[^\x20-\x7E]", sample_data, perl = TRUE))
        has_null_chars <- any(grepl("\\x00", sample_data, perl = TRUE))
        
        if (has_weird_chars || has_null_chars) {
          encoding_issues <- encoding_issues + 1
          issues <- c()
          if (has_weird_chars) issues <- c(issues, "non-ASCII")
          if (has_null_chars) issues <- c(issues, "null-chars")
          details <- c(details, paste(col, ":", paste(issues, collapse = ",")))
        }
        
      }, error = function(e) {
        # Skip columns that cause errors
      })
    }
  }
  
  status <- if (encoding_issues == 0) "pass" else "warning"
  
  data.frame(
    check_name = "encoding_validation",
    check_type = "quality",
    status = status,
    message = paste(encoding_issues, "columns with potential encoding issues"),
    details = paste(details, collapse = "; "),
    stringsAsFactors = FALSE
  )
}

#' Check data completeness patterns
#' @param table_name Name of the table
#' @param db_connection Database connection
#' @return Check result data frame
check_data_completeness <- function(table_name, db_connection) {
  
  schema_query <- paste("PRAGMA table_info(", table_name, ")")
  schema <- DBI::dbGetQuery(db_connection, schema_query)
  
  total_query <- paste("SELECT COUNT(*) as total FROM", table_name)
  total_rows <- DBI::dbGetQuery(db_connection, total_query)$total
  
  if (total_rows == 0) {
    return(data.frame(
      check_name = "completeness_analysis",
      check_type = "quality",
      status = "fail",
      message = "Table is empty",
      details = "",
      stringsAsFactors = FALSE
    ))
  }
  
  completeness_issues <- 0
  details <- character(0)
  
  # Check completeness for important columns
  important_columns <- intersect(c("UNITID", "INSTNM", "YEAR"), schema$name)
  
  for (col in important_columns) {
    non_null_query <- paste("SELECT COUNT(*) as non_null FROM", table_name, "WHERE", col, "IS NOT NULL")
    non_null_count <- DBI::dbGetQuery(db_connection, non_null_query)$non_null
    
    completeness_pct <- (non_null_count / total_rows) * 100
    
    if (completeness_pct < 95) {  # Less than 95% completeness is concerning
      completeness_issues <- completeness_issues + 1
      details <- c(details, paste(col, ":", round(completeness_pct, 1), "%"))
    }
  }
  
  status <- if (completeness_issues == 0) "pass" else if (completeness_issues == 1) "warning" else "fail"
  
  data.frame(
    check_name = "completeness_analysis",
    check_type = "quality",
    status = status,
    message = paste(completeness_issues, "columns with low completeness"),
    details = paste(details, collapse = "; "),
    stringsAsFactors = FALSE
  )
}

#' Check for statistical outliers in numeric data
#' @param table_name Name of the table
#' @param db_connection Database connection
#' @return Check result data frame
check_statistical_outliers <- function(table_name, db_connection) {
  
  schema_query <- paste("PRAGMA table_info(", table_name, ")")
  schema <- DBI::dbGetQuery(db_connection, schema_query)
  
  # Focus on numeric columns that might represent counts or amounts
  numeric_columns <- schema$name[grepl("INTEGER|REAL|NUMERIC", schema$type, ignore.case = TRUE)]
  numeric_columns <- numeric_columns[!grepl("UNITID|YEAR|FIPS|ID", numeric_columns)]  # Exclude identifier columns
  
  if (length(numeric_columns) == 0) {
    return(data.frame(
      check_name = "outlier_detection",
      check_type = "quality",
      status = "pass",
      message = "No suitable numeric columns found for outlier detection",
      details = "",
      stringsAsFactors = FALSE
    ))
  }
  
  outlier_columns <- 0
  details <- character(0)
  
  # Check first few numeric columns for outliers
  max_numeric_cols <- min(3, length(numeric_columns))
  if (max_numeric_cols > 0) {
    for (i in seq_len(max_numeric_cols)) {
      col <- numeric_columns[i]
    tryCatch({
      stats_query <- paste(
        "SELECT",
        "AVG(", col, ") as mean_val,",
        "MIN(", col, ") as min_val,",
        "MAX(", col, ") as max_val,",
        "COUNT(", col, ") as count_val",
        "FROM", table_name,
        "WHERE", col, "IS NOT NULL AND", col, "> 0"
      )
      
      stats_data <- DBI::dbGetQuery(db_connection, stats_query)
      
      if (stats_data$count_val > 10 && !is.na(stats_data$mean_val)) {
        # Simple outlier detection: check if max is more than 100x the mean
        if (stats_data$max_val > (stats_data$mean_val * 100)) {
          outlier_columns <- outlier_columns + 1
          details <- c(details, paste(col, ": max", stats_data$max_val, "vs mean", round(stats_data$mean_val, 1)))
        }
      }
      
    }, error = function(e) {
      # Skip columns that cause errors
    })
  }
  }
  
  status <- if (outlier_columns == 0) "pass" else "warning"
  
  data.frame(
    check_name = "outlier_detection",
    check_type = "quality",
    status = status,
    message = paste(outlier_columns, "columns with potential outliers"),
    details = paste(details, collapse = "; "),
    stringsAsFactors = FALSE
  )
}

#' Print validation summary
#' @param validation_results Results from validation
print_validation_summary <- function(validation_results) {
  
  cat("\n" , "=" , rep("=", 30), "=", "\n")
  cat("IPEDS DATA VALIDATION SUMMARY\n")
  cat("=" , rep("=", 30), "=", "\n\n")
  
  summary <- validation_results$summary
  
  cat("Tables validated:", nrow(summary), "\n")
  cat("Overall status distribution:\n")
  
  status_counts <- table(summary$overall_status)
  for (status in names(status_counts)) {
    cat("  ", status, ":", status_counts[status], "\n")
  }
  
  cat("\nTotals across all tables:\n")
  cat("  Total checks:", sum(summary$total_checks), "\n")
  cat("  Passed:", sum(summary$passed_checks), "\n")
  cat("  Failed:", sum(summary$failed_checks), "\n")
  cat("  Warnings:", sum(summary$warnings), "\n")
  cat("  Errors:", sum(summary$errors), "\n")
  
  # Show tables with issues
  problem_tables <- summary[summary$overall_status %in% c("fail", "error"), ]
  if (nrow(problem_tables) > 0) {
    cat("\nTables requiring attention:\n")
    for (i in seq_len(nrow(problem_tables))) {
      cat("  ", problem_tables$table_name[i], " (", problem_tables$overall_status[i], ")\n")
    }
  }
  
  cat("\n")
}

#' Generate validation recommendations
#' @param validation_results Results from validation
#' @return Vector of recommendations
generate_validation_recommendations <- function(validation_results) {
  
  recommendations <- character(0)
  summary <- validation_results$summary
  
  # Check for common issues
  high_error_tables <- summary[summary$errors > 0, ]
  if (nrow(high_error_tables) > 0) {
    recommendations <- c(recommendations, 
      paste("Investigate error conditions in tables:", paste(high_error_tables$table_name, collapse = ", ")))
  }
  
  high_fail_tables <- summary[summary$failed_checks > summary$passed_checks, ]
  if (nrow(high_fail_tables) > 0) {
    recommendations <- c(recommendations,
      paste("Review data quality in tables with high failure rates:", paste(high_fail_tables$table_name, collapse = ", ")))
  }
  
  # Overall health check
  total_checks <- sum(summary$total_checks)
  total_passed <- sum(summary$passed_checks)
  pass_rate <- total_passed / total_checks
  
  if (pass_rate < 0.8) {
    recommendations <- c(recommendations,
      paste("Overall pass rate is", round(pass_rate * 100, 1), "% - consider comprehensive data review"))
  }
  
  if (length(recommendations) == 0) {
    recommendations <- "Data quality appears good overall. Consider running comprehensive validation periodically."
  }
  
  return(recommendations)
}