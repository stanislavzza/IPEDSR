#' Enhanced IPEDS Web Scraping Functions
#' 
#' Advanced functions for parsing IPEDS data files from the NCES website

#' Scrape IPEDS data files with robust HTML parsing
#' @param year The year to scrape data for
#' @param verbose Whether to print progress messages
#' @return A data frame with detailed file information
scrape_ipeds_files_enhanced <- function(year, verbose = FALSE) {
  
  url <- paste0("https://nces.ed.gov/ipeds/datacenter/DataFiles.aspx?year=", year)
  
  if (verbose) {
    message("Fetching IPEDS data files for ", year, " from: ", url)
  }
  
  tryCatch({
    # Read the webpage
    page <- rvest::read_html(url)
    
    # Find the data files table - this may need adjustment based on actual HTML structure
    # The table typically contains columns for: Year, Survey Component, Description, File Name, etc.
    
    # Look for table rows that contain data file information
    rows <- rvest::html_elements(page, "tr")
    
    # Extract file information from each row
    files_data <- extract_file_info_from_rows(rows, year, verbose)
    
    if (verbose && nrow(files_data) > 0) {
      message("Found ", nrow(files_data), " data files for ", year)
    }
    
    return(files_data)
    
  }, error = function(e) {
    warning("Error scraping IPEDS files for year ", year, ": ", e$message)
    return(create_empty_files_dataframe())
  })
}

#' Extract file information from HTML table rows
#' @param rows HTML elements representing table rows
#' @param year The year being processed
#' @param verbose Whether to print progress
#' @return Data frame with file information
extract_file_info_from_rows <- function(rows, year, verbose) {
  
  files_data <- create_empty_files_dataframe()
  
  for (i in seq_along(rows)) {
    row <- rows[[i]]
    
    # Extract text from all cells in this row
    cells <- rvest::html_elements(row, "td")
    
    if (length(cells) == 0) next
    
    cell_texts <- rvest::html_text(cells, trim = TRUE)
    
    # Look for rows that contain year information and file links
    if (length(cell_texts) >= 6 && any(grepl(as.character(year), cell_texts))) {
      
      # Parse the row to extract file information
      file_info <- parse_file_row(cells, cell_texts, year)
      
      if (!is.null(file_info)) {
        files_data <- rbind(files_data, file_info)
      }
    }
  }
  
  return(files_data)
}

#' Parse individual table row for file information
#' @param cells HTML cell elements
#' @param cell_texts Text content of cells
#' @param year The year being processed
#' @return Single row data frame or NULL
parse_file_row <- function(cells, cell_texts, year) {
  
  # This is a simplified parser - the actual implementation would need
  # to be adjusted based on the exact HTML structure of the IPEDS page
  
  # Typical IPEDS table structure might be:
  # Year | Survey Component | Description | CSV File | Other Formats | Dictionary
  
  if (length(cell_texts) < 4) return(NULL)
  
  # Extract survey component and description
  survey_component <- if (length(cell_texts) >= 2) cell_texts[2] else ""
  description <- if (length(cell_texts) >= 3) cell_texts[3] else ""
  
  # Look for CSV download links
  csv_links <- rvest::html_elements(cells, "a[href*='.csv']")
  csv_link <- if (length(csv_links) > 0) rvest::html_attr(csv_links[1], "href") else ""
  
  # Look for dictionary links
  dict_links <- rvest::html_elements(cells, "a[href*='Dictionary']")
  dictionary_link <- if (length(dict_links) > 0) rvest::html_attr(dict_links[1], "href") else ""
  
  # Extract table name from CSV filename
  table_name <- extract_table_name_from_link(csv_link)
  
  if (table_name == "" && length(cell_texts) >= 4) {
    # Try to extract from cell text if not found in link
    table_name <- extract_table_name_from_text(cell_texts[4])
  }
  
  if (table_name == "") return(NULL)
  
  return(data.frame(
    year = year,
    survey_component = survey_component,
    description = description,
    table_name = table_name,
    csv_link = csv_link,
    dictionary_link = dictionary_link,
    file_size = "", # Would need to be extracted from page or determined by download
    last_modified = as.character(Sys.Date()), # Placeholder
    source_url = paste0("https://nces.ed.gov/ipeds/datacenter/DataFiles.aspx?year=", year),
    stringsAsFactors = FALSE
  ))
}

#' Extract table name from download link
#' @param link URL to CSV file
#' @return Table name or empty string
extract_table_name_from_link <- function(link) {
  if (link == "" || is.na(link)) return("")
  
  # Extract filename from URL
  filename <- basename(link)
  
  # Remove .csv extension and _Data suffix if present
  table_name <- stringr::str_remove(filename, "\\.csv$")
  table_name <- stringr::str_remove(table_name, "_Data$")
  table_name <- stringr::str_remove(table_name, "_Revised$")
  
  return(table_name)
}

#' Extract table name from cell text
#' @param text Cell text content
#' @return Table name or empty string
extract_table_name_from_text <- function(text) {
  # Look for patterns like HD2024, IC2024, etc.
  pattern <- "[A-Z]+\\d{4}[A-Z]*"
  match <- stringr::str_extract(text, pattern)
  
  return(if (is.na(match)) "" else match)
}

#' Create empty data frame with correct structure for files data
#' @return Empty data frame with proper columns
create_empty_files_dataframe <- function() {
  data.frame(
    year = integer(0),
    survey_component = character(0),
    description = character(0),
    table_name = character(0),
    csv_link = character(0),
    dictionary_link = character(0),
    file_size = character(0),
    last_modified = character(0),
    source_url = character(0),
    stringsAsFactors = FALSE
  )
}

#' Download and parse data dictionary for a specific file
#' @param dictionary_link URL to the dictionary
#' @param table_name Name of the table
#' @param verbose Whether to print progress
#' @return Data frame with variable definitions
#' @export
download_data_dictionary <- function(dictionary_link, table_name, verbose = FALSE) {
  
  if (dictionary_link == "" || is.na(dictionary_link)) {
    warning("No dictionary link provided for table: ", table_name)
    return(create_empty_dictionary_dataframe())
  }
  
  if (verbose) {
    message("Downloading data dictionary for ", table_name)
  }
  
  tryCatch({
    # Download the dictionary file (usually HTML or text)
    response <- httr::GET(dictionary_link)
    
    if (httr::status_code(response) != 200) {
      warning("Failed to download dictionary for ", table_name)
      return(create_empty_dictionary_dataframe())
    }
    
    content <- httr::content(response, as = "text", encoding = "UTF-8")
    
    # Parse the dictionary content
    dict_data <- parse_dictionary_content(content, table_name)
    
    return(dict_data)
    
  }, error = function(e) {
    warning("Error downloading dictionary for ", table_name, ": ", e$message)
    return(create_empty_dictionary_dataframe())
  })
}

#' Parse data dictionary content
#' @param content Raw content from dictionary file
#' @param table_name Name of the table
#' @return Data frame with variable definitions
parse_dictionary_content <- function(content, table_name) {
  
  # This would need to be customized based on the actual format of IPEDS dictionaries
  # They might be HTML tables, plain text, or other formats
  
  # For now, return empty structure - this would be enhanced based on actual format
  return(create_empty_dictionary_dataframe())
}

#' Create empty data frame for dictionary data
#' @return Empty data frame with dictionary structure
create_empty_dictionary_dataframe <- function() {
  data.frame(
    table_name = character(0),
    variable_name = character(0),
    variable_label = character(0),
    data_type = character(0),
    valid_values = character(0),
    notes = character(0),
    stringsAsFactors = FALSE
  )
}

#' Get comprehensive file listing for multiple years
#' @param years Vector of years to process
#' @param include_dictionaries Whether to download dictionary information
#' @param verbose Whether to print progress
#' @return Data frame with all file information
#' @export
get_comprehensive_file_listing <- function(years = 2020:2024, 
                                          include_dictionaries = FALSE, 
                                          verbose = TRUE) {
  
  all_files <- create_empty_files_dataframe()
  
  for (year in years) {
    if (verbose) {
      message("Processing year ", year, "...")
    }
    
    year_files <- scrape_ipeds_files_enhanced(year, verbose = verbose)
    
    if (nrow(year_files) > 0) {
      all_files <- rbind(all_files, year_files)
    }
    
    # Be respectful to the server
    Sys.sleep(1)
  }
  
  if (include_dictionaries && nrow(all_files) > 0) {
    if (verbose) {
      message("Downloading data dictionaries...")
    }
    
    # Download dictionaries for unique tables
    unique_tables <- unique(all_files$table_name)
    
    for (table in unique_tables) {
      table_rows <- all_files[all_files$table_name == table, ]
      if (nrow(table_rows) > 0 && table_rows$dictionary_link[1] != "") {
        dict_data <- download_data_dictionary(
          table_rows$dictionary_link[1], 
          table, 
          verbose = verbose
        )
        # Store dictionary data (implementation would depend on storage strategy)
      }
      
      # Be respectful to the server
      Sys.sleep(0.5)
    }
  }
  
  return(all_files)
}

#' Validate downloaded file integrity
#' @param file_path Path to downloaded file
#' @param expected_table_name Expected table name
#' @param verbose Whether to print validation details
#' @return List with validation results
validate_downloaded_file <- function(file_path, expected_table_name, verbose = FALSE) {
  
  if (!file.exists(file_path)) {
    return(list(
      valid = FALSE,
      errors = "File does not exist",
      warnings = character(0),
      row_count = 0,
      column_count = 0
    ))
  }
  
  tryCatch({
    # Read first few rows to validate structure
    sample_data <- utils::read.csv(file_path, nrows = 10, stringsAsFactors = FALSE)
    
    errors <- character(0)
    warnings <- character(0)
    
    # Check if file has expected UNITID column (most IPEDS files should)
    if (!"UNITID" %in% names(sample_data)) {
      warnings <- c(warnings, "No UNITID column found")
    }
    
    # Check for reasonable number of columns
    if (ncol(sample_data) < 2) {
      errors <- c(errors, "Too few columns")
    }
    
    # Get full file info
    file_info <- file.info(file_path)
    
    if (file_info$size < 1000) {  # Less than 1KB is suspicious
      warnings <- c(warnings, "File size is very small")
    }
    
    # Count total rows (expensive for large files, so use wc -l on Unix systems)
    total_rows <- count_file_rows(file_path)
    
    if (verbose) {
      message("Validation for ", expected_table_name, ": ",
              total_rows, " rows, ", ncol(sample_data), " columns")
    }
    
    return(list(
      valid = length(errors) == 0,
      errors = errors,
      warnings = warnings,
      row_count = total_rows,
      column_count = ncol(sample_data),
      file_size = file_info$size,
      sample_data = sample_data
    ))
    
  }, error = function(e) {
    return(list(
      valid = FALSE,
      errors = paste("Validation error:", e$message),
      warnings = character(0),
      row_count = 0,
      column_count = 0
    ))
  })
}

#' Count rows in a file efficiently
#' @param file_path Path to file
#' @return Number of rows
count_file_rows <- function(file_path) {
  tryCatch({
    # Try to use system wc command if available (much faster for large files)
    if (Sys.which("wc") != "") {
      result <- system(paste("wc -l", shQuote(file_path)), intern = TRUE)
      return(as.numeric(strsplit(result, " ")[[1]][1]) - 1)  # Subtract 1 for header
    } else {
      # Fallback to R method
      lines <- readLines(file_path)
      return(length(lines) - 1)  # Subtract 1 for header
    }
  }, error = function(e) {
    return(0)
  })
}