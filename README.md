# IPEDSR

An R package for downloading and using data from (Integrated Postsecondary Education Data System) and other
sources of data on higher education. 

## Overview

IPEDSR provides researchers with a set of tools for quickly using institutional data for analysis. The data is downloaded
as a single duckdb database file stored in the user's application data directory (or wherever you like). The main use of
the package is retrieving institutional data for one or more institutions using their UNITID codes. 

### Key Features

#### **Data Access**
- **IPEDS data since 2004**: IPEDS data from 2004-present with 958+ tables. 
- **DAPIP** Access to DAPIP data on postsecondary accreditors and accreditation status of institutions and programs.
- **PSEO** Access to Postsecondary Employement Outcomes (PSEO) data on earnings of graduates.
- **Planned Expansion**: College Scorecard data and inflation indices coming soon. 
- **DuckDB Backend**: High-performance database with intelligent caching
- **Modern R Interface**: Tidyverse-friendly functions with consistent naming, to retrieve institutional characteristics, cohorts, completions, salaries, and more. A single query produces longitudinal data for specified (or all) years and institutions. 


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
- **Web**: rvest, httr

## Quick Start Guide

```r
# Download the database
library(tidyverse)
library(IPEDSR)

# OPTIONAL - set a custom path for the database file
IPEDSR::set_ipeds_db_path("~/user/ipeds_data") # change to your path

# if skipped, it chooses a default location
IPEDSR::download_ipeds_database() # repeat when new versions are available

# Test it by retrieving Harvard presidents
idbc <- IPEDSR::get_ipeds_connection()

# Find all the presidents of Harvard since 2006
presidents <- data.frame()
for(year in 2006:2023){
  tdf <- IPEDSR::get_characteristics(idbc, year) |> 
              select(School = 2, President = 9) |> 
              mutate(Year = year) |> 
              filter(School == "Harvard University")
  
  presidents <- bind_rows(presidents, tdf)
}

print(presidents)
```
You can find related R projects on the ThIRsdays site [here](https://www.reddit.com/r/ThIRsdays/comments/1kfdv2l/thirsdays_schedule/).
