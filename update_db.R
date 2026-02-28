library(tidyverse)
library(IPEDSR)
library(DBI)

# pick a year to update
year <- 2024 # 2024-25
ipeds_index <- ipeds_dl_index(year)
load_ipeds_index_to_duckdb(ipeds_index) # uses default duckdb path

# a new year needs new index files
# these aren't as complete as the ones from Access
write_ipeds_tables_meta(ipeds_index)

# overwrite the provisional data from the previous year# pick a year to update
year <- 2023
ipeds_index <- ipeds_dl_index(year)
load_ipeds_index_to_duckdb(ipeds_index) # uses default duckdb path


# test it
idbc <- IPEDSR::get_ipeds_connection()
ret <- IPEDSR::get_retention(idbc, 218070)

# get tables in the db starting with "Tables"
dbListTables(idbc) |>
  str_subset("^Tables")

tbl(idbc,"Tables24") |> collect() -> tdf
