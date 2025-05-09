#' Get institutional characteristics
#' @param idbc A database connector
#' @param year The year to get, or NULL (default) for the most recent year
#' @param UNITIDs optional array of UNITIDs to filter to
#' @return a dataframe with institutional characteristics
#' @export
#' @details Apparently these tables include 'blob' columns that won't allow downloading
#' of the full thing. See https://github.com/r-dbi/odbc/issues/309.
#' So we have to select around those.
get_characteristics <- function(idbc, year = NULL, UNITIDs = NULL){

  # find all the tables
  #tnames <- odbc::dbListTables(idbc, table_name = "hd%")
  tnames <- my_dbListTables(idbc, search_string = "^HD\\d{4}$")

  if(is.null(year)) year <- max(as.integer(substr(tnames, 3,6)))

  for(tname in tnames) {

    # use the fall near, not the year on the table name
    file_year <- as.integer(substr(tname, 3,6))

    if(year != file_year) next

    tdf <- tbl(idbc, tname) %>%
        select(UNITID,
               OPEID,
               InstName = INSTNM,
               City = CITY,
               State = STABBR,
               Zipcode = ZIP,
               FIPS,
               CensusRegion = OBEREG,
               SECTOR,
               ICLEVEL,
               CONTROL,
               CCBASIC,
               HLOFFER,
               UGOFFER,
               GROFFER,
               HDEGOFR1,
               DEGGRANT,
               HBCU,
               HOSPITAL,
               MEDICAL,
               TRIBAL)

    if(!is.null(UNITIDs)) tdf <- tdf %>% filter(UNITID %in% !!UNITIDs)

    tdf <- tdf |>
      collect()
  }


  return(tdf)
}

