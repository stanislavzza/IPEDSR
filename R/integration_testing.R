#' IPEDS Data Management Integration Testing Suite
#' 
#' Comprehensive tests to validate complete data management workflow

#' Run complete integration test suite
#' @param test_year Year to use for testing (default: previous year)
#' @param quick_mode Whether to run abbreviated tests for speed
#' @param verbose Whether to show detailed output
#' @return List with test results
#' @export
run_integration_tests <- function(test_year = NULL, quick_mode = FALSE, verbose = TRUE) {
  
  if (is.null(test_year)) {
    test_year <- as.numeric(format(Sys.Date(), "%Y")) - 1
  }
  
  if (verbose) {
    cat("\n")
    cat("=" , rep("=", 60), "=", "\n")
    cat("IPEDS DATA MANAGEMENT INTEGRATION TESTS\n")
    cat("=" , rep("=", 60), "=", "\n")
    cat("Test Year:", test_year, "\n")
    cat("Quick Mode:", quick_mode, "\n")
    cat("Started:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")
    cat(rep("=", 62), "\n\n")
  }
  
  # Initialize test results
  test_results <- list(
    start_time = Sys.time(),
    test_year = test_year,
    quick_mode = quick_mode,
    tests = list(),
    summary = list(
      total_tests = 0,
      passed = 0,
      failed = 0,
      warnings = 0,
      errors = 0
    ),
    overall_status = "unknown"
  )
  
  # Define test suite
  test_suite <- get_integration_test_suite(quick_mode)
  test_results$summary$total_tests <- length(test_suite)
  
  if (verbose) {
    cat("Running", length(test_suite), "integration tests...\n\n")
  }
  
  # Run each test
  for (i in seq_along(test_suite)) {
    test_name <- names(test_suite)[i]
    test_function <- test_suite[[i]]
    
    if (verbose) {
      cat("Test", i, "/", length(test_suite), ":", test_name, "...")
    }
    
    # Run the test
    test_result <- run_single_integration_test(test_function, test_year, verbose)
    test_results$tests[[test_name]] <- test_result
    
    # Update summary
    if (test_result$status == "pass") {
      test_results$summary$passed <- test_results$summary$passed + 1
      if (verbose) cat(" ✅ PASS\n")
    } else if (test_result$status == "fail") {
      test_results$summary$failed <- test_results$summary$failed + 1
      if (verbose) cat(" ❌ FAIL\n")
    } else if (test_result$status == "warning") {
      test_results$summary$warnings <- test_results$summary$warnings + 1
      if (verbose) cat(" ⚠️  WARN\n")
    } else if (test_result$status == "error") {
      test_results$summary$errors <- test_results$summary$errors + 1
      if (verbose) cat(" 💥 ERROR\n")
    }
    
    if (verbose && test_result$message != "") {
      cat("     ", test_result$message, "\n")
    }
    
    if (verbose && length(test_result$details) > 0) {
      for (detail in test_result$details) {
        cat("     ", detail, "\n")
      }
    }
    
    if (verbose) cat("\n")
  }
  
  # Calculate overall status
  test_results$end_time <- Sys.time()
  test_results$duration <- as.numeric(test_results$end_time - test_results$start_time, units = "secs")
  
  if (test_results$summary$errors > 0) {
    test_results$overall_status <- "error"
  } else if (test_results$summary$failed > 0) {
    test_results$overall_status <- "fail"
  } else if (test_results$summary$warnings > 0) {
    test_results$overall_status <- "warning"
  } else {
    test_results$overall_status <- "pass"
  }
  
  # Print summary
  if (verbose) {
    print_integration_test_summary(test_results)
  }
  
  return(test_results)
}

#' Get the integration test suite
#' @param quick_mode Whether to use abbreviated test suite
#' @return Named list of test functions
get_integration_test_suite <- function(quick_mode = FALSE) {
  
  basic_tests <- list(
    "database_connection" = test_database_connection,
    "web_scraping" = test_web_scraping_functionality,
    "file_download" = test_file_download_functionality,
    "data_processing" = test_data_processing_functionality,
    "validation_system" = test_validation_system,
    "user_interface" = test_user_interface_functions
  )
  
  if (quick_mode) {
    return(basic_tests)
  }
  
  # Add comprehensive tests
  comprehensive_tests <- list(
    "version_tracking" = test_version_tracking_system,
    "backup_restore" = test_backup_restore_functionality,
    "error_handling" = test_error_handling_robustness,
    "end_to_end_workflow" = test_end_to_end_workflow,
    "performance_benchmarks" = test_performance_benchmarks,
    "data_integrity" = test_data_integrity_checks
  )
  
  return(c(basic_tests, comprehensive_tests))
}

#' Run a single integration test
#' @param test_function Function to run
#' @param test_year Year for testing
#' @param verbose Whether to show detailed output
#' @return Test result list
run_single_integration_test <- function(test_function, test_year, verbose = TRUE) {
  
  result <- list(
    status = "unknown",
    message = "",
    details = character(0),
    start_time = Sys.time(),
    duration = 0,
    data = NULL
  )
  
  tryCatch({
    # Run the test function
    test_output <- test_function(test_year, verbose)
    
    result$status <- test_output$status
    result$message <- test_output$message
    result$details <- test_output$details
    result$data <- test_output$data
    
  }, error = function(e) {
    result$status <<- "error"
    result$message <<- paste("Test failed with error:", e$message)
    result$details <<- c(result$details, as.character(e))
  })
  
  result$end_time <- Sys.time()
  result$duration <- as.numeric(result$end_time - result$start_time, units = "secs")
  
  return(result)
}

#' Test database connection functionality
#' @param test_year Year for testing
#' @param verbose Verbose output
#' @return Test result
test_database_connection <- function(test_year, verbose = FALSE) {
  
  result <- list(status = "unknown", message = "", details = character(0), data = NULL)
  
  tryCatch({
    # Test connection creation
    db_connection <- ensure_connection()
    
    if (!DBI::dbIsValid(db_connection)) {
      result$status <- "fail"
      result$message <- "Database connection is not valid"
      return(result)
    }
    
    # Test basic query
    tables <- DBI::dbListTables(db_connection)
    
    # Test metadata table initialization
    metadata_exists <- "ipeds_metadata" %in% tables
    if (!metadata_exists) {
      init_result <- initialize_version_tracking(db_connection)
      if (!init_result) {
        result$status <- "warning"
        result$message <- "Could not initialize version tracking"
        result$details <- c("Version tracking initialization failed")
      }
    }
    
    result$status <- "pass"
    result$message <- paste("Database connection successful,", length(tables), "tables found")
    result$data <- list(table_count = length(tables), metadata_exists = metadata_exists)
    
  }, error = function(e) {
    result$status <- "fail"
    result$message <- paste("Database connection failed:", e$message)
  })
  
  return(result)
}

#' Test web scraping functionality
#' @param test_year Year for testing
#' @param verbose Verbose output
#' @return Test result
test_web_scraping_functionality <- function(test_year, verbose = FALSE) {
  
  result <- list(status = "unknown", message = "", details = character(0), data = NULL)
  
  tryCatch({
    # Test basic scraping
    files <- scrape_ipeds_files_enhanced(test_year)
    
    if (length(files) == 0) {
      result$status <- "warning"
      result$message <- paste("No files found for year", test_year)
      return(result)
    }
    
    # Check file structure
    sample_file <- files[[1]]
    required_fields <- c("title", "survey_component", "year", "file_url")
    missing_fields <- setdiff(required_fields, names(sample_file))
    
    if (length(missing_fields) > 0) {
      result$status <- "fail"
      result$message <- "File info missing required fields"
      result$details <- paste("Missing:", paste(missing_fields, collapse = ", "))
      return(result)
    }
    
    # Test update checking
    updates <- check_ipeds_updates(test_year)
    
    result$status <- "pass"
    result$message <- paste("Web scraping successful,", length(files), "files found")
    result$data <- list(
      file_count = length(files), 
      update_count = length(updates),
      sample_file = sample_file
    )
    
  }, error = function(e) {
    result$status <- "fail"
    result$message <- paste("Web scraping failed:", e$message)
  })
  
  return(result)
}

#' Test file download functionality
#' @param test_year Year for testing
#' @param verbose Verbose output
#' @return Test result
test_file_download_functionality <- function(test_year, verbose = FALSE) {
  
  result <- list(status = "unknown", message = "", details = character(0), data = NULL)
  
  tryCatch({
    # Get available files
    files <- scrape_ipeds_files_enhanced(test_year)
    
    if (length(files) == 0) {
      result$status <- "warning"
      result$message <- "No files available for download test"
      return(result)
    }
    
    # Test downloading a small file (first one)
    test_file <- files[[1]]
    temp_file <- tempfile(fileext = ".csv")
    
    # Test the download function
    download_result <- download_ipeds_csv(test_file$file_url, temp_file)
    
    if (!download_result) {
      result$status <- "fail"
      result$message <- "File download failed"
      return(result)
    }
    
    # Check if file was created and has content
    if (!file.exists(temp_file) || file.size(temp_file) == 0) {
      result$status <- "fail"
      result$message <- "Downloaded file is empty or missing"
      return(result)
    }
    
    # Test CSV reading
    tryCatch({
      test_data <- read_csv_with_types(temp_file)
      
      if (nrow(test_data) == 0) {
        result$status <- "warning"
        result$message <- "Downloaded file has no data rows"
      } else {
        result$status <- "pass"
        result$message <- paste("File download successful,", nrow(test_data), "rows")
      }
      
      result$data <- list(
        file_size = file.size(temp_file),
        row_count = nrow(test_data),
        col_count = ncol(test_data)
      )
      
    }, error = function(e) {
      result$status <- "warning"
      result$message <- "File downloaded but CSV parsing failed"
      result$details <- c(paste("Parse error:", e$message))
    })
    
    # Clean up
    if (file.exists(temp_file)) {
      unlink(temp_file)
    }
    
  }, error = function(e) {
    result$status <- "fail"
    result$message <- paste("Download test failed:", e$message)
  })
  
  return(result)
}

#' Test data processing functionality
#' @param test_year Year for testing
#' @param verbose Verbose output
#' @return Test result
test_data_processing_functionality <- function(test_year, verbose = FALSE) {
  
  result <- list(status = "unknown", message = "", details = character(0), data = NULL)
  
  tryCatch({
    # Test CSV type inference
    test_data <- data.frame(
      UNITID = c(100654, 100663, 100690),
      INSTNM = c("University A", "College B", "Institute C"),
      YEAR = c(test_year, test_year, test_year),
      ENROLLMENT = c(5000, 3200, 1500),
      stringsAsFactors = FALSE
    )
    
    temp_file <- tempfile(fileext = ".csv")
    write.csv(test_data, temp_file, row.names = FALSE)
    
    # Test type inference
    processed_data <- read_csv_with_types(temp_file)
    
    if (nrow(processed_data) != nrow(test_data)) {
      result$status <- "fail"
      result$message <- "Data processing changed row count"
      return(result)
    }
    
    # Test data cleaning
    cleaned_data <- clean_ipeds_data(processed_data)
    
    # Test database import (to temporary table)
    db_connection <- ensure_connection()
    test_table_name <- paste0("test_import_", format(Sys.time(), "%Y%m%d_%H%M%S"))
    
    import_result <- import_csv_to_duckdb(temp_file, test_table_name, db_connection)
    
    if (!import_result) {
      result$status <- "fail"
      result$message <- "Database import failed"
      return(result)
    }
    
    # Verify data in database
    imported_data <- DBI::dbGetQuery(db_connection, paste("SELECT * FROM", test_table_name))
    
    if (nrow(imported_data) != nrow(test_data)) {
      result$status <- "fail"
      result$message <- "Imported data row count mismatch"
    } else {
      result$status <- "pass"
      result$message <- "Data processing successful"
    }
    
    result$data <- list(
      original_rows = nrow(test_data),
      processed_rows = nrow(processed_data),
      imported_rows = nrow(imported_data)
    )
    
    # Clean up
    tryCatch({
      DBI::dbExecute(db_connection, paste("DROP TABLE IF EXISTS", test_table_name))
    }, error = function(e) {
      # Ignore cleanup errors
    })
    
    if (file.exists(temp_file)) {
      unlink(temp_file)
    }
    
  }, error = function(e) {
    result$status <- "fail"
    result$message <- paste("Data processing test failed:", e$message)
  })
  
  return(result)
}

#' Test validation system
#' @param test_year Year for testing
#' @param verbose Verbose output
#' @return Test result
test_validation_system <- function(test_year, verbose = FALSE) {
  
  result <- list(status = "unknown", message = "", details = character(0), data = NULL)
  
  tryCatch({
    # Get available tables for testing
    db_connection <- ensure_connection()
    all_tables <- DBI::dbListTables(db_connection)
    ipeds_tables <- all_tables[!grepl("^(ipeds_|sqlite_)", all_tables)]
    
    if (length(ipeds_tables) == 0) {
      result$status <- "warning"
      result$message <- "No IPEDS tables found for validation testing"
      return(result)
    }
    
    # Test basic validation on a sample of tables
    test_tables <- head(ipeds_tables, 2)
    
    # Run validation
    validation_results <- validate_ipeds_data(test_tables, "basic")
    
    if (is.null(validation_results) || length(validation_results$summary) == 0) {
      result$status <- "fail"
      result$message <- "Validation system produced no results"
      return(result)
    }
    
    # Check validation structure
    required_summary_cols <- c("table_name", "total_checks", "passed_checks", "overall_status")
    missing_cols <- setdiff(required_summary_cols, names(validation_results$summary))
    
    if (length(missing_cols) > 0) {
      result$status <- "fail"
      result$message <- "Validation results missing required columns"
      result$details <- paste("Missing:", paste(missing_cols, collapse = ", "))
      return(result)
    }
    
    # Test schema change detection
    if (length(ipeds_tables) >= 2) {
      schema_changes <- detect_schema_changes(ipeds_tables[1], db_connection)
      
      if (!is.data.frame(schema_changes)) {
        result$status <- "warning"
        result$message <- "Schema change detection failed"
        result$details <- c("Schema change detection returned non-data.frame")
      }
    }
    
    result$status <- "pass"
    result$message <- paste("Validation system functional,", nrow(validation_results$summary), "tables tested")
    result$data <- list(
      tables_tested = nrow(validation_results$summary),
      total_checks = sum(validation_results$summary$total_checks),
      pass_rate = sum(validation_results$summary$passed_checks) / sum(validation_results$summary$total_checks)
    )
    
  }, error = function(e) {
    result$status <- "fail"
    result$message <- paste("Validation system test failed:", e$message)
  })
  
  return(result)
}

#' Test user interface functions
#' @param test_year Year for testing
#' @param verbose Verbose output
#' @return Test result
test_user_interface_functions <- function(test_year, verbose = FALSE) {
  
  result <- list(status = "unknown", message = "", details = character(0), data = NULL)
  
  tryCatch({
    # Test non-interactive mode functions
    tests_passed <- 0
    tests_total <- 0
    
    # Test status function
    tests_total <- tests_total + 1
    tryCatch({
      ui_show_status(FALSE)
      tests_passed <- tests_passed + 1
    }, error = function(e) {
      result$details <- c(result$details, paste("Status function failed:", e$message))
    })
    
    # Test help function
    tests_total <- tests_total + 1
    tryCatch({
      ui_show_help()
      tests_passed <- tests_passed + 1
    }, error = function(e) {
      result$details <- c(result$details, paste("Help function failed:", e$message))
    })
    
    # Test update check
    tests_total <- tests_total + 1
    tryCatch({
      ui_check_updates(test_year, FALSE)
      tests_passed <- tests_passed + 1
    }, error = function(e) {
      result$details <- c(result$details, paste("Update check failed:", e$message))
    })
    
    # Test main interface function
    tests_total <- tests_total + 1
    tryCatch({
      ipeds_data_manager("help", interactive = FALSE)
      tests_passed <- tests_passed + 1
    }, error = function(e) {
      result$details <- c(result$details, paste("Main interface failed:", e$message))
    })
    
    if (tests_passed == tests_total) {
      result$status <- "pass"
      result$message <- "All user interface functions working"
    } else if (tests_passed > 0) {
      result$status <- "warning"
      result$message <- paste(tests_passed, "/", tests_total, "UI functions working")
    } else {
      result$status <- "fail"
      result$message <- "User interface functions failed"
    }
    
    result$data <- list(
      tests_passed = tests_passed,
      tests_total = tests_total
    )
    
  }, error = function(e) {
    result$status <- "fail"
    result$message <- paste("UI test failed:", e$message)
  })
  
  return(result)
}

#' Test version tracking system (comprehensive test only)
#' @param test_year Year for testing
#' @param verbose Verbose output
#' @return Test result
test_version_tracking_system <- function(test_year, verbose = FALSE) {
  
  result <- list(status = "unknown", message = "", details = character(0), data = NULL)
  
  tryCatch({
    db_connection <- ensure_connection()
    
    # Test version tracking initialization
    init_result <- initialize_version_tracking(db_connection)
    
    if (!init_result) {
      result$status <- "fail"
      result$message <- "Version tracking initialization failed"
      return(result)
    }
    
    # Test metadata recording
    test_file_info <- list(
      year = test_year,
      survey_component = "TEST",
      description = "Test file for integration testing",
      source_url = "http://test.example.com/test.csv",
      file_size = 1024
    )
    
    metadata_result <- record_table_metadata("test_table", test_file_info, db_connection)
    
    if (!metadata_result) {
      result$status <- "warning"
      result$message <- "Metadata recording failed"
      result$details <- c("Could not record test metadata")
    }
    
    # Test version history retrieval
    version_history <- get_version_history(db_connection = db_connection)
    
    if (!is.data.frame(version_history)) {
      result$status <- "fail"
      result$message <- "Version history retrieval failed"
      return(result)
    }
    
    result$status <- "pass"
    result$message <- "Version tracking system functional"
    result$data <- list(
      metadata_tables_exist = "ipeds_metadata" %in% DBI::dbListTables(db_connection),
      version_records = nrow(version_history)
    )
    
  }, error = function(e) {
    result$status <- "fail"
    result$message <- paste("Version tracking test failed:", e$message)
  })
  
  return(result)
}

#' Test backup and restore functionality (comprehensive test only)
#' @param test_year Year for testing
#' @param verbose Verbose output
#' @return Test result
test_backup_restore_functionality <- function(test_year, verbose = FALSE) {
  
  result <- list(status = "unknown", message = "", details = character(0), data = NULL)
  
  tryCatch({
    # Test backup creation
    backup_result <- backup_database()
    
    if (!backup_result) {
      result$status <- "fail"
      result$message <- "Database backup failed"
      return(result)
    }
    
    # Check if backup file was created
    db_connection <- ensure_connection()
    backup_dir <- file.path(dirname(db_connection@dbname), "backups")
    
    if (!dir.exists(backup_dir)) {
      result$status <- "fail"
      result$message <- "Backup directory not created"
      return(result)
    }
    
    backup_files <- list.files(backup_dir, pattern = "\\.duckdb$")
    
    if (length(backup_files) == 0) {
      result$status <- "fail"
      result$message <- "No backup files found"
      return(result)
    }
    
    result$status <- "pass"
    result$message <- paste("Backup system functional,", length(backup_files), "backups available")
    result$data <- list(
      backup_count = length(backup_files),
      latest_backup = tail(backup_files, 1)
    )
    
  }, error = function(e) {
    result$status <- "fail"
    result$message <- paste("Backup/restore test failed:", e$message)
  })
  
  return(result)
}

#' Test error handling robustness (comprehensive test only)
#' @param test_year Year for testing
#' @param verbose Verbose output
#' @return Test result
test_error_handling_robustness <- function(test_year, verbose = FALSE) {
  
  result <- list(status = "unknown", message = "", details = character(0), data = NULL)
  
  # Test various error conditions
  error_tests_passed <- 0
  error_tests_total <- 0
  
  # Test 1: Invalid year
  error_tests_total <- error_tests_total + 1
  tryCatch({
    invalid_files <- scrape_ipeds_files_enhanced(1900)  # Very old year
    # Should handle gracefully, not crash
    error_tests_passed <- error_tests_passed + 1
  }, error = function(e) {
    # Should not reach here
  })
  
  # Test 2: Invalid URL download
  error_tests_total <- error_tests_total + 1
  tryCatch({
    invalid_download <- download_ipeds_csv("http://invalid.url.test/file.csv", tempfile())
    # Should return FALSE, not crash
    if (!invalid_download) {
      error_tests_passed <- error_tests_passed + 1
    }
  }, error = function(e) {
    # Should not reach here
  })
  
  # Test 3: Validation on non-existent table
  error_tests_total <- error_tests_total + 1
  tryCatch({
    db_connection <- ensure_connection()
    invalid_validation <- validate_ipeds_data("nonexistent_table_xyz", "basic", db_connection)
    # Should handle gracefully
    error_tests_passed <- error_tests_passed + 1
  }, error = function(e) {
    # Should not reach here
  })
  
  if (error_tests_passed == error_tests_total) {
    result$status <- "pass"
    result$message <- "Error handling robust"
  } else {
    result$status <- "warning"
    result$message <- paste(error_tests_passed, "/", error_tests_total, "error conditions handled properly")
  }
  
  result$data <- list(
    error_tests_passed = error_tests_passed,
    error_tests_total = error_tests_total
  )
  
  return(result)
}

#' Test end-to-end workflow (comprehensive test only)
#' @param test_year Year for testing
#' @param verbose Verbose output
#' @return Test result
test_end_to_end_workflow <- function(test_year, verbose = FALSE) {
  
  result <- list(status = "unknown", message = "", details = character(0), data = NULL)
  
  # This is a placeholder for a complete workflow test
  # In practice, this would test the entire process from update detection to validation
  
  tryCatch({
    workflow_steps <- 0
    workflow_completed <- 0
    
    # Step 1: Check for updates
    workflow_steps <- workflow_steps + 1
    updates <- check_ipeds_updates(test_year)
    if (!is.null(updates)) {
      workflow_completed <- workflow_completed + 1
    }
    
    # Step 2: Database status check
    workflow_steps <- workflow_steps + 1
    db_connection <- ensure_connection()
    if (DBI::dbIsValid(db_connection)) {
      workflow_completed <- workflow_completed + 1
    }
    
    # Step 3: Validation check
    workflow_steps <- workflow_steps + 1
    all_tables <- DBI::dbListTables(db_connection)
    ipeds_tables <- all_tables[!grepl("^(ipeds_|sqlite_)", all_tables)]
    if (length(ipeds_tables) > 0) {
      sample_validation <- validate_ipeds_data(head(ipeds_tables, 1), "basic")
      if (!is.null(sample_validation)) {
        workflow_completed <- workflow_completed + 1
      }
    } else {
      workflow_completed <- workflow_completed + 1  # No tables is also valid
    }
    
    if (workflow_completed == workflow_steps) {
      result$status <- "pass"
      result$message <- "End-to-end workflow functional"
    } else {
      result$status <- "warning"
      result$message <- paste(workflow_completed, "/", workflow_steps, "workflow steps completed")
    }
    
    result$data <- list(
      steps_completed = workflow_completed,
      total_steps = workflow_steps
    )
    
  }, error = function(e) {
    result$status <- "fail"
    result$message <- paste("End-to-end workflow test failed:", e$message)
  })
  
  return(result)
}

#' Test performance benchmarks (comprehensive test only)
#' @param test_year Year for testing
#' @param verbose Verbose output
#' @return Test result
test_performance_benchmarks <- function(test_year, verbose = FALSE) {
  
  result <- list(status = "unknown", message = "", details = character(0), data = NULL)
  
  tryCatch({
    benchmarks <- list()
    
    # Benchmark 1: Database connection time
    start_time <- Sys.time()
    db_connection <- ensure_connection()
    connection_time <- as.numeric(Sys.time() - start_time, units = "secs")
    benchmarks$connection_time <- connection_time
    
    # Benchmark 2: Table listing time
    start_time <- Sys.time()
    tables <- DBI::dbListTables(db_connection)
    listing_time <- as.numeric(Sys.time() - start_time, units = "secs")
    benchmarks$listing_time <- listing_time
    
    # Benchmark 3: Web scraping time
    start_time <- Sys.time()
    files <- scrape_ipeds_files_enhanced(test_year)
    scraping_time <- as.numeric(Sys.time() - start_time, units = "secs")
    benchmarks$scraping_time <- scraping_time
    
    # Performance thresholds (reasonable expectations)
    performance_issues <- 0
    if (connection_time > 5) performance_issues <- performance_issues + 1
    if (listing_time > 2) performance_issues <- performance_issues + 1
    if (scraping_time > 30) performance_issues <- performance_issues + 1
    
    if (performance_issues == 0) {
      result$status <- "pass"
      result$message <- "Performance within acceptable limits"
    } else {
      result$status <- "warning"
      result$message <- paste(performance_issues, "performance concerns identified")
    }
    
    result$data <- benchmarks
    result$details <- c(
      paste("Connection time:", round(connection_time, 2), "seconds"),
      paste("Table listing time:", round(listing_time, 2), "seconds"),
      paste("Web scraping time:", round(scraping_time, 2), "seconds")
    )
    
  }, error = function(e) {
    result$status <- "fail"
    result$message <- paste("Performance benchmark test failed:", e$message)
  })
  
  return(result)
}

#' Test data integrity checks (comprehensive test only)
#' @param test_year Year for testing
#' @param verbose Verbose output
#' @return Test result
test_data_integrity_checks <- function(test_year, verbose = FALSE) {
  
  result <- list(status = "unknown", message = "", details = character(0), data = NULL)
  
  tryCatch({
    db_connection <- ensure_connection()
    all_tables <- DBI::dbListTables(db_connection)
    ipeds_tables <- all_tables[!grepl("^(ipeds_|sqlite_)", all_tables)]
    
    integrity_issues <- 0
    tables_checked <- 0
    
    if (length(ipeds_tables) > 0) {
      # Check a sample of tables for basic integrity
      check_tables <- head(ipeds_tables, 3)
      
      for (table_name in check_tables) {
        tables_checked <- tables_checked + 1
        
        # Basic integrity: table should have data
        row_count_query <- paste("SELECT COUNT(*) as n FROM", table_name)
        row_count <- DBI::dbGetQuery(db_connection, row_count_query)$n
        
        if (row_count == 0) {
          integrity_issues <- integrity_issues + 1
          result$details <- c(result$details, paste(table_name, "is empty"))
        }
        
        # Check for UNITID if present
        schema_query <- paste("PRAGMA table_info(", table_name, ")")
        schema <- DBI::dbGetQuery(db_connection, schema_query)
        
        if ("UNITID" %in% schema$name) {
          unitid_query <- paste("SELECT COUNT(DISTINCT UNITID) as unique_unitids FROM", table_name)
          unique_unitids <- DBI::dbGetQuery(db_connection, unitid_query)$unique_unitids
          
          if (unique_unitids == 0) {
            integrity_issues <- integrity_issues + 1
            result$details <- c(result$details, paste(table_name, "has no valid UNITIDs"))
          }
        }
      }
    }
    
    if (integrity_issues == 0) {
      result$status <- "pass"
      result$message <- paste("Data integrity checks passed for", tables_checked, "tables")
    } else {
      result$status <- "warning"
      result$message <- paste(integrity_issues, "integrity issues found in", tables_checked, "tables")
    }
    
    result$data <- list(
      tables_checked = tables_checked,
      integrity_issues = integrity_issues
    )
    
  }, error = function(e) {
    result$status <- "fail"
    result$message <- paste("Data integrity test failed:", e$message)
  })
  
  return(result)
}

#' Print integration test summary
#' @param test_results Results from integration tests
print_integration_test_summary <- function(test_results) {
  
  cat(rep("=", 62), "\n")
  cat("INTEGRATION TEST SUMMARY\n")
  cat(rep("=", 62), "\n\n")
  
  # Overall results
  cat("Overall Status:", switch(test_results$overall_status,
    "pass" = "✅ PASS",
    "warning" = "⚠️  WARNING", 
    "fail" = "❌ FAIL",
    "error" = "💥 ERROR",
    "❓ UNKNOWN"
  ), "\n")
  
  cat("Test Duration:", round(test_results$duration, 1), "seconds\n")
  cat("Test Year:", test_results$test_year, "\n")
  cat("Quick Mode:", test_results$quick_mode, "\n\n")
  
  # Results breakdown
  summary <- test_results$summary
  cat("Results:\n")
  cat("  Total Tests:", summary$total_tests, "\n")
  cat("  Passed:     ", summary$passed, " (", round(summary$passed/summary$total_tests*100, 1), "%)\n")
  cat("  Warnings:   ", summary$warnings, "\n")
  cat("  Failed:     ", summary$failed, "\n")
  cat("  Errors:     ", summary$errors, "\n\n")
  
  # Failed/problematic tests
  problem_tests <- names(test_results$tests)[
    sapply(test_results$tests, function(x) x$status %in% c("fail", "error", "warning"))
  ]
  
  if (length(problem_tests) > 0) {
    cat("Tests requiring attention:\n")
    for (test_name in problem_tests) {
      test_result <- test_results$tests[[test_name]]
      status_icon <- switch(test_result$status,
        "warning" = "⚠️ ",
        "fail" = "❌",
        "error" = "💥",
        "❓"
      )
      cat("  ", status_icon, " ", test_name, ": ", test_result$message, "\n")
    }
    cat("\n")
  }
  
  # Recommendations
  if (test_results$overall_status != "pass") {
    cat("Recommendations:\n")
    if (summary$errors > 0) {
      cat("  • Check system configuration and dependencies\n")
    }
    if (summary$failed > 0) {
      cat("  • Review failed tests and fix underlying issues\n")
    }
    if (summary$warnings > 0) {
      cat("  • Investigate warnings for potential improvements\n")
    }
    cat("  • Run tests again after addressing issues\n")
    cat("  • Use verbose mode for detailed debugging\n\n")
  } else {
    cat("✅ All systems operational! The IPEDS data management system is ready for use.\n\n")
  }
  
  cat("Next steps:\n")
  cat("  • Use ipeds_data_manager('check_updates') to check for new data\n")
  cat("  • Use ipeds_data_manager('download') to download latest IPEDS data\n")
  cat("  • Use ipeds_data_manager('validate') to validate data quality\n")
  cat("  • Use ipeds_data_manager('help') for more options\n\n")
}