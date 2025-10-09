# Download and Process All 2024 Dictionary Files
# This script downloads all 13 dictionary ZIP files found on IPEDS 2024 page
# and processes their Excel workbooks into the database

library(httr)
library(readxl)
library(DBI)
library(duckdb)
library(rappdirs)

# Source the database management functions
source("R/database_management.R")

# Setup paths
downloads_dir <- get_ipeds_downloads_path()

# All 13 dictionary files found by our regex scraping
dict_files <- c(
    "HD2024_Dict.zip",
    "IC2024_Dict.zip", 
    "FLAGS2024_Dict.zip",
    "EFFY2024_Dict.zip",
    "EFFY2024_DIST_Dict.zip",
    "EFFY2024_HS_Dict.zip",
    "EFIA2024_Dict.zip",
    "C2024_A_Dict.zip",
    "C2024_B_Dict.zip",
    "C2024_C_Dict.zip",
    "C2024DEP_Dict.zip",
    "DRVEF122024_Dict.zip",
    "DRVC2024_Dict.zip"
)

# Base URL for IPEDS dictionary files
base_url <- "https://nces.ed.gov/ipeds/datacenter/data/"

# Function to download a dictionary file if it doesn't exist
download_dict_file <- function(filename) {
    local_path <- file.path(downloads_dir, filename)
    
    # Skip if already downloaded
    if (file.exists(local_path)) {
        cat("Already exists:", filename, "\n")
        return(local_path)
    }
    
    url <- paste0(base_url, filename)
    cat("Downloading:", filename, "from", url, "\n")
    
    response <- GET(url, write_disk(local_path, overwrite = TRUE))
    
    if (status_code(response) == 200) {
        cat("Downloaded successfully:", filename, "\n")
        return(local_path)
    } else {
        cat("Failed to download:", filename, "Status:", status_code(response), "\n")
        return(NULL)
    }
}

# Function to extract and process Excel workbook from ZIP
process_dict_zip <- function(zip_path) {
    if (is.null(zip_path) || !file.exists(zip_path)) {
        return(NULL)
    }
    
    filename <- basename(zip_path)
    cat("\nProcessing:", filename, "\n")
    
    # Create temporary directory for extraction
    temp_dir <- tempdir()
    extract_dir <- file.path(temp_dir, gsub("\\.zip$", "", filename))
    dir.create(extract_dir, recursive = TRUE, showWarnings = FALSE)
    
    # Extract ZIP file
    unzip(zip_path, exdir = extract_dir)
    
    # Find Excel file (should be .xlsx)
    excel_files <- list.files(extract_dir, pattern = "\\.xlsx$", full.names = TRUE)
    
    if (length(excel_files) == 0) {
        cat("No Excel file found in", filename, "\n")
        return(NULL)
    }
    
    excel_file <- excel_files[1]
    cat("Found Excel file:", basename(excel_file), "\n")
    
    # Get all sheet names
    sheet_names <- excel_sheets(excel_file)
    cat("Worksheets:", paste(sheet_names, collapse = ", "), "\n")
    
    # Read the worksheets we're interested in
    result <- list()
    
    # Look for Varlist worksheet (maps to vartable24)
    if ("Varlist" %in% sheet_names) {
        cat("Reading Varlist worksheet...\n")
        result$vartable <- read_excel(excel_file, sheet = "Varlist")
        cat("Varlist has", nrow(result$vartable), "rows and", ncol(result$vartable), "columns\n")
    }
    
    # Look for Description worksheet (maps to valuesets24)  
    if ("Description" %in% sheet_names) {
        cat("Reading Description worksheet...\n")
        result$valuesets <- read_excel(excel_file, sheet = "Description")
        cat("Description has", nrow(result$valuesets), "rows and", ncol(result$valuesets), "columns\n")
    }
    
    # Look for Frequencies worksheet (alternative to valuesets)
    if ("Frequencies" %in% sheet_names && is.null(result$valuesets)) {
        cat("Reading Frequencies worksheet...\n")
        result$valuesets <- read_excel(excel_file, sheet = "Frequencies")
        cat("Frequencies has", nrow(result$valuesets), "rows and", ncol(result$valuesets), "columns\n")
    }
    
    # Clean up temp directory
    unlink(extract_dir, recursive = TRUE)
    
    return(result)
}

# Connect to database
cat("Connecting to DuckDB database...\n")
con <- get_ipeds_connection(read_only = FALSE)

# Download and process all dictionary files
all_vartable_data <- list()
all_valuesets_data <- list()

cat("Starting download and processing of", length(dict_files), "dictionary files...\n\n")

for (dict_file in dict_files) {
    cat(paste(rep("=", 60), collapse=""), "\n")
    cat("Processing:", dict_file, "\n")
    cat(paste(rep("=", 60), collapse=""), "\n")
    
    # Download the file
    zip_path <- download_dict_file(dict_file)
    
    # Process the ZIP file
    data <- process_dict_zip(zip_path)
    
    if (!is.null(data)) {
        # Store data for later database insertion
        file_prefix <- gsub("_Dict\\.zip$", "", dict_file)
        
        if (!is.null(data$valuesets)) {
            all_valuesets_data[[file_prefix]] <- data$valuesets
        }
        if (!is.null(data$vartable)) {
            all_vartable_data[[file_prefix]] <- data$vartable
        }
    }
    
    cat("\n")
}

# Now combine all data and write to database
cat(paste(rep("=", 60), collapse=""), "\n")
cat("Writing combined data to database...\n")
cat(paste(rep("=", 60), collapse=""), "\n")

# Combine all valuesets data
if (length(all_valuesets_data) > 0) {
    cat("Combining", length(all_valuesets_data), "valuesets datasets...\n")
    
    # Add source column to each dataset
    for (prefix in names(all_valuesets_data)) {
        all_valuesets_data[[prefix]]$source_file <- prefix
    }
    
    # Combine all valuesets data
    combined_valuesets <- do.call(rbind, all_valuesets_data)
    
    cat("Combined valuesets has", nrow(combined_valuesets), "rows\n")
    
    # Write to database
    dbWriteTable(con, "valuesets24", combined_valuesets, overwrite = TRUE)
    cat("Written valuesets24 to database\n")
}

# Combine all vartable data
if (length(all_vartable_data) > 0) {
    cat("Combining", length(all_vartable_data), "vartable datasets...\n")
    
    # Add source column to each dataset
    for (prefix in names(all_vartable_data)) {
        all_vartable_data[[prefix]]$source_file <- prefix
    }
    
    # Combine all vartable data
    combined_vartable <- do.call(rbind, all_vartable_data)
    
    cat("Combined vartable has", nrow(combined_vartable), "rows\n")
    
    # Write to database
    dbWriteTable(con, "vartable24", combined_vartable, overwrite = TRUE)
    cat("Written vartable24 to database\n")
}

# Summary
cat("\n")
cat(paste(rep("=", 60), collapse=""), "\n")
cat("SUMMARY\n")
cat(paste(rep("=", 60), collapse=""), "\n")
cat("Processed", length(dict_files), "dictionary files\n")
cat("Found valuesets data in", length(all_valuesets_data), "files\n") 
cat("Found vartable data in", length(all_vartable_data), "files\n")

# Check what we have in the database now
tables_list <- dbListTables(con)
dict_tables <- grep("24$", tables_list, value = TRUE)
cat("Dictionary tables in database:", paste(dict_tables, collapse = ", "), "\n")

# Show row counts
for (table in dict_tables) {
    count <- dbGetQuery(con, paste("SELECT COUNT(*) as count FROM", table))$count
    cat(table, ":", count, "rows\n")
}

dbDisconnect(con)
cat("\nProcessing complete!\n")