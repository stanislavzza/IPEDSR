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

#' Get IPEDS UNITIDs for institutions matching criteria
#' @param idbc A database connector
#' @param year The year to get, or NULL (default) for the most recent
#' @param control Optional array of CONTROL codes to filter to
#' @param states Optional array of state abbreviations to filter to
#' @param level Optional array of ICLEVEL codes to filter to
#' @return A vector with UNITIDs matching the criteria
#' @export
#' @details State abbreviations are the standard postal codes.
#' CONTROL codes are:
#'  1	Public
#'  2	Private not-for-profit
#'  3	Private for-profit
#'  -3	{Not available}
#'  ICLEVEL codes are:
#'  1	Four or more years
#'  2	At least 2 but less than 4 years
#'  3	Less than 2 years (below associate)
#'  -3	{Not available}
#'  You can provide an array like c(1,3) to get multiple levels or controls.
#'  If left blank, all levels/controls/states are included.

get_ids <- function(idbc, year = NULL, control = NULL, states = NULL, level = NULL){

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

  ipeds_df <- tbl(idbc, tname)

  # filter by states?
  if(!is.null(states)){
    ipeds_df <- ipeds_df %>%
      filter(STABBR %in% states)
  }

  # filter by control?
  if(!is.null(control)){
    ipeds_df <- ipeds_df %>%
      filter(CONTROL %in% control)
  }

  # filter by level?
  if(!is.null(level)){
    ipeds_df <- ipeds_df %>%
      filter(ICLEVEL %in% level)
  }

  ids <- ipeds_df %>% select(UNITID) |> distinct() |> collect() |> pull(UNITID)

  return(ids)

}
