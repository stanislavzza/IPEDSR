library(tidyverse)
library(IPEDSR)
library(DBI)

# pick a year to update
year <- 2024 # 2024-25
ipeds_index <- ipeds_dl_index(year)
load_ipeds_index_to_duckdb(ipeds_index) # uses default duckdb path

# write the tables meta data
write_ipeds_tables_meta(ipeds_index)

# the vars and codes
build_dictionary_metadata(ipeds_index)

# overwrite the provisional data from the previous year# pick a year to update
year <- 2023
ipeds_index <- ipeds_dl_index(year)
load_ipeds_index_to_duckdb(ipeds_index) # uses default duckdb path


# test it
idbc <- IPEDSR::get_ipeds_connection()
ret <- IPEDSR::get_retention(idbc, 218070)

# get tables in the db starting with "Tables"
dbListTables(idbc) |>
  str_subset("^HD")

tbl(idbc,"Tables24") |> collect() -> tdf

dbListTables(idbc) |>
  str_subset("^values")

tbl(idbc,"valuesets24") |> collect() -> tdf

dbListTables(idbc) |>
  str_subset("^var")

tbl(idbc,"vartable24") |> collect() -> tdf
