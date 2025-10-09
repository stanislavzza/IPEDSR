# ENHANCED SCRAPING FUNCTION FOR DICTIONARY FILES
# Modify the existing scraping function to capture SOMETHING_Dict.zip files from last column

cat("=== ENHANCING SCRAPING FUNCTION FOR DICTIONARY FILES ===\n")

library(IPEDSR)

# First, let's test the current function to see what it captures
cat("\n1. TESTING CURRENT SCRAPING FUNCTION:\n")
current_results <- scrape_ipeds_files_enhanced(2024, verbose = FALSE)
cat("Current function finds:", nrow(current_results), "files\n")

if (nrow(current_results) > 0) {
  cat("Sample results:\n")
  for (i in 1:min(3, nrow(current_results))) {
    cat("  ", current_results$table_name[i], "\n")
    cat("    CSV link:", if(current_results$csv_link[i] != "") "HAS CSV" else "NO CSV", "\n")
    cat("    ZIP link:", if(current_results$zip_link[i] != "") "HAS ZIP" else "NO ZIP", "\n") 
    cat("    Dict link:", if(current_results$dictionary_link[i] != "") "HAS DICT" else "NO DICT", "\n")
  }
}

# 2. Create enhanced version that specifically looks for XX_Dict.zip files
cat("\n2. CREATING ENHANCED DICTIONARY SCRAPING FUNCTION:\n")

# Enhanced function to also capture dictionary files from last column
scrape_ipeds_files_with_dictionaries <- function(year, verbose = FALSE) {
  
  url <- paste0("https://nces.ed.gov/ipeds/datacenter/DataFiles.aspx?year=", year)
  
  if (verbose) {
    message("Fetching IPEDS data files AND dictionaries for ", year, " from: ", url)
  }
  
  tryCatch({
    # Read the webpage
    page <- rvest::read_html(url)
    
    # Look for table rows that contain data file information
    rows <- rvest::html_elements(page, "tr")
    
    # Extract file information from each row
    files_data <- extract_file_info_with_dictionaries(rows, year, verbose)
    
    if (verbose && nrow(files_data) > 0) {
      message("Found ", nrow(files_data), " data files and dictionaries for ", year)
    }
    
    return(files_data)
    
  }, error = function(e) {
    warning("Error scraping IPEDS files for year ", year, ": ", e$message)
    return(create_empty_files_dataframe())
  })
}

# Enhanced extraction function that looks in ALL columns for dictionary links
extract_file_info_with_dictionaries <- function(rows, year, verbose) {
  
  files_data <- create_empty_files_dataframe()
  
  for (i in seq_along(rows)) {
    row <- rows[[i]]
    
    # Extract ALL cells in this row
    cells <- rvest::html_elements(row, "td")
    
    if (length(cells) == 0) next
    
    cell_texts <- rvest::html_text(cells, trim = TRUE)
    
    # Look for rows that contain year information and file links
    if (length(cell_texts) >= 4 && any(grepl(as.character(year), cell_texts))) {
      
      # Parse the row to extract file information INCLUDING dictionary links from last column
      file_info <- parse_file_row_with_dictionaries(cells, cell_texts, year, verbose)
      
      if (!is.null(file_info)) {
        files_data <- rbind(files_data, file_info)
      }
    }
  }
  
  return(files_data)
}

# Enhanced row parser that looks specifically for XX_Dict.zip in ALL columns
parse_file_row_with_dictionaries <- function(cells, cell_texts, year, verbose = FALSE) {
  
  if (length(cell_texts) < 4) return(NULL)
  
  # Extract survey component and description
  survey_component <- if (length(cell_texts) >= 2) cell_texts[2] else ""
  description <- if (length(cell_texts) >= 3) cell_texts[3] else ""
  
  # Look for CSV download links
  csv_links <- rvest::html_elements(cells, "a[href*='.csv']")
  csv_link <- if (length(csv_links) > 0) rvest::html_attr(csv_links[1], "href") else ""
  
  # Look for ZIP download links (for newer years like 2024)
  zip_links <- rvest::html_elements(cells, "a[href*='.zip']")
  zip_link <- if (length(zip_links) > 0) rvest::html_attr(zip_links[1], "href") else ""
  
  # ENHANCED: Look for dictionary links with _Dict.zip pattern in ALL cells
  dictionary_link <- ""
  dict_file_name <- ""
  
  # Check each cell for dictionary links
  for (j in seq_along(cells)) {
    # Look for links containing "_Dict.zip" 
    dict_links <- rvest::html_elements(cells[j], "a[href*='_Dict.zip']")
    if (length(dict_links) > 0) {
      dictionary_link <- rvest::html_attr(dict_links[1], "href")
      dict_file_name <- basename(dictionary_link)
      if (verbose) {
        cat("    Found dictionary:", dict_file_name, "in column", j, "\n")
      }
      break  # Found it, stop looking
    }
    
    # Also look for any links containing "Dict" (case insensitive)
    dict_links_general <- rvest::html_elements(cells[j], "a")
    if (length(dict_links_general) > 0) {
      for (link in dict_links_general) {
        href <- rvest::html_attr(link, "href")
        if (!is.na(href) && grepl("Dict", href, ignore.case = TRUE)) {
          dictionary_link <- href
          dict_file_name <- basename(href)
          if (verbose) {
            cat("    Found dictionary (general):", dict_file_name, "in column", j, "\n")
          }
          break
        }
      }
      if (dictionary_link != "") break
    }
  }
  
  # Extract table name from CSV filename first, then ZIP if no CSV
  table_name <- extract_table_name_from_link(csv_link)
  if (table_name == "" && zip_link != "") {
    table_name <- extract_table_name_from_link(zip_link)
  }
  
  if (table_name == "" && length(cell_texts) >= 4) {
    # Try to extract from cell text if not found in link
    table_name <- extract_table_name_from_text(cell_texts[4])
  }
  
  if (table_name == "") return(NULL)
  
  result <- data.frame(
    year = year,
    survey_component = survey_component,
    description = description,
    table_name = table_name,
    csv_link = csv_link,
    zip_link = zip_link,
    dictionary_link = dictionary_link,
    dictionary_file = dict_file_name,  # NEW: Store the dictionary filename
    file_size = "",
    last_modified = as.character(Sys.Date()),
    source_url = paste0("https://nces.ed.gov/ipeds/datacenter/DataFiles.aspx?year=", year),
    stringsAsFactors = FALSE
  )
  
  return(result)
}

cat("\n3. TESTING ENHANCED FUNCTION:\n")
cat("Testing enhanced scraping function to capture dictionary files...\n")

# Note: We can't actually test this enhanced function without modifying the package
# Instead, let's create a plan for implementation

cat("\n=== IMPLEMENTATION PLAN ===\n")
cat("1. Backup current web_scraping.R file\n")
cat("2. Modify parse_file_row function to look for _Dict.zip in ALL columns\n")
cat("3. Add dictionary_file column to output dataframe\n")
cat("4. Test with 2024 data to verify dictionary capture\n")
cat("5. Download dictionary ZIP files when found\n")

cat("\n=== NEXT STEPS ===\n")
cat("Ready to modify the web_scraping.R file to add dictionary support?\n")