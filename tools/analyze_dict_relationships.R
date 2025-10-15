# DICTIONARY TABLE RELATIONSHIPS ANALYSIS
# Map relationships between Tables, valuesets, vartable and data tables

cat("=== DICTIONARY TABLE RELATIONSHIPS ANALYSIS ===\n")

library(IPEDSR)
library(dplyr)
con <- ensure_connection()

# 1. Examine the relationship structure using 2023 data (most recent complete set)
cat("\n1. RELATIONSHIP STRUCTURE ANALYSIS (using 2023 data):\n")

# Get the three dictionary tables for 2023
tables_23 <- DBI::dbGetQuery(con, "SELECT * FROM Tables23")
valuesets_23 <- DBI::dbGetQuery(con, "SELECT * FROM valuesets23") 
vartable_23 <- DBI::dbGetQuery(con, "SELECT * FROM vartable23")

cat("Tables23 structure:\n")
cat("  Rows:", nrow(tables_23), "\n")
cat("  Key columns:", paste(names(tables_23), collapse = ", "), "\n")

cat("\nvaluesets23 structure:\n") 
cat("  Rows:", nrow(valuesets_23), "\n")
cat("  Key columns:", paste(names(valuesets_23), collapse = ", "), "\n")

cat("\nvartable23 structure:\n")
cat("  Rows:", nrow(vartable_23), "\n") 
cat("  Key columns:", paste(names(vartable_23), collapse = ", "), "\n")

# 2. Analyze the relationships between the three dictionary tables
cat("\n2. INTER-DICTIONARY RELATIONSHIPS:\n")

# A. Tables -> valuesets relationship
tables_names <- unique(tables_23$TableName)
valuesets_tables <- unique(valuesets_23$TableName)

cat("Tables in Tables23:", length(tables_names), "\n")
cat("Tables in valuesets23:", length(valuesets_tables), "\n")

# Check overlap
tables_overlap <- intersect(tables_names, valuesets_tables)
cat("Tables present in both Tables23 and valuesets23:", length(tables_overlap), "\n")

if (length(tables_overlap) > 10) {
  cat("Sample overlapping tables:", paste(head(tables_overlap, 10), collapse = ", "), "\n")
}

# B. Tables -> vartable relationship  
vartable_tables <- unique(vartable_23$TableName)
cat("Tables in vartable23:", length(vartable_tables), "\n")

tables_vartable_overlap <- intersect(tables_names, vartable_tables)
cat("Tables present in both Tables23 and vartable23:", length(tables_vartable_overlap), "\n")

# C. valuesets -> vartable relationship
valuesets_vartable_overlap <- intersect(valuesets_tables, vartable_tables)
cat("Tables present in both valuesets23 and vartable23:", length(valuesets_vartable_overlap), "\n")

# 3. Examine the connection to actual data tables
cat("\n3. CONNECTION TO DATA TABLES:\n")

# Get 2023 data tables
data_tables_2023 <- grep("2023", DBI::dbListTables(con), value = TRUE)
data_tables_2023 <- data_tables_2023[!grepl("^(tables|valuesets|vartable)", data_tables_2023, ignore.case = TRUE)]

cat("2023 data tables:", length(data_tables_2023), "\n")
cat("Sample data tables:", paste(head(data_tables_2023, 10), collapse = ", "), "\n")

# Check how many data tables have dictionary coverage
data_in_tables <- intersect(data_tables_2023, tables_names) 
data_in_valuesets <- intersect(data_tables_2023, valuesets_tables)
data_in_vartable <- intersect(data_tables_2023, vartable_tables)

cat("\nDictionary coverage of data tables:\n")
cat("Data tables in Tables23:", length(data_in_tables), "/", length(data_tables_2023), "\n")
cat("Data tables in valuesets23:", length(data_in_valuesets), "/", length(data_tables_2023), "\n") 
cat("Data tables in vartable23:", length(data_in_vartable), "/", length(data_tables_2023), "\n")

# 4. Detailed relationship analysis
cat("\n4. DETAILED RELATIONSHIP PATTERNS:\n")

# Examine a specific table to understand the relationships
if ("HD2023" %in% tables_names) {
  cat("\nExample: HD2023 table relationships:\n")
  
  # Get HD2023 info from each dictionary
  hd_tables <- tables_23[tables_23$TableName == "HD2023", ]
  hd_valuesets <- valuesets_23[valuesets_23$TableName == "HD2023", ]
  hd_vartable <- vartable_23[vartable_23$TableName == "HD2023", ]
  
  cat("HD2023 in Tables23:", nrow(hd_tables), "records\n")
  cat("HD2023 in valuesets23:", nrow(hd_valuesets), "records\n")
  cat("HD2023 in vartable23:", nrow(hd_vartable), "records\n")
  
  if (nrow(hd_vartable) > 0) {
    hd_variables <- unique(hd_vartable$varName)
    cat("HD2023 variables:", length(hd_variables), "\n")
    cat("Sample variables:", paste(head(hd_variables, 10), collapse = ", "), "\n")
  }
  
  if (nrow(hd_valuesets) > 0) {
    hd_valuesets_vars <- unique(hd_valuesets$varName)
    cat("HD2023 variables with value sets:", length(hd_valuesets_vars), "\n")
  }
}

# 5. Dictionary table consolidation implications
cat("\n5. CONSOLIDATION IMPLICATIONS:\n")

cat("Key findings for consolidation strategy:\n")
cat("1. Tables table: Contains survey/table metadata (", nrow(tables_23), "records)\n")
cat("2. valuesets table: Contains variable value labels (", nrow(valuesets_23), "records)\n")
cat("3. vartable table: Contains variable definitions (", nrow(vartable_23), "records)\n")

cat("\nRelationship hierarchy:\n") 
cat("Survey -> Table -> Variable -> Values\n")
cat("Tables23 defines surveys and tables\n")
cat("vartable23 defines variables within tables\n")
cat("valuesets23 defines possible values for variables\n")

# 6. Year consistency check
cat("\n6. YEAR CONSISTENCY PATTERNS:\n")

# Check if the relationships are consistent across years
cat("Checking relationship consistency across recent years:\n")

years_to_check <- c("22", "21", "20")
for (year in years_to_check) {
  tables_name <- paste0("Tables", year)
  valuesets_name <- paste0("valuesets", year)
  vartable_name <- paste0("vartable", year)
  
  if (all(c(tables_name, valuesets_name, vartable_name) %in% DBI::dbListTables(con))) {
    tables_data <- DBI::dbGetQuery(con, paste("SELECT COUNT(*) as n FROM", tables_name))$n
    valuesets_data <- DBI::dbGetQuery(con, paste("SELECT COUNT(*) as n FROM", valuesets_name))$n
    vartable_data <- DBI::dbGetQuery(con, paste("SELECT COUNT(*) as n FROM", vartable_name))$n
    
    cat("20", year, ": Tables(", tables_data, ") valuesets(", valuesets_data, ") vartable(", vartable_data, ")\n")
  }
}

cat("\n=== RELATIONSHIP ANALYSIS COMPLETE ===\n")
cat("Dictionary tables form a hierarchical metadata system:\n")
cat("Tables -> vartable -> valuesets\n")
cat("Perfect candidates for consolidation with year column\n")