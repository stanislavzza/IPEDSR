# Quick check for remaining missing files
library(IPEDSR)

available_2024 <- scrape_ipeds_files_enhanced(2024, verbose = FALSE)
available_clean <- gsub("\\.zip$", "", available_2024$table_name)
existing_2024 <- grep("2024", DBI::dbListTables(ensure_connection()), value = TRUE)
missing <- available_clean[!available_clean %in% existing_2024]

cat("Still missing:", length(missing), "files:\n")
for(m in missing) {
  cat(" -", m, "\n")
}

# Show what we have vs what we expect
cat("\nHave:", length(existing_2024), "files\n")
cat("Expected:", length(available_clean), "files\n")

# Show duplicates in available list (if any)
cat("\nChecking for duplicates in available list...\n")
if(any(duplicated(available_clean))) {
  cat("Found duplicates:", sum(duplicated(available_clean)), "\n")
  dups <- available_clean[duplicated(available_clean)]
  for(d in unique(dups)) {
    cat(" -", d, "appears", sum(available_clean == d), "times\n")
  }
} else {
  cat("No duplicates found\n")
}