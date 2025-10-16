#' Get institutional characteristics for a single year
#' @param year The year to get, or NULL (default) for the most recent year
#' @param UNITIDs optional array of UNITIDs to filter to. If NULL, uses configured default_unitid.
#' @param labels if TRUE, replace column names and cell entries with their
#' labels. If FALSE, return the raw data.
#' @return a dataframe with institutional characteristics
#' @export
#' @details Automatically manages database connection and setup.
#' If UNITIDs is not provided, the function will use the default_unitid from your configuration.
#' Set this with: set_ipedsr_config(default_unitid = YOUR_UNITID)
get_characteristics <- function(year = NULL, UNITIDs = NULL, labels = TRUE){
  
  # Use configured default UNITID if none provided
  if (is.null(UNITIDs)) {
    UNITIDs <- get_default_unitid()
  }

  # Use survey registry to get directory tables
  hd_pattern <- get_survey_pattern("directory")
  tnames <- my_dbListTables(search_string = hd_pattern)
  years_available <- as.integer(substr(tnames, 3,6))

  # get the most recent year unless otherwise specified
  if(is.null(year)) {
    tname <- max(tnames)
  } else {
    # check if the year is valid
    if(!year %in% years_available) {
      stop(stringr::str_c("Invalid year specified. Available: ", stringr::str_c(years_available, collapse = ", ")))
    }

    # check if the year is in the table names
    tname <- paste0("hd", year)
  }

  if(labels == TRUE){
    ipeds_df <- get_ipeds_table(tname, stringr::str_sub(tname,5,6), UNITIDs)
  } else {
    idbc <- ensure_connection()
    ipeds_df <- dplyr::tbl(idbc, tname)
    if(!is.null(UNITIDs)) ipeds_df <- ipeds_df %>% dplyr::filter(UNITID %in% !!UNITIDs)
    # pull the data from the database
    ipeds_df <- ipeds_df %>%
      dplyr::collect()
  }

  return(ipeds_df)
}
