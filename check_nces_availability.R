#!/usr/bin/env Rscript
# Check what IPEDS data years are actually available on NCES website
# This script programmatically verifies data availability

library(rvest)
library(httr)
library(dplyr)

cat("Checking NCES IPEDS data availability...\n\n")

# Function to check if a specific year has data available
check_year_availability <- function(year) {
  tryCatch({
    url <- paste0("https://nces.ed.gov/ipeds/datacenter/DataFiles.aspx?year=", year)
    cat("Checking year", year, "at:", url, "\n")
    
    # Add headers to avoid blocking
    response <- httr::GET(url, 
                         httr::user_agent("IPEDSR R Package Data Checker"),
                         httr::timeout(30))
    
    if (httr::status_code(response) != 200) {
      cat("  ❌ HTTP", httr::status_code(response), "- Year", year, "page not accessible\n")
      return(list(year = year, available = FALSE, file_count = 0, error = paste("HTTP", httr::status_code(response))))
    }
    
    # Parse the page
    page <- httr::content(response, "text", encoding = "UTF-8")
    html_doc <- rvest::read_html(page)
    
    # Look for download links (CSV files)
    csv_links <- html_doc %>%
      rvest::html_nodes("a[href$='.csv']") %>%
      rvest::html_attr("href")
    
    # Also look for zip files that might contain CSV data
    zip_links <- html_doc %>%
      rvest::html_nodes("a[href$='.zip']") %>%
      rvest::html_attr("href")
    
    # Check for any indication this is a valid data year
    page_title <- html_doc %>%
      rvest::html_node("title") %>%
      rvest::html_text()
    
    # Look for data tables or file listings
    data_indicators <- c(
      length(csv_links),
      length(zip_links),
      grepl(as.character(year), page_title, ignore.case = TRUE)
    )
    
    file_count <- length(csv_links) + length(zip_links)
    has_data <- file_count > 0 || any(data_indicators)
    
    if (has_data) {
      cat("  ✅ Year", year, "appears to have data -", file_count, "files found\n")
    } else {
      cat("  ❌ Year", year, "appears to have no data files\n")
    }
    
    return(list(
      year = year, 
      available = has_data, 
      file_count = file_count,
      csv_files = length(csv_links),
      zip_files = length(zip_links),
      page_title = page_title
    ))
    
  }, error = function(e) {
    cat("  ❌ Error checking year", year, ":", e$message, "\n")
    return(list(year = year, available = FALSE, file_count = 0, error = e$message))
  })
}

# Check recent years around current year
current_year <- 2025
years_to_check <- (current_year-5):(current_year-1)  # 2020-2024

cat("Checking years:", paste(years_to_check, collapse = ", "), "\n\n")

results <- list()
for (year in years_to_check) {
  results[[as.character(year)]] <- check_year_availability(year)
  Sys.sleep(1)  # Be nice to the server
}

cat("\n", paste(rep("=", 60), collapse=""), "\n")
cat("SUMMARY OF NCES DATA AVAILABILITY\n")
cat(paste(rep("=", 60), collapse=""), "\n")

for (year in years_to_check) {
  result <- results[[as.character(year)]]
  status <- if (result$available) "✅ AVAILABLE" else "❌ NOT AVAILABLE"
  files <- if (result$file_count > 0) paste0(" (", result$file_count, " files)") else ""
  cat(sprintf("Year %d: %s%s\n", year, status, files))
}

# Specifically check 2024
cat("\n", paste(rep("=", 40), collapse=""), "\n")
cat("DETAILED CHECK FOR 2024\n")
cat(paste(rep("=", 40), collapse=""), "\n")

result_2024 <- results[["2024"]]
if (!is.null(result_2024)) {
  cat("2024 Data Status:", if (result_2024$available) "AVAILABLE" else "NOT AVAILABLE", "\n")
  cat("Files found:", result_2024$file_count, "\n")
  cat("CSV files:", result_2024$csv_files, "\n")
  cat("ZIP files:", result_2024$zip_files, "\n")
  if (!is.null(result_2024$page_title)) {
    cat("Page title:", substr(result_2024$page_title, 1, 100), "...\n")
  }
  if (!is.null(result_2024$error)) {
    cat("Error:", result_2024$error, "\n")
  }
}

cat("\nCheck completed at:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")