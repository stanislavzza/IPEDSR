#' IPEDS Data Management User Interface System
#' 
#' User-friendly functions for managing IPEDS data updates and validation

#' Get actual years available in the database
#' @return Vector of years found in database table names
#' @export
get_database_years <- function() {
  tryCatch({
    # Use existing connection infrastructure
    db_connection <- ensure_connection()
    
    # Get all table names
    tables <- DBI::dbListTables(db_connection)
    
    # Extract years from table names (simpler approach)
    years <- character()
    for (table in tables) {
      # Look for 4-digit numbers that could be years
      year_matches <- regmatches(table, gregexpr("[0-9]{4}", table))[[1]]
      if (length(year_matches) > 0) {
        # Filter to reasonable year range
        for (year_str in year_matches) {
          year_num <- as.numeric(year_str)
          if (!is.na(year_num) && year_num >= 2000 && year_num <= 2030) {
            years <- c(years, year_str)
          }
        }
      }
    }
    
    # Convert to numeric, remove duplicates, sort
    years <- as.numeric(unique(years))
    years <- sort(years)
    
    return(years)
    
  }, error = function(e) {
    warning("Error getting database years: ", e$message)
    return(integer(0))
  })
}

#' Main interface for IPEDS data management
#' @param action Action to perform: "check_updates", "download", "validate", "status", "help"
#' @param year Specific year to work with (optional)
#' @param tables Specific tables to work with (optional)
#' @param validation_level Level of validation: "basic", "standard", "comprehensive"
#' @param interactive Whether to use interactive prompts
#' @return Results based on action performed
#' @export
ipeds_data_manager <- function(action = "help", year = NULL, tables = NULL, 
                              validation_level = "standard", interactive = TRUE) {
  
  # Print header
  cat("\n")
  cat("=" , rep("=", 30), "=", "\n")
  cat("IPEDS DATA MANAGEMENT SYSTEM\n")
  cat("=" , rep("=", 30), "=", "\n\n")
  
  # Route to appropriate function based on action
  result <- switch(action,
    "check_updates" = ui_check_updates(year, interactive),
    "download" = ui_download_data(year, tables, interactive),
    "validate" = ui_validate_data(tables, validation_level, interactive),
    "status" = ui_show_status(interactive),
    "backup" = ui_backup_database(interactive),
    "restore" = ui_restore_database(interactive),
    "help" = ui_show_help(),
    {
      cat("Unknown action:", action, "\n")
      cat("Use action = 'help' to see available options.\n")
      return(invisible(NULL))
    }
  )
  
  return(invisible(result))
}

#' Check for available updates
#' @param year Specific year to check (optional)
#' @param interactive Whether to use interactive prompts
ui_check_updates <- function(year = NULL, interactive = TRUE) {
  
  cat("Checking for IPEDS data updates...\n\n")
  
  tryCatch({
    # Check for updates
    updates <- check_ipeds_updates(year)
    
    if (length(updates) == 0) {
      cat("✅ No updates found. Your database appears to be current.\n")
      return(invisible(NULL))
    }
    
    cat("🔄 Found", length(updates), "potential updates:\n\n")
    
    # Display updates in a nice format
    for (i in seq_along(updates)) {
      update <- updates[[i]]
      cat("", i, ". ", update$title, "\n")
      cat("     Year:", update$year, "\n")
      cat("     Survey:", update$survey_component, "\n")
      cat("     Files:", length(update$files), "\n")
      if (!is.null(update$description)) {
        cat("     Description:", substr(update$description, 1, 80), "...\n")
      }
      cat("\n")
    }
    
    if (interactive) {
      response <- readline("Would you like to download these updates? (y/n): ")
      if (tolower(substr(response, 1, 1)) == "y") {
        cat("\nStarting download process...\n")
        return(ui_download_data(year, NULL, FALSE))
      }
    }
    
    return(invisible(updates))
    
  }, error = function(e) {
    cat("❌ Error checking for updates:", e$message, "\n")
    return(invisible(NULL))
  })
}

#' Download and process IPEDS data
#' @param year Specific year to download (optional)
#' @param tables Specific tables to download (optional)
#' @param interactive Whether to use interactive prompts
ui_download_data <- function(year = NULL, tables = NULL, interactive = TRUE) {
  
  if (is.null(year)) {
    current_year <- as.numeric(format(Sys.Date(), "%Y"))
    year <- current_year - 1  # Default to previous year
    
    if (interactive) {
      cat("No year specified. Default is", year, "\n")
      response <- readline(paste("Press Enter to continue with", year, "or type a different year: "))
      if (response != "") {
        year <- as.numeric(response)
        if (is.na(year) || year < 1980 || year > current_year) {
          cat("❌ Invalid year. Using default:", year, "\n")
          year <- current_year - 1
        }
      }
    }
  }
  
  cat("📥 Starting download for year", year, "\n\n")
  
  tryCatch({
    # Create backup before major update
    if (interactive) {
      cat("Creating backup before download...\n")
      backup_result <- backup_database()
      if (backup_result) {
        cat("✅ Backup created successfully\n\n")
      } else {
        cat("⚠️  Backup failed, but continuing...\n\n")
      }
    }
    
    # Get available files for the year
    cat("Fetching available files for", year, "...\n")
    available_files <- scrape_ipeds_files_enhanced(year)
    
    if (length(available_files) == 0) {
      cat("❌ No files found for year", year, "\n")
      return(invisible(NULL))
    }
    
    cat("Found", length(available_files), "available files\n\n")
    
    # Filter tables if specified
    if (!is.null(tables)) {
      if (interactive) {
        cat("Filtering for specific tables:", paste(tables, collapse = ", "), "\n")
      }
      available_files <- available_files[grepl(paste(tables, collapse = "|"), names(available_files))]
    }
    
    if (length(available_files) == 0) {
      cat("❌ No files found matching specified tables\n")
      return(invisible(NULL))
    }
    
    # Show download plan
    if (interactive) {
      cat("Download plan:\n")
      for (i in seq_along(available_files)) {
        file_info <- available_files[[i]]
        cat("  ", i, ". ", file_info$title, " (", file_info$survey_component, ")\n")
      }
      cat("\n")
      
      response <- readline("Proceed with download? (y/n): ")
      if (tolower(substr(response, 1, 1)) != "y") {
        cat("Download cancelled.\n")
        return(invisible(NULL))
      }
    }
    
    # Execute download
    cat("\n🚀 Starting bulk download...\n\n")
    results <- batch_download_ipeds_files(available_files)
    
    # Update database
    cat("\n📊 Updating database...\n")
    db_result <- update_ipeds_database_year(year)
    
    # Show summary
    cat("\n" , rep("=", 50), "\n")
    cat("DOWNLOAD SUMMARY\n")
    cat(rep("=", 50), "\n")
    cat("Year:", year, "\n")
    cat("Files processed:", length(results$success), "/", length(available_files), "\n")
    cat("Database updated:", ifelse(db_result, "✅ Yes", "❌ Failed"), "\n")
    
    if (length(results$failed) > 0) {
      cat("\nFailed downloads:\n")
      for (failure in results$failed) {
        cat("  ❌", failure, "\n")
      }
    }
    
    cat("\n")
    return(invisible(results))
    
  }, error = function(e) {
    cat("❌ Download failed:", e$message, "\n")
    return(invisible(NULL))
  })
}

#' Validate IPEDS data quality
#' @param tables Specific tables to validate (optional)
#' @param validation_level Level of validation
#' @param interactive Whether to use interactive prompts
ui_validate_data <- function(tables = NULL, validation_level = "standard", interactive = TRUE) {
  
  cat("🔍 Starting data validation...\n")
  cat("Validation level:", validation_level, "\n\n")
  
  if (interactive && is.null(tables)) {
    response <- readline("Validate all tables? (y) or specify tables (t) or cancel (n): ")
    if (tolower(substr(response, 1, 1)) == "n") {
      cat("Validation cancelled.\n")
      return(invisible(NULL))
    } else if (tolower(substr(response, 1, 1)) == "t") {
      # Get available tables
      db_connection <- ensure_connection()
      all_tables <- DBI::dbListTables(db_connection)
      ipeds_tables <- all_tables[!grepl("^(ipeds_|sqlite_)", all_tables)]
      
      cat("Available tables:\n")
      for (i in seq_along(ipeds_tables)) {
        cat("  ", i, ". ", ipeds_tables[i], "\n")
      }
      
      table_selection <- readline("Enter table numbers (comma-separated) or table names: ")
      if (grepl("^[0-9,\\s]+$", table_selection)) {
        # Numeric selection
        indices <- as.numeric(unlist(strsplit(gsub("\\s", "", table_selection), ",")))
        indices <- indices[!is.na(indices) & indices <= length(ipeds_tables)]
        tables <- ipeds_tables[indices]
      } else {
        # Text selection
        tables <- unlist(strsplit(gsub("\\s", "", table_selection), ","))
      }
      
      cat("Selected tables:", paste(tables, collapse = ", "), "\n\n")
    }
  }
  
  tryCatch({
    # Run validation
    results <- validate_ipeds_data(tables, validation_level)
    
    # Show detailed results if requested
    if (interactive) {
      response <- readline("\nView detailed results for problematic tables? (y/n): ")
      if (tolower(substr(response, 1, 1)) == "y") {
        show_detailed_validation_results(results)
      }
      
      # Offer to run recommendations
      if (length(results$recommendations) > 0) {
        cat("\n📋 RECOMMENDATIONS:\n")
        for (i in seq_along(results$recommendations)) {
          cat("", i, ". ", results$recommendations[i], "\n")
        }
        cat("\n")
      }
    }
    
    return(invisible(results))
    
  }, error = function(e) {
    cat("❌ Validation failed:", e$message, "\n")
    return(invisible(NULL))
  })
}

#' Show database status and summary
#' @param interactive Whether to use interactive prompts
ui_show_status <- function(interactive = TRUE) {
  
  cat("📊 IPEDS Database Status\n\n")
  
  tryCatch({
    db_connection <- ensure_connection()
    
    # Get basic database info
    all_tables <- DBI::dbListTables(db_connection)
    ipeds_tables <- all_tables[!grepl("^(ipeds_|sqlite_)", all_tables)]
    metadata_tables <- all_tables[grepl("^ipeds_", all_tables)]
    
    cat("Database Tables:\n")
    cat("  IPEDS data tables:", length(ipeds_tables), "\n")
    cat("  Metadata tables:", length(metadata_tables), "\n")
    cat("  Total tables:", length(all_tables), "\n\n")
    
    # Get ACTUAL years from database
    actual_years <- get_database_years()
    if (length(actual_years) > 0) {
      cat("Data Years Available:\n")
      cat("  Years:", paste(actual_years, collapse = ", "), "\n")
      cat("  Range:", min(actual_years), "-", max(actual_years), "\n")
      cat("  Total years:", length(actual_years), "\n\n")
      
      # Count tables per year
      cat("Tables per Year:\n")
      for (year in tail(actual_years, 5)) {  # Show last 5 years
        year_tables <- ipeds_tables[grepl(as.character(year), ipeds_tables)]
        cat("  ", year, ": ", length(year_tables), " tables\n")
      }
      cat("\n")
    } else {
      cat("⚠️  Could not determine available data years\n\n")
    }
    
    # Get version information if available
    if ("ipeds_metadata" %in% all_tables) {
      version_info <- get_version_history()
      if (nrow(version_info) > 0) {
        cat("Version Tracking:\n")
        
        # Show latest updates by year
        years <- unique(version_info$data_year)
        years <- years[order(years, decreasing = TRUE)]
        
        for (year in head(years, 5)) {
          year_data <- version_info[version_info$data_year == year, ]
          latest_update <- max(year_data$download_date, na.rm = TRUE)
          table_count <- nrow(year_data)
          
          cat("  ", year, ": ", table_count, " tables (last updated: ", 
              substr(latest_update, 1, 10), ")\n")
        }
        cat("\n")
      }
    } else {
      cat("Version Tracking: Not initialized\n\n")
    }
    
    # Database file info - use safer approach
    tryCatch({
      library(rappdirs)
      db_dir <- user_data_dir("IPEDSR")
      db_files <- list.files(db_dir, pattern = "\\.duckdb$", full.names = TRUE)
      
      if (length(db_files) > 0) {
        db_path <- db_files[1]
        file_info <- file.info(db_path)
        file_size_mb <- round(file_info$size / 1024 / 1024, 1)
        cat("Database File:\n")
        cat("  Path:", db_path, "\n")
        cat("  Size:", file_size_mb, "MB\n")
        cat("  Modified:", format(file_info$mtime, "%Y-%m-%d %H:%M:%S"), "\n\n")
      }
    }, error = function(e) {
      cat("Database file info not available\n\n")
    })
    
    # Quick data quality check
    if (interactive) {
      response <- readline("Run quick data quality check? (y/n): ")
      if (tolower(substr(response, 1, 1)) == "y") {
        cat("\n🔍 Running quick quality check...\n")
        sample_tables <- head(ipeds_tables, 3)
        quick_results <- validate_ipeds_data(sample_tables, "basic")
        cat("Quick check complete. Use validation_level = 'comprehensive' for full analysis.\n")
      }
    }
    
  }, error = function(e) {
    cat("❌ Error getting status:", e$message, "\n")
  })
  
  return(invisible(NULL))
}

#' Backup database
#' @param interactive Whether to use interactive prompts
ui_backup_database <- function(interactive = TRUE) {
  
  cat("💾 Database Backup\n\n")
  
  if (interactive) {
    response <- readline("Create backup of current database? (y/n): ")
    if (tolower(substr(response, 1, 1)) != "y") {
      cat("Backup cancelled.\n")
      return(invisible(FALSE))
    }
  }
  
  tryCatch({
    result <- backup_database()
    
    if (result) {
      cat("✅ Backup created successfully\n")
      
      # Show backup location
      db_connection <- ensure_connection()
      backup_dir <- file.path(dirname(db_connection@dbname), "backups")
      if (dir.exists(backup_dir)) {
        backups <- list.files(backup_dir, pattern = "\\.duckdb$", full.names = TRUE)
        if (length(backups) > 0) {
          latest_backup <- backups[which.max(file.mtime(backups))]
          cat("Latest backup:", basename(latest_backup), "\n")
          cat("Location:", backup_dir, "\n")
        }
      }
    } else {
      cat("❌ Backup failed\n")
    }
    
    return(invisible(result))
    
  }, error = function(e) {
    cat("❌ Backup error:", e$message, "\n")
    return(invisible(FALSE))
  })
}

#' Restore database from backup
#' @param interactive Whether to use interactive prompts
ui_restore_database <- function(interactive = TRUE) {
  
  cat("🔄 Database Restore\n\n")
  
  # List available backups
  db_connection <- ensure_connection()
  backup_dir <- file.path(dirname(db_connection@dbname), "backups")
  
  if (!dir.exists(backup_dir)) {
    cat("❌ No backup directory found\n")
    return(invisible(FALSE))
  }
  
  backups <- list.files(backup_dir, pattern = "\\.duckdb$", full.names = TRUE)
  
  if (length(backups) == 0) {
    cat("❌ No backup files found\n")
    return(invisible(FALSE))
  }
  
  # Show available backups
  cat("Available backups:\n")
  backup_info <- data.frame(
    file = basename(backups),
    date = format(file.mtime(backups), "%Y-%m-%d %H:%M:%S"),
    size_mb = round(file.size(backups) / 1024 / 1024, 1),
    stringsAsFactors = FALSE
  )
  
  for (i in seq_len(nrow(backup_info))) {
    cat("  ", i, ". ", backup_info$file[i], " (", backup_info$date[i], ", ", 
        backup_info$size_mb[i], " MB)\n")
  }
  
  if (!interactive) {
    cat("Use interactive mode to select backup for restore.\n")
    return(invisible(FALSE))
  }
  
  # Get user selection
  selection <- readline("\nEnter backup number to restore (or 'c' to cancel): ")
  
  if (tolower(selection) == "c") {
    cat("Restore cancelled.\n")
    return(invisible(FALSE))
  }
  
  backup_index <- as.numeric(selection)
  if (is.na(backup_index) || backup_index < 1 || backup_index > length(backups)) {
    cat("❌ Invalid selection\n")
    return(invisible(FALSE))
  }
  
  selected_backup <- backups[backup_index]
  
  # Confirm restore
  cat("\n⚠️  WARNING: This will replace your current database!\n")
  cat("Selected backup:", basename(selected_backup), "\n")
  confirmation <- readline("Type 'RESTORE' to confirm: ")
  
  if (confirmation != "RESTORE") {
    cat("Restore cancelled.\n")
    return(invisible(FALSE))
  }
  
  tryCatch({
    result <- restore_database_backup(selected_backup, FALSE)  # Use the function from data_updates.R
    
    if (result) {
      cat("✅ Database restored successfully\n")
    } else {
      cat("❌ Restore failed\n")
    }
    
    return(invisible(result))
    
  }, error = function(e) {
    cat("❌ Restore error:", e$message, "\n")
    return(invisible(FALSE))
  })
}

#' Show help information
ui_show_help <- function() {
  
  cat("📖 IPEDS Data Manager Help\n\n")
  
  cat("Available Actions:\n\n")
  
  cat("🔄 check_updates   - Check for new IPEDS data releases\n")
  cat("   Examples:\n")
  cat("     ipeds_data_manager('check_updates')\n")
  cat("     ipeds_data_manager('check_updates', year = 2023)\n\n")
  
  cat("📥 download        - Download and process IPEDS data\n")
  cat("   Examples:\n")
  cat("     ipeds_data_manager('download')\n")
  cat("     ipeds_data_manager('download', year = 2023)\n")
  cat("     ipeds_data_manager('download', year = 2023, tables = c('HD', 'IC'))\n\n")
  
  cat("🔍 validate        - Validate data quality and integrity\n")
  cat("   Examples:\n")
  cat("     ipeds_data_manager('validate')\n")
  cat("     ipeds_data_manager('validate', validation_level = 'comprehensive')\n")
  cat("     ipeds_data_manager('validate', tables = c('HD2023', 'IC2023'))\n\n")
  
  cat("📊 status          - Show database status and summary\n")
  cat("   Example:\n")
  cat("     ipeds_data_manager('status')\n\n")
  
  cat("💾 backup          - Create database backup\n")
  cat("   Example:\n")
  cat("     ipeds_data_manager('backup')\n\n")
  
  cat("🔄 restore         - Restore database from backup\n")
  cat("   Example:\n")
  cat("     ipeds_data_manager('restore')\n\n")
  
  cat("Parameters:\n")
  cat("  year             - Specific year (e.g., 2023)\n")
  cat("  tables           - Vector of table names (e.g., c('HD', 'IC'))\n")
  cat("  validation_level - 'basic', 'standard', or 'comprehensive'\n")
  cat("  interactive      - TRUE/FALSE for interactive prompts\n\n")
  
  cat("Quick Start:\n")
  cat("  1. Check for updates: ipeds_data_manager('check_updates')\n")
  cat("  2. Download data:     ipeds_data_manager('download')\n")
  cat("  3. Validate data:     ipeds_data_manager('validate')\n")
  cat("  4. Check status:      ipeds_data_manager('status')\n\n")
  
  return(invisible(NULL))
}

#' Show detailed validation results for problematic tables
#' @param validation_results Results from validation
show_detailed_validation_results <- function(validation_results) {
  
  summary <- validation_results$summary
  problem_tables <- summary[summary$overall_status %in% c("fail", "error", "warning"), ]
  
  if (nrow(problem_tables) == 0) {
    cat("✅ No problematic tables found!\n")
    return(invisible(NULL))
  }
  
  cat("\n📋 DETAILED VALIDATION RESULTS\n")
  cat(rep("=", 50), "\n\n")
  
  for (i in seq_len(nrow(problem_tables))) {
    table_name <- problem_tables$table_name[i]
    table_details <- validation_results$detailed_results[[table_name]]
    
    cat("Table:", table_name, "(", problem_tables$overall_status[i], ")\n")
    cat(rep("-", 30), "\n")
    
    # Show failed and warning checks
    problem_checks <- table_details$checks[table_details$checks$status %in% c("fail", "error", "warning"), ]
    
    if (nrow(problem_checks) > 0) {
      for (j in seq_len(nrow(problem_checks))) {
        check <- problem_checks[j, ]
        icon <- switch(check$status,
          "fail" = "❌",
          "error" = "💥",
          "warning" = "⚠️",
          "ℹ️"
        )
        
        cat("  ", icon, " ", check$check_name, ": ", check$message, "\n")
        if (check$details != "") {
          cat("      Details: ", check$details, "\n")
        }
      }
    }
    
    cat("\n")
  }
}

#' Quick data update workflow
#' @param year Year to update (optional)
#' @param validate Whether to run validation after update
#' @export
quick_update <- function(year = NULL, validate = TRUE) {
  
  cat("🚀 Quick IPEDS Data Update\n\n")
  
  # Check for updates
  cat("Step 1: Checking for updates...\n")
  updates <- ui_check_updates(year, FALSE)
  
  if (length(updates) == 0) {
    cat("No updates available.\n")
    return(invisible(NULL))
  }
  
  # Download updates
  cat("\nStep 2: Downloading updates...\n")
  download_results <- ui_download_data(year, NULL, FALSE)
  
  # Validate if requested
  if (validate) {
    cat("\nStep 3: Validating data...\n")
    validation_results <- ui_validate_data(NULL, "standard", FALSE)
  }
  
  cat("\n✅ Quick update complete!\n")
  
  return(invisible(list(
    updates = updates,
    download_results = download_results,
    validation_results = if (validate) validation_results else NULL
  )))
}