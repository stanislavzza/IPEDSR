# IPEDSR

An R package for easy access to IPEDS (Integrated Postsecondary Education Data System) data for Institutional Research professionals.

## Overview

The IPEDSR package provides institutional researchers with streamlined access to IPEDS data from 2004-2023. The package automatically manages a 2.4GB DuckDB database containing 939 tables of IPEDS data, eliminating the need for manual database setup or management.

### Key Features

- **Automatic Database Management**: No need to download, install, or configure databases
- **Comprehensive Data Coverage**: 20 years of IPEDS data (2004-2023) with 939 tables
- **Cloud-Based Storage**: Database automatically downloaded from Google Drive when needed
- **Modern R Interface**: Tidyverse-friendly functions with consistent naming
- **Institutional Research Focus**: Functions specifically designed for common IR analyses

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

## Quick Start

```r
library(IPEDSR)

# Get institutional characteristics for Furman University (2023)
furman_chars <- get_characteristics(year = 2023, UNITIDs = 218070)

# Get financial data for multiple institutions
finances <- get_finances(UNITIDs = c(218070, 139755, 190150))

# Get graduation rates
grad_rates <- get_grad_rates(UNITIDs = 218070)
```

## How It Works

### Automatic Database Setup

When you first use any function, IPEDSR automatically:

1. **Checks for existing database** in your user data directory
2. **Downloads the database** from Google Drive if needed (~52 seconds)
3. **Establishes connection** using DuckDB
4. **Caches the database** locally for future use

No manual intervention required!

### Data Location

The database is stored in your system's user data directory:
- **macOS**: `~/Library/Application Support/IPEDSR/`
- **Windows**: `%APPDATA%/IPEDSR/`
- **Linux**: `~/.local/share/IPEDSR/`

## Available Functions

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

## Examples

### Find Your Institution

```r
# Search for institutions by name
find_unitids("Furman")
find_unitids("Harvard")
find_unitids("University of California")
```

### Compare Institutions

```r
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

### Graduation Rate Analysis

```r
# Detailed graduation analysis
grad_data <- get_grad_rates(218070)
demo_grad <- get_grad_demo_rates(218070)
pell_grad <- get_grad_pell_rates(218070)

# Combine for comprehensive view
cohort_analysis <- get_cohort_stats(218070)
```

### Academic Program Analysis

```r
# Get completions by major program areas (2-digit CIP)
programs <- get_cip2_counts(awlevel = "05", UNITIDs = 218070)

# Look at specific CIP codes
business_degrees <- get_cips(UNITIDs = 218070, cip_codes = "52")
```

## Data Coverage

The database contains IPEDS data from **2004-2023** including:

- **Institutional Characteristics** (IC tables)
- **Admissions** (ADM tables) 
- **Enrollment** (EF tables)
- **Completions** (C tables)
- **Graduation Rates** (GR tables)
- **Student Financial Aid** (SFA tables)
- **Finance** (F tables)
- **Human Resources** (HR, S, SAL, EAP tables)
- **Academic Libraries** (AL tables)

Total: **939 tables** across 20 years of data.

## Database Management

### Check Database Status

```r
# Get database information
get_database_info()
```

### Manual Database Update

```r
# Force download of latest database
setup_ipeds_database(force_download = TRUE)
```

### Database Location

```r
# Find where your database is stored
rappdirs::user_data_dir("IPEDSR")
```

## Performance Tips

1. **Filter Early**: Use UNITIDs parameter to limit data retrieval
2. **Cache Results**: Store frequently-used results in variables
3. **Batch Queries**: Request multiple institutions at once rather than looping
4. **Use Specific Functions**: Choose the most specific function for your needs

## Troubleshooting

### Database Download Issues

If the initial download fails:

```r
# Try manual setup
setup_ipeds_database(force_download = TRUE)

# Check your internet connection and try again
```

### Performance Issues

For large queries:
- Limit UNITIDs to institutions of interest
- Use specific date ranges where available
- Consider breaking large requests into smaller chunks

### Memory Issues

For memory-intensive operations:
- Work with smaller subsets of data
- Use `dplyr::collect()` judiciously
- Clear large objects with `rm()` when done

## Getting Help

### Documentation

```r
# Get help for any function
?get_characteristics
?get_finances
?find_unitids
```

### IPEDS Resources

- [IPEDS Data Center](https://nces.ed.gov/ipeds/datacenter/)
- [IPEDS Survey Components](https://nces.ed.gov/ipeds/use-the-data/survey-components)
- [IPEDS Glossary](https://surveys.nces.ed.gov/ipeds/VisGlossaryAll.aspx)

### Package Issues

For bugs or feature requests, please visit: [GitHub Issues](https://github.com/stanislavzza/IPEDSR/issues)

## License

This package is licensed under the MIT License. IPEDS data is public domain.

## Citation

```r
# Generate citation
citation("IPEDSR")
```

## Development

This package was developed for institutional research professionals to simplify access to IPEDS data. The automatic database management eliminates common barriers to IPEDS data analysis, allowing researchers to focus on insights rather than data wrangling.

### Version History

- **v2.0.0**: Major refactor with automatic database management
- **v1.x**: Previous versions with manual database setup

---

**Note**: This package provides access to IPEDS data but is not affiliated with or endorsed by the National Center for Education Statistics or the U.S. Department of Education.