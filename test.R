library(tidyverse)
library(DBI)
library(duckdb)
library(IPEDSR)

# ipeds database connector -- change the path to your db
idbc <- duckdb::dbConnect(duckdb(), 
                          dbdir = "data/ipeds.duckdb", 
                          read_only = TRUE)

# get the list of tables
ipeds_tables <- duckdb::dbListTables(idbc, table_type = "TABLE")

# View a few rows of the header
tbl(idbc, "HD2023") |>
  select(UNITID, INSTNM, CITY, STABBR) |>
  head(10) |>
  collect()  # Collect pulls the data into R as a regular dataframe

