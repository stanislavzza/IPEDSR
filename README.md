# IPEDSR

A comprehensive R package for IPEDS (Integrated Postsecondary Education Data System) data management and analysis, designed for Institutional Research professionals.

## Overview

IPEDSR provides institutional researchers with a complete, production-ready data management system for IPEDS data. Beyond basic data access, it includes automated data updates, comprehensive validation, version tracking, and quality assurance—everything needed for reliable, up-to-date institutional research.

### 🚀 Key Features

#### **Automated Data Management**
- **Smart Data Updates**: Automatically detect and download new IPEDS releases from NCES
- **Version Tracking**: Complete audit trail of data changes with schema comparison
- **Backup & Recovery**: Automatic backups before updates with one-click restore
- **Data Validation**: Multi-level quality checks with detailed reporting

#### **Comprehensive Data Access**
- **20+ Years of Data**: IPEDS data from 2004-present with 939+ tables
- **DuckDB Backend**: High-performance database with intelligent caching
- **Modern R Interface**: Tidyverse-friendly functions with consistent naming
- **Web Scraping**: Direct integration with NCES data center for latest releases

#### **Production-Ready Tools**
- **One-Command Interface**: `ipeds_data_manager()` for all operations
- **Integration Testing**: Complete test suite ensuring system reliability
- **Error Handling**: Robust error recovery and detailed logging
- **Performance Optimization**: Efficient processing of large datasets

## Installation

### From GitHub (Recommended)

```r
# Install devtools if you haven't already
install.packages("devtools")

# Install IPEDSR from GitHub
devtools::install_github("stanislavzza/IPEDSR")
```

### Dependencies

The package will automatically install required dependencies:
- DBI
- duckdb
- dplyr
- magrittr
- rappdirs
- stringr
- tibble
- tidyr

## Installation

### From GitHub (Recommended)

```r
# Install devtools if you haven't already
install.packages("devtools")

# Install IPEDSR from GitHub
devtools::install_github("stanislavzza/IPEDSR")
```

### Dependencies

The package automatically installs required dependencies:
- **Core**: DBI, duckdb, dplyr, magrittr, tibble, tidyr, stringr
- **Web**: rvest, httr, xml2 (for automated data updates)
- **Utilities**: rappdirs, digest (for caching and integrity checks)

## 🎯 Quick Start Guide

### 1. Basic Data Access (Traditional Workflow)

```r
library(IPEDSR)

# Get institutional characteristics for Furman University (2023)
furman_chars <- get_characteristics(year = 2023, UNITIDs = 218070)

# Get financial data for multiple institutions
finances <- get_finances(UNITIDs = c(218070, 139755, 190150))

# Get graduation rates
grad_rates <- get_grad_rates(UNITIDs = 218070)
```

### 2. Modern Data Management (New Capabilities)

```r
# Check for latest IPEDS data releases
ipeds_data_manager("check_updates")

# Download and process latest data
ipeds_data_manager("download")

# Validate data quality and integrity
ipeds_data_manager("validate")

# Get system status and health
ipeds_data_manager("status")

# Quick update workflow (check → download → validate)
quick_update()
```

### 3. Get Help and Learn

```r
# Comprehensive help system
ipeds_data_manager("help")

# Run system tests to verify everything works
run_integration_tests()
```

## 📊 Data Management System

### Automated Updates

IPEDSR now includes a sophisticated data management system that:

1. **Monitors NCES Website**: Automatically checks for new IPEDS releases
2. **Smart Downloads**: Fetches only new or updated files
3. **Version Control**: Tracks all changes with complete audit trails
4. **Quality Assurance**: Validates data integrity before and after updates
5. **Safe Operations**: Creates backups before any major changes

#### Check for Updates

```r
# Check what's new on IPEDS website
ipeds_data_manager("check_updates")

# Check for specific year
ipeds_data_manager("check_updates", year = 2024)
```

#### Download Latest Data

```r
# Download all available updates
ipeds_data_manager("download")

# Download specific year or survey components
ipeds_data_manager("download", year = 2023)
ipeds_data_manager("download", year = 2023, tables = c("HD", "IC"))
```

#### Data Validation

```r
# Basic validation (quick)
ipeds_data_manager("validate", validation_level = "basic")

# Standard validation (recommended)
ipeds_data_manager("validate", validation_level = "standard")

# Comprehensive validation (thorough)
ipeds_data_manager("validate", validation_level = "comprehensive")

# Validate specific tables
ipeds_data_manager("validate", tables = c("HD2023", "IC2023"))
```

### Backup & Recovery

```r
# Create backup
ipeds_data_manager("backup")

# Restore from backup (interactive)
ipeds_data_manager("restore")

# Get system status
ipeds_data_manager("status")
```

### Integration Testing

```r
# Run complete test suite
test_results <- run_integration_tests()

# Quick test mode (faster)
test_results <- run_integration_tests(quick_mode = TRUE)

# Test specific year
test_results <- run_integration_tests(test_year = 2023)
```

## 📖 Available Functions

### 🎛️ Data Management Interface

- `ipeds_data_manager(action, ...)` - **Main interface for all data operations**
  - `"check_updates"` - Check for new IPEDS releases
  - `"download"` - Download and process latest data
  - `"validate"` - Validate data quality and integrity  
  - `"status"` - Show database status and health
  - `"backup"` - Create database backup
  - `"restore"` - Restore from backup
  - `"help"` - Show comprehensive help

- `quick_update(year, validate)` - **One-command update workflow**
- `run_integration_tests(quick_mode)` - **System validation and testing**

### 🏛️ Institutional Data Functions

### Institutional Characteristics
- `get_characteristics(year, UNITIDs)` - Basic institutional information

### Financial Data
- `get_finances(UNITIDs)` - Comprehensive financial data
- `get_tuition(UNITIDs)` - Tuition and fees information

### Student Outcomes
- `get_grad_rates(UNITIDs)` - Graduation rates
- `get_grad_demo_rates(UNITIDs)` - Graduation rates by demographics
- `get_grad_pell_rates(UNITIDs)` - Graduation rates by Pell status
- `get_retention(UNITIDs)` - Retention rates
- `get_cohort_stats(UNITIDs)` - Comprehensive cohort analysis

### Enrollment & Admissions
- `ipeds_get_enrollment(UNITIDs, StudentTypeCode)` - Enrollment data
- `get_admit_funnel(UNITIDs)` - Admissions funnel analysis

### Personnel
- `get_faculty(UNITIDs, before_2011)` - Faculty counts and demographics
- `get_employees(UNITIDs)` - Employee information
- `get_ipeds_faculty_salaries(UNITIDs, years)` - Faculty salary data

### Academic Programs
- `get_cips(UNITIDs, cip_codes, years)` - Completions by CIP code
- `get_cipcodes(digits)` - CIP code lookup
- `get_cip2_counts(awlevel, UNITIDs, first_only)` - CIP 2-digit summaries
- `get_ipeds_completions(UNITIDs)` - Degree completions

### Financial Aid
- `get_fa_info(UNITIDs)` - Financial aid information

### Utility Functions
- `find_unitids(search_string)` - Find institution UNITIDs
- `get_variables(year, table_name)` - Variable definitions
- `get_valueset(table_name, variable_name)` - Value labels
- `my_dbListTables(search_string)` - List available tables

## 💡 Examples

### Modern Workflow: Keep Your Data Current

```r
library(IPEDSR)

# Step 1: Check what's new
ipeds_data_manager("check_updates")
# ✅ Found 12 potential updates for 2024 data

# Step 2: Download latest data (with automatic backup)
ipeds_data_manager("download")
# 📥 Downloading 12 files...
# 💾 Creating backup...
# 📊 Updating database...
# ✅ Download complete!

# Step 3: Validate data quality
ipeds_data_manager("validate")
# 🔍 Running validation...
# ✅ All checks passed!

# Or do it all in one command
quick_update()
```

### Traditional Analysis: Use the Data

```r
# Find your institution
find_unitids("Furman")
#> UNITID      INSTNM
#> 218070     Furman University

# Define peer institutions
peer_unitids <- c(
  218070,  # Furman University
  139755,  # Davidson College
  190150   # Wake Forest University
)

# Compare graduation rates
peer_grad_rates <- get_grad_rates(peer_unitids)

# Compare financial data
peer_finances <- get_finances(peer_unitids)

# Get institutional characteristics for context
peer_chars <- get_characteristics(2023, peer_unitids)
```

### Advanced Data Management

```r
# Check system health
ipeds_data_manager("status")
# 📊 IPEDS Database Status
# Database Tables:
#   IPEDS data tables: 945
#   Metadata tables: 3
#   Total tables: 948
# 
# Version Information:
#   2024: 156 tables (last updated: 2024-10-08)
#   2023: 145 tables (last updated: 2024-09-15)

# Validate specific tables with comprehensive checks
ipeds_data_manager("validate", 
                   tables = c("HD2024", "IC2024"), 
                   validation_level = "comprehensive")

# Create backup before major analysis
ipeds_data_manager("backup")
# ✅ Backup created successfully
# Latest backup: ipeds_backup_20241008_143022.duckdb
# Location: /Users/username/Library/Application Support/IPEDSR/backups

# Test system integrity
test_results <- run_integration_tests()
# ✅ All systems operational!
```

### Analyze Trends Over Time

```r
# Get financial trends for your institution
finances <- get_finances(218070)
library(ggplot2)

# Plot endowment growth
finances %>%
  ggplot(aes(x = Year, y = Endowment)) +
  geom_line() +
  geom_point() +
  labs(title = "Endowment Growth Over Time",
       y = "Endowment ($)")
```

### Data Quality Validation

```r
# Run comprehensive validation on your key tables
validation_results <- validate_ipeds_data(
  tables = c("HD2024", "IC2024", "EF2024"), 
  validation_level = "comprehensive"
)

# View validation summary
print(validation_results$summary)

# Check recommendations
validation_results$recommendations
```

### Working with Latest Data

```r
# Always work with the most current data
ipeds_data_manager("check_updates")

# If updates are available, download them
if (length(check_ipeds_updates()) > 0) {
  quick_update()
}

# Now proceed with analysis knowing you have the latest data
current_data <- get_characteristics(year = 2024, UNITIDs = your_unitids)
```

## 🔧 System Architecture

### How It Works

IPEDSR now operates as a complete data management ecosystem:

1. **Web Monitoring**: Continuously monitors NCES website for new releases
2. **Smart Downloads**: Fetches only new or changed files with retry logic
3. **Data Processing**: Automatically cleans, validates, and imports data
4. **Version Control**: Tracks all changes with complete audit trails
5. **Quality Assurance**: Multi-level validation ensures data integrity
6. **Backup System**: Automatic backups before any major operations

### Database Location

The database is stored in your system's user data directory:
- **macOS**: `~/Library/Application Support/IPEDSR/`
- **Windows**: `%APPDATA%/IPEDSR/`
- **Linux**: `~/.local/share/IPEDSR/`

### Data Validation Levels

- **Basic**: Essential checks (table exists, not empty, basic schema)
- **Standard**: Comprehensive checks (UNITID validation, duplicates, null analysis)
- **Comprehensive**: Full validation suite (cross-year comparison, referential integrity, outlier detection)

## 🎛️ Configuration & Settings

### Interactive vs Non-Interactive Mode

```r
# Interactive mode (default) - prompts for confirmation
ipeds_data_manager("download")

# Non-interactive mode - runs automatically
ipeds_data_manager("download", interactive = FALSE)
```

### Validation Preferences

```r
# Set default validation level
ipeds_data_manager("validate", validation_level = "comprehensive")

# Validate specific survey components
ipeds_data_manager("validate", tables = c("HD", "IC", "EF"))
```

## 📊 Data Coverage

The database contains IPEDS data from **2004-present** including:

- **Institutional Characteristics** (HD, IC tables)
- **Admissions** (ADM tables) 
- **Enrollment** (EF tables)
- **Completions** (C tables)
- **Graduation Rates** (GR tables)
- **Student Financial Aid** (SFA tables)
- **Finance** (F tables)
- **Human Resources** (HR, S, SAL, EAP tables)
- **Academic Libraries** (AL tables)

**Total**: 945+ tables across 20+ years of data, **automatically updated** as new releases become available.

## ⚡ Performance Tips

1. **Keep Data Current**: Use `quick_update()` regularly to ensure latest data
2. **Validate Regularly**: Run validation after updates to catch issues early
3. **Filter Early**: Use UNITIDs parameter to limit data retrieval
4. **Cache Results**: Store frequently-used results in variables
5. **Batch Queries**: Request multiple institutions at once rather than looping
6. **Use Specific Functions**: Choose the most specific function for your needs
7. **Monitor System Health**: Check `ipeds_data_manager("status")` periodically

## 🔧 Troubleshooting

### Data Update Issues

If data updates fail:

```r
# Check system status first
ipeds_data_manager("status")

# Try updating specific year
ipeds_data_manager("download", year = 2024)

# Run validation to check for issues
ipeds_data_manager("validate", validation_level = "comprehensive")

# Check integration tests
run_integration_tests()
```

### Database Issues

For database problems:

```r
# Create backup before troubleshooting
ipeds_data_manager("backup")

# Check database connection
test_results <- run_integration_tests(quick_mode = TRUE)

# Restore from backup if needed
ipeds_data_manager("restore")
```

### Performance Issues

For slow operations:
- Use `validation_level = "basic"` for faster validation
- Limit UNITIDs to institutions of interest
- Use `quick_mode = TRUE` for faster testing
- Consider breaking large requests into smaller chunks

### Validation Failures

When validation finds issues:

```r
# Get detailed validation results
results <- validate_ipeds_data(validation_level = "comprehensive")

# Review recommendations
results$recommendations

# Check specific problematic tables
problematic_tables <- results$summary[results$summary$overall_status == "fail", ]
```

## 📚 Getting Help

### Package Documentation

```r
# Main interface help
?ipeds_data_manager

# Traditional function help
?get_characteristics
?get_finances
?find_unitids

# Get comprehensive help
ipeds_data_manager("help")
```

### System Diagnostics

```r
# Check if everything is working
run_integration_tests()

# Quick system check
run_integration_tests(quick_mode = TRUE)

# Check specific year
run_integration_tests(test_year = 2024)
```

### IPEDS Resources

- [IPEDS Data Center](https://nces.ed.gov/ipeds/datacenter/)
- [IPEDS Survey Components](https://nces.ed.gov/ipeds/use-the-data/survey-components)
- [IPEDS Glossary](https://surveys.nces.ed.gov/ipeds/VisGlossaryAll.aspx)
- [IPEDS Data Files](https://nces.ed.gov/ipeds/datacenter/DataFiles.aspx) (monitored automatically by IPEDSR)

### Package Support

For bugs, feature requests, or questions:
- **GitHub Issues**: [https://github.com/stanislavzza/IPEDSR/issues](https://github.com/stanislavzza/IPEDSR/issues)
- **Documentation**: Use `ipeds_data_manager("help")` for built-in help
- **System Health**: Run `run_integration_tests()` to diagnose issues

## 🚀 What's New in v2.0

### Major Features Added
- ✅ **Automated Data Updates**: Direct integration with NCES website
- ✅ **Data Management Interface**: `ipeds_data_manager()` for all operations
- ✅ **Comprehensive Validation**: Multi-level data quality checks
- ✅ **Version Tracking**: Complete audit trail of all changes
- ✅ **Backup & Recovery**: Safe operations with automatic backups
- ✅ **Integration Testing**: Complete system validation framework
- ✅ **Performance Optimization**: Faster processing and better error handling

### Migration from v1.x
Existing v1.x code continues to work unchanged. New features are additive:

```r
# v1.x style (still works)
data <- get_characteristics(2023, c(218070, 139755))

# v2.0 style (recommended for new workflows)
ipeds_data_manager("check_updates")
quick_update()
data <- get_characteristics(2023, c(218070, 139755))
```

## 📄 License

This package is licensed under the MIT License. IPEDS data is public domain.

## 📖 Citation

```r
# Generate citation
citation("IPEDSR")
```

## 🛠️ Development

IPEDSR v2.0 represents a complete evolution from a simple data access package to a comprehensive data management platform. The system is designed for institutional research professionals who need reliable, up-to-date, and validated IPEDS data for critical decision-making.

### Key Design Principles
- **Reliability**: Comprehensive testing and validation at every step
- **Automation**: Minimal manual intervention required
- **Safety**: Automatic backups and rollback capabilities  
- **Performance**: Optimized for large datasets and frequent use
- **Usability**: Both beginner-friendly and power-user capable

### Architecture Overview
The package consists of several integrated systems:
- **Web Scraping Engine**: Monitors NCES for new releases
- **Download Manager**: Handles file retrieval with retry logic
- **Data Processing Pipeline**: Cleans and imports data automatically
- **Validation Framework**: Multi-level quality assurance
- **Version Control System**: Tracks all changes and schema evolution
- **User Interface Layer**: Intuitive command interface
- **Testing Framework**: Comprehensive integration testing

### Version History

- **v2.0.0**: Complete data management platform with automated updates, validation, and version control
- **v1.x**: Basic data access with manual database management

---

**Note**: This package provides access to IPEDS data but is not affiliated with or endorsed by the National Center for Education Statistics or the U.S. Department of Education. IPEDSR enhances the IPEDS data experience through modern data management practices while maintaining full compliance with NCES data policies.