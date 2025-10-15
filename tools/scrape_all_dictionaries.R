# SCRAPE ALL DICTIONARY FILES FROM IPEDS 2024 PAGE
# Find ALL files ending in _Dict.zip using regex pattern matching

cat("=== SCRAPING ALL DICTIONARY FILES FROM IPEDS 2024 PAGE ===\n")

library(IPEDSR)
library(rvest)
library(httr)

cat("\n1. FETCHING IPEDS 2024 PAGE:\n")

# Try different possible URLs for 2024 data
possible_urls <- c(
  "https://nces.ed.gov/ipeds/datacenter/DataFiles.aspx?year=2024",
  "https://nces.ed.gov/ipeds/datacenter/Default.aspx?year=2024",
  "https://nces.ed.gov/ipeds/datacenter/DataFiles.aspx?gotoReportId=7&year=2024"
)

page_content <- NULL
working_url <- NULL

for (url in possible_urls) {
  cat("Trying URL:", url, "\n")
  
  tryCatch({
    response <- httr::GET(url)
    if (httr::status_code(response) == 200) {
      page_content <- httr::content(response, as = "text", encoding = "UTF-8")
      working_url <- url
      cat("  ✅ SUCCESS - got page content\n")
      break
    } else {
      cat("  ❌ Status code:", httr::status_code(response), "\n")
    }
  }, error = function(e) {
    cat("  ❌ Error:", e$message, "\n")
  })
}

if (is.null(page_content)) {
  cat("❌ Could not fetch any IPEDS 2024 page\n")
  stop("Unable to fetch IPEDS page")
}

cat("\n2. SEARCHING FOR ALL _Dict.zip FILES:\n")
cat("Using URL:", working_url, "\n")

# Use regex to find ALL links containing _Dict.zip
dict_pattern <- "href=[\"'][^\"']*_Dict\\.zip[\"']"
dict_matches <- gregexpr(dict_pattern, page_content, ignore.case = TRUE)[[1]]

if (dict_matches[1] == -1) {
  cat("❌ No _Dict.zip files found on the page\n")
  
  # Let's try a broader search to see what's on the page
  cat("\n3. DEBUGGING - SEARCHING FOR ANY .zip FILES:\n")
  zip_pattern <- "href=[\"'][^\"']*\\.zip[\"']"
  zip_matches <- gregexpr(zip_pattern, page_content, ignore.case = TRUE)[[1]]
  
  if (zip_matches[1] != -1) {
    # Extract all zip file links
    zip_links <- character(0)
    for (i in seq_along(zip_matches)) {
      match_start <- zip_matches[i]
      match_length <- attr(zip_matches, "match.length")[i]
      match_text <- substr(page_content, match_start, match_start + match_length - 1)
      
      # Extract the URL from href="URL"
      url_match <- regmatches(match_text, regexec("href=[\"']([^\"']*)[\"']", match_text))[[1]]
      if (length(url_match) >= 2) {
        zip_links <- c(zip_links, url_match[2])
      }
    }
    
    cat("Found", length(unique(zip_links)), "total .zip files:\n")
    for (link in unique(zip_links)[1:min(10, length(unique(zip_links)))]) {
      cat("  ", link, "\n")
    }
    
    # Check if any contain "Dict"
    dict_zips <- grep("Dict", zip_links, ignore.case = TRUE, value = TRUE)
    if (length(dict_zips) > 0) {
      cat("\nFound .zip files containing 'Dict':\n")
      for (link in dict_zips) {
        cat("  ", link, "\n")
      }
    }
  } else {
    cat("❌ No .zip files found at all on the page\n")
  }
  
} else {
  cat("✅ Found", length(dict_matches), "_Dict.zip file references\n")
  
  # Extract all dictionary file URLs
  dict_urls <- character(0)
  
  for (i in seq_along(dict_matches)) {
    match_start <- dict_matches[i]
    match_length <- attr(dict_matches, "match.length")[i]
    match_text <- substr(page_content, match_start, match_start + match_length - 1)
    
    # Extract the URL from href="URL"
    url_match <- regmatches(match_text, regexec("href=[\"']([^\"']*)[\"']", match_text))[[1]]
    if (length(url_match) >= 2) {
      dict_urls <- c(dict_urls, url_match[2])
    }
  }
  
  # Clean up URLs and make them absolute
  dict_urls <- unique(dict_urls)
  
  # Convert relative URLs to absolute URLs
  for (i in seq_along(dict_urls)) {
    if (!grepl("^https?://", dict_urls[i])) {
      if (startsWith(dict_urls[i], "/")) {
        dict_urls[i] <- paste0("https://nces.ed.gov", dict_urls[i])
      } else {
        dict_urls[i] <- paste0("https://nces.ed.gov/ipeds/datacenter/", dict_urls[i])
      }
    }
  }
  
  cat("\n3. FOUND DICTIONARY FILES:\n")
  for (i in seq_along(dict_urls)) {
    cat("  ", i, ".", dict_urls[i], "\n")
  }
  
  cat("\n4. TESTING DICTIONARY URL AVAILABILITY:\n")
  available_dicts <- character(0)
  
  for (url in dict_urls) {
    filename <- basename(url)
    cat("Testing", filename, "...")
    
    tryCatch({
      response <- httr::HEAD(url)
      if (httr::status_code(response) == 200) {
        cat(" ✅ AVAILABLE\n")
        available_dicts <- c(available_dicts, url)
      } else {
        cat(" ❌ Status:", httr::status_code(response), "\n")
      }
    }, error = function(e) {
      cat(" ❌ ERROR:", e$message, "\n")
    })
  }
  
  cat("\n5. FINAL SUMMARY:\n")
  cat("Total dictionary files found on page:", length(dict_urls), "\n")
  cat("Available for download:", length(available_dicts), "\n")
  
  if (length(available_dicts) > 0) {
    cat("\n✅ AVAILABLE DICTIONARY FILES:\n")
    for (url in available_dicts) {
      cat("  ", url, "\n")
    }
  }
}

cat("\n=== SCRAPING COMPLETE ===\n")