# Create Consolidated Dictionary Tables
# Handles structural differences across years and creates unified tables

library(DBI)
source("R/database_management.R")

# Connect to database
con <- get_ipeds_connection(read_only = FALSE)

cat("Creating consolidated dictionary tables...\n")
cat("==========================================================\n")

# 1. CONSOLIDATE TABLES (Tables06-Tables24)
cat("1. Creating Tables_All...\n")

# Get all Tables tables
tables_tables <- grep('^Tables[0-9]{2}$', dbListTables(con), value=TRUE)
cat("Found Tables tables:", paste(tables_tables, collapse=", "), "\n")

# Handle two different structures:
# - Tables06-Tables17: 10 columns (no F11-F16)
# - Tables19-Tables24: 16 columns (with F11-F16)

# First, get the full structure (from Tables19+)
full_columns <- dbListFields(con, "Tables19")
cat("Full column structure:", paste(full_columns, collapse=", "), "\n")

# Create unified Tables_All
tables_queries <- c()
for (table in tables_tables) {
    year <- gsub("Tables", "", table)
    cols <- dbListFields(con, table)
    
    if (length(cols) == 10) {
        # Early format - add NULL for missing F11-F16 columns
        query <- sprintf("SELECT SurveyOrder, SurveyNumber, Survey, YearCoverage, TableName, Tablenumber, TableTitle, Release, \"Release date\", NULL as F11, NULL as F12, NULL as F13, NULL as F14, NULL as F15, NULL as F16, Description, '%s' as YEAR FROM %s", year, table)
    } else {
        # Later format - use all columns
        query <- sprintf("SELECT SurveyOrder, SurveyNumber, Survey, YearCoverage, TableName, Tablenumber, TableTitle, Release, \"Release date\", F11, F12, F13, F14, F15, F16, Description, '%s' as YEAR FROM %s", year, table)
    }
    tables_queries <- c(tables_queries, query)
}

# Combine all Tables data
tables_union_query <- paste(tables_queries, collapse=" UNION ALL ")
cat("Creating Tables_All with", length(tables_queries), "table unions...\n")
dbExecute(con, sprintf("CREATE OR REPLACE TABLE Tables_All AS %s", tables_union_query))

# Verify Tables_All
tables_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM Tables_All")$count
cat("Tables_All created with", tables_count, "rows\n\n")

# 2. CONSOLIDATE VARTABLE (vartable06-vartable24)
cat("2. Creating vartable_All...\n")

# Get all vartable tables  
vartable_tables <- grep('^vartable[0-9]{2}$', dbListTables(con), value=TRUE)
cat("Found vartable tables:", paste(vartable_tables, collapse=", "), "\n")

# Handle two different structures:
# - vartable06-vartable23: 22 columns (full IPEDS format)
# - vartable24: 8 columns (from Excel worksheets)

# Get the full structure from earlier years
full_vartable_cols <- dbListFields(con, "vartable06")
cat("Full vartable structure:", paste(full_vartable_cols, collapse=", "), "\n")

vartable_queries <- c()
for (table in vartable_tables) {
    year <- gsub("vartable", "", table)
    cols <- dbListFields(con, table)
    
    if (table == "vartable24") {
        # 2024 format from Excel - map available columns and add NULLs for missing
        query <- sprintf("SELECT 
            NULL as SurveyOrder,
            NULL as SurveyNumber, 
            NULL as Survey,
            NULL as Tablenumber,
            NULL as TableName,
            NULL as TableTitle,
            varNumber,
            NULL as varOrder,
            varName,
            imputationvar,
            varTitle,
            DataType,
            FieldWidth as fieldWidth,
            format,
            NULL as multiRecord,
            NULL as hasRV,
            NULL as fileNumber,
            NULL as sectionnumber,
            NULL as varSource,
            NULL as filetitle,
            NULL as sectionTitle,
            NULL as longDescription,
            '%s' as YEAR,
            source_file
        FROM %s", year, table)
    } else {
        # 2006-2023 format - use all existing columns
        query <- sprintf("SELECT 
            SurveyOrder,
            SurveyNumber,
            Survey,
            Tablenumber,
            TableName,
            TableTitle,
            varNumber,
            varOrder,
            varName,
            imputationvar,
            varTitle,
            DataType,
            fieldWidth,
            format,
            multiRecord,
            hasRV,
            fileNumber,
            sectionnumber,
            varSource,
            filetitle,
            sectionTitle,
            longDescription,
            '%s' as YEAR,
            NULL as source_file
        FROM %s", year, table)
    }
    vartable_queries <- c(vartable_queries, query)
}

# Combine all vartable data
vartable_union_query <- paste(vartable_queries, collapse=" UNION ALL ")
cat("Creating vartable_All with", length(vartable_queries), "table unions...\n")
dbExecute(con, sprintf("CREATE OR REPLACE TABLE vartable_All AS %s", vartable_union_query))

# Verify vartable_All
vartable_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM vartable_All")$count
cat("vartable_All created with", vartable_count, "rows\n\n")

# 3. CONSOLIDATE VALUESETS (valuesets06-valuesets24) 
cat("3. Creating valuesets_All...\n")

# Get all valuesets tables
valuesets_tables <- grep('^valuesets[0-9]{2}$', dbListTables(con), value=TRUE)
cat("Found valuesets tables:", paste(valuesets_tables, collapse=", "), "\n")

# Handle two different structures:
# - valuesets06-valuesets23: 12 columns (full IPEDS format)
# - valuesets24: 4 columns (from Excel worksheets)

valuesets_queries <- c()
for (table in valuesets_tables) {
    year <- gsub("valuesets", "", table)
    cols <- dbListFields(con, table)
    
    if (table == "valuesets24") {
        # 2024 format from Excel - map available columns and add NULLs for missing
        query <- sprintf("SELECT
            NULL as SurveyOrder,
            NULL as Tablenumber,
            NULL as TableName,
            varNumber,
            NULL as varOrder,
            varName,
            NULL as Codevalue,
            NULL as Frequency,
            NULL as Percent,
            NULL as valueOrder,
            NULL as valueLabel,
            NULL as varTitle,
            longDescription,
            '%s' as YEAR,
            source_file
        FROM %s", year, table)
    } else {
        # 2006-2023 format - use all existing columns
        query <- sprintf("SELECT
            SurveyOrder,
            Tablenumber,
            TableName,
            varNumber,
            varOrder,
            varName,
            Codevalue,
            Frequency,
            Percent,
            valueOrder,
            valueLabel,
            varTitle,
            NULL as longDescription,
            '%s' as YEAR,
            NULL as source_file
        FROM %s", year, table)
    }
    valuesets_queries <- c(valuesets_queries, query)
}

# Combine all valuesets data
valuesets_union_query <- paste(valuesets_queries, collapse=" UNION ALL ")
cat("Creating valuesets_All with", length(valuesets_queries), "table unions...\n")
dbExecute(con, sprintf("CREATE OR REPLACE TABLE valuesets_All AS %s", valuesets_union_query))

# Verify valuesets_All
valuesets_count <- dbGetQuery(con, "SELECT COUNT(*) as count FROM valuesets_All")$count
cat("valuesets_All created with", valuesets_count, "rows\n\n")

# 4. SUMMARY AND VERIFICATION
cat("==========================================================\n")
cat("CONSOLIDATION COMPLETE!\n")
cat("==========================================================\n")

# Show summary statistics
cat("Summary of consolidated tables:\n")
cat("- Tables_All:", tables_count, "rows\n")
cat("- vartable_All:", vartable_count, "rows\n") 
cat("- valuesets_All:", valuesets_count, "rows\n\n")

# Show year coverage
cat("Year coverage in each consolidated table:\n")

tables_years <- dbGetQuery(con, "SELECT YEAR, COUNT(*) as count FROM Tables_All GROUP BY YEAR ORDER BY YEAR")
cat("Tables_All years:\n")
print(tables_years)

vartable_years <- dbGetQuery(con, "SELECT YEAR, COUNT(*) as count FROM vartable_All GROUP BY YEAR ORDER BY YEAR")  
cat("\nvartable_All years:\n")
print(vartable_years)

valuesets_years <- dbGetQuery(con, "SELECT YEAR, COUNT(*) as count FROM valuesets_All GROUP BY YEAR ORDER BY YEAR")
cat("\nvaluesets_All years:\n") 
print(valuesets_years)

# Sample data from each consolidated table
cat("\nSample from Tables_All:\n")
print(head(dbGetQuery(con, "SELECT TableName, TableTitle, YEAR FROM Tables_All ORDER BY YEAR, TableName"), 5))

cat("\nSample from vartable_All:\n")
print(head(dbGetQuery(con, "SELECT varName, varTitle, YEAR FROM vartable_All WHERE varTitle IS NOT NULL ORDER BY YEAR, varName"), 5))

cat("\nSample from valuesets_All:\n")
print(head(dbGetQuery(con, "SELECT varName, valueLabel, YEAR FROM valuesets_All WHERE valueLabel IS NOT NULL ORDER BY YEAR, varName"), 5))

dbDisconnect(con)
cat("\nConsolidated dictionary system is ready!\n")