# DOWNLOAD AND PROCESS 2024 DICTIONARY FILES
# Download ZIP files, extract Excel workbooks, read worksheets, import to database

cat("=== DOWNLOADING AND PROCESSING 2024 DICTIONARY FILES ===\n")

library(IPEDSR)
library(readxl)  # For reading Excel files

# Available dictionary URLs (from previous test)
available_dict_urls <- c(
  "https://nces.ed.gov/ipeds/datacenter/data/DRVC2024_Dict.zip",
  "https://nces.ed.gov/ipeds/datacenter/data/DRVEF122024_Dict.zip", 
  "https://nces.ed.gov/ipeds/datacenter/data/EFFY2024_Dict.zip",
  "https://nces.ed.gov/ipeds/datacenter/data/EFIA2024_Dict.zip",
  "https://nces.ed.gov/ipeds/datacenter/data/FLAGS2024_Dict.zip",
  "https://nces.ed.gov/ipeds/datacenter/data/HD2024_Dict.zip",
  "https://nces.ed.gov/ipeds/datacenter/data/IC2024_Dict.zip"
)

# Setup download directory
downloads_dir <- rappdirs::user_data_dir("IPEDSR", "IPEDSR")
downloads_path <- file.path(downloads_dir, "downloads")
if (!dir.exists(downloads_path)) {
  dir.create(downloads_path, recursive = TRUE)
}

cat("\n1. DOWNLOADING DICTIONARY ZIP FILES:\n")
cat("Download directory:", downloads_path, "\n")

downloaded_files <- character(0)

for (url in available_dict_urls) {
  filename <- basename(url)
  local_path <- file.path(downloads_path, filename)
  
  cat("Downloading", filename, "...")
  
  tryCatch({
    # Download the ZIP file
    httr::GET(url, httr::write_disk(local_path, overwrite = TRUE))
    
    if (file.exists(local_path) && file.size(local_path) > 0) {
      cat(" ✅ SUCCESS (", file.size(local_path), "bytes)\n")
      downloaded_files <- c(downloaded_files, local_path)
    } else {
      cat(" ❌ FAILED\n")
    }
    
  }, error = function(e) {
    cat(" ❌ ERROR:", e$message, "\n")
  })
}

cat("\nDownloaded", length(downloaded_files), "dictionary ZIP files\n")

if (length(downloaded_files) == 0) {
  cat("❌ No files downloaded. Stopping.\n")
  stop("No dictionary files downloaded")
}

cat("\n2. EXTRACTING AND PROCESSING EXCEL WORKBOOKS:\n")

# Initialize storage for dictionary data
all_tables_data <- data.frame()
all_valuesets_data <- data.frame()
all_vartable_data <- data.frame()

for (zip_path in downloaded_files) {
  zip_filename <- basename(zip_path)
  component <- gsub("2024_Dict\\.zip$", "", zip_filename)
  
  cat("\nProcessing", zip_filename, "(", component, ")...\n")
  
  # Create temporary directory for extraction
  temp_dir <- tempfile()
  dir.create(temp_dir)
  
  tryCatch({
    # Extract ZIP file
    utils::unzip(zip_path, exdir = temp_dir)
    
    # Look for Excel files in extracted content
    excel_files <- list.files(temp_dir, pattern = "\\.(xlsx?|xls)$", 
                              recursive = TRUE, full.names = TRUE)
    
    if (length(excel_files) == 0) {
      cat("  ❌ No Excel files found in ZIP\n")
      next
    }
    
    cat("  Found", length(excel_files), "Excel file(s)\n")
    
    for (excel_file in excel_files) {
      cat("  Processing Excel file:", basename(excel_file), "\n")
      
      # Get worksheet names
      sheet_names <- readxl::excel_sheets(excel_file)
      cat("    Worksheets:", paste(sheet_names, collapse = ", "), "\n")
      
      # Look for Tables, valuesets, vartable worksheets
      for (sheet in sheet_names) {
        sheet_lower <- tolower(sheet)
        
        cat("    Reading worksheet:", sheet, "...")
        
        tryCatch({
          # Read the worksheet
          sheet_data <- readxl::read_excel(excel_file, sheet = sheet)
          
          if (nrow(sheet_data) == 0) {
            cat(" EMPTY\n")
            next
          }
          
          cat(" SUCCESS (", nrow(sheet_data), "rows,", ncol(sheet_data), "cols)\n")
          
          # Determine which dictionary table this belongs to
          if (grepl("tables?", sheet_lower)) {
            # This is a Tables worksheet
            cat("      → Adding to Tables data\n")
            all_tables_data <- rbind(all_tables_data, sheet_data)
            
          } else if (grepl("valuesets?", sheet_lower)) {
            # This is a valuesets worksheet
            cat("      → Adding to valuesets data\n")
            all_valuesets_data <- rbind(all_valuesets_data, sheet_data)
            
          } else if (grepl("vartables?|variables?", sheet_lower)) {
            # This is a vartable worksheet
            cat("      → Adding to vartable data\n")
            all_vartable_data <- rbind(all_vartable_data, sheet_data)
            
          } else {
            cat("      → Unknown worksheet type, skipping\n")
          }
          
        }, error = function(e) {
          cat(" ERROR:", e$message, "\n")
        })
      }
    }
    
  }, error = function(e) {
    cat("  ❌ Error processing ZIP:", e$message, "\n")
  }, finally = {
    # Clean up temp directory
    unlink(temp_dir, recursive = TRUE)
  })
}

cat("\n3. SUMMARY OF EXTRACTED DATA:\n")
cat("Tables data:", nrow(all_tables_data), "rows,", ncol(all_tables_data), "columns\n")
cat("valuesets data:", nrow(all_valuesets_data), "rows,", ncol(all_valuesets_data), "columns\n") 
cat("vartable data:", nrow(all_vartable_data), "rows,", ncol(all_vartable_data), "columns\n")

# Show column names for verification
if (nrow(all_tables_data) > 0) {
  cat("\nTables columns:", paste(names(all_tables_data), collapse = ", "), "\n")
}
if (nrow(all_valuesets_data) > 0) {
  cat("valuesets columns:", paste(names(all_valuesets_data), collapse = ", "), "\n")
}
if (nrow(all_vartable_data) > 0) {
  cat("vartable columns:", paste(names(all_vartable_data), collapse = ", "), "\n")
}

cat("\n=== EXTRACTION COMPLETE ===\n")
cat("Ready to import to database as tables24, valuesets24, vartable24\n")