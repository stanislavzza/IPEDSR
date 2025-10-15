# DIRECT DICTIONARY DOWNLOAD APPROACH
# Instead of scraping, construct dictionary URLs directly and download them

cat("=== DIRECT DICTIONARY DOWNLOAD APPROACH ===\n")

library(IPEDSR)

cat("\n1. IDENTIFYING 2024 SURVEY COMPONENTS:\n")

# Get the 2024 tables we already have in the database
con <- ensure_connection()
existing_2024_tables <- grep("2024", DBI::dbListTables(con), value = TRUE)

cat("2024 tables in database:", length(existing_2024_tables), "\n")
for (table in sort(existing_2024_tables)) {
  cat("  ", table, "\n")
}

# Extract base survey components (remove 2024 and suffixes)
survey_components <- unique(gsub("2024.*", "", existing_2024_tables))
survey_components <- survey_components[survey_components != ""]

cat("\n2. SURVEY COMPONENTS IDENTIFIED:\n")
cat("Base survey components:", paste(survey_components, collapse = ", "), "\n")

# Expected dictionary files based on the pattern you provided
expected_dict_urls <- paste0("https://nces.ed.gov/ipeds/datacenter/data/", 
                             survey_components, "2024_Dict.zip")

cat("\n3. EXPECTED DICTIONARY URLS:\n")
for (i in seq_along(survey_components)) {
  cat("  ", survey_components[i], ":", expected_dict_urls[i], "\n")
}

# Function to test if a dictionary URL exists
test_dict_url <- function(url) {
  tryCatch({
    response <- httr::HEAD(url)
    return(httr::status_code(response) == 200)
  }, error = function(e) {
    return(FALSE)
  })
}

cat("\n4. TESTING DICTIONARY URL AVAILABILITY:\n")
available_dicts <- character(0)

for (i in seq_along(expected_dict_urls)) {
  url <- expected_dict_urls[i]
  component <- survey_components[i]
  
  cat("Testing", component, "...")
  if (test_dict_url(url)) {
    cat(" ✅ AVAILABLE\n")
    available_dicts <- c(available_dicts, url)
  } else {
    cat(" ❌ NOT FOUND\n")
  }
}

cat("\n5. SUMMARY:\n")
cat("Available dictionary files:", length(available_dicts), "\n")

if (length(available_dicts) > 0) {
  cat("\n✅ FOUND DICTIONARY FILES:\n")
  for (url in available_dicts) {
    cat("  ", url, "\n")
  }
  
  cat("\nNext steps:\n")
  cat("1. Download these ZIP files\n")
  cat("2. Extract Excel workbooks from ZIP files\n")
  cat("3. Read Tables, valuesets, vartable worksheets from Excel\n")
  cat("4. Import as tables24, valuesets24, vartable24\n")
  
} else {
  cat("\n❌ NO DICTIONARY FILES FOUND\n")
  cat("This could mean:\n")
  cat("1. Dictionary files use a different naming pattern\n")
  cat("2. Dictionary files aren't released yet for 2024\n")
  cat("3. They're located at a different URL structure\n")
}

cat("\n=== DIRECT APPROACH COMPLETE ===\n")