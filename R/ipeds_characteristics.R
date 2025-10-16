#' Get institutional characteristics for a single year
#' @param idbc A database connector
#' @param year The year to get, or NULL (default) for the most recent year
#' @param UNITIDs optional array of UNITIDs to filter to
#' @param labels if TRUE, replace column names and cell entries with their
#' labels. If FALSE, return the raw data.
#' @return a dataframe with institutional characteristics
#' @export
#' @details Apparently these tables include 'blob' columns that won't allow downloading
#' of the full thing. See https://github.com/r-dbi/odbc/issues/309.
#' So we have to select around those.
get_characteristics <- function(idbc, year = NULL, UNITIDs = NULL, labels = TRUE){

  # find all the tables
  #tnames <- odbc::dbListTables(idbc, table_name = "hd%")
  tnames <- my_dbListTables(idbc, search_string = "^HD\\d{4}$")
  years_available <- as.integer(substr(tnames, 3,6))

  # get the most recent year unless otherwise specified
  if(is.null(year)) {
    tname <- max(tnames)
  } else {
    # check if the year is valid
    if(!year %in% years_available) {
      stop(str_c("Invalid year specified. Available: ",str_c(years_available, collapse = ", ")))
    }

    # check if the year is in the table names
    tname <- paste0("HD", year)
  }

  if(labels == TRUE){
    ipeds_df <- get_ipeds_table(idbc, tname, str_sub(tname,5,6), UNITIDs)
  } else {
    ipeds_df <- tbl(idbc, tname)
    if(!is.null(UNITIDs)) ipeds_df <- ipeds_df %>% filter(UNITID %in% !!UNITIDs)
    # pull the data from the database
    ipeds_df <- ipeds_df |>
      collect()
  }

  return(ipeds_df)
}
