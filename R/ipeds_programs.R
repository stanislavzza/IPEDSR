#' Get CIPS
#' @description Given institutional IDs, get completions by year and CIP for each
#' @param idbc Database connector
#' @param UNITIDs UNITIDs, or NULL. If NULL, uses configured default_unitid.
#' @param years The years of data to retrieve; the table name minus one. Years before 2007 are invalid.
#' @param cip_codes Provide a vector of codes to search for. This can be two-digit, four, or six. Note
#' code "99" is all degrees, which is filtered out if you leave cip_codes NULL.
#' @param awlevel Award level, defaults to "05" for Bachelors
#' @return A data frame with UNITID, CIPCODE, MAJORNUM, N (the count of completions), and Year
#' @export
get_cips <- function(UNITIDs = NULL, years = NULL, cip_codes = NULL, awlevel = "05"){
  # Use configured default UNITID if none provided
  if (is.null(UNITIDs)) {
    UNITIDs <- get_default_unitid()
  }
  
  idbc <- ensure_connection()

  # find all the tables
  tnames <- my_dbListTables(search_string = "^C\\d{4}_A$")

  out <- data.frame()

  for(tname in tnames) {

    # from the 2023 dictionary:
    # Awards/degrees conferred between July 1, 2022 and June 30, 2023
    year <- as.integer(substr(tname, 2,5))
    if(is.na(year)) next

    if(!is.null(years)) {
      if(!(year %in% years) ) next
    }

    if(year < 2009) next # the C2006_A and C2007_A tables have different column names


    message("Processing ", tname, " for year ", year)

    tdf <- dplyr::tbl(idbc, tname) %>%
      dplyr::filter(AWLEVEL == !!awlevel) # 99 is total degrees

    if (!is.null(cip_codes)) {
      tdf <- tdf %>% filter(CIPCODE %in% !!cip_codes)
    } else {
      tdf <- tdf %>% filter(CIPCODE != "99") # 99 is total degrees
    }

    if(!is.null(UNITIDs)) tdf <- tdf %>% filter(UNITID %in% !!UNITIDs)

    tdf <- tdf %>% # CIP 99 is total
      select(UNITID, CIPCODE, MAJORNUM, N = CTOTALT) %>%
      collect() %>%
      mutate(Year = year)

      out <- rbind(out,tdf)
  }
  return(out)
}

#' Get CIP Codes
#' @description Get the latest CIP code table from IPEDS
#' @param idbc Database connector
#' @param digits optional number of digits to truncate to, or NULL for no truncation
#' @return A data frame with CIPCODE, Subject
#' @details If CIPs are truncated, there are multiple versions, which are reduced
#' through distinct(). That may not be optimal.
#' @export
get_cipcodes <- function(digits = NULL){
  idbc <- ensure_connection()

  # find the most recent values table
  tname <- my_dbListTables(search_string = "^VALUESETS\\d\\d$") %>% max()

  # get the cipcodes
  tdf <- dplyr::tbl(idbc,tname) %>%
    dplyr::filter(varName == "CIPCODE") %>%
    dplyr::select(CIPCODE = Codevalue, Subject = valueLabel) %>%
    dplyr::collect() %>%
    unique()

  if(!is.null(digits)) {
    tdf <- tdf %>%
      dplyr::filter(nchar(CIPCODE) == digits)
  }

  return(tdf)
}

#' CIP distributions
#' @description Get the distribution of degrees granted by year and institution and CIP2 for
#' the given degree level.
#' @param idbc Database connector for the IPEDS database
#' @param level The code for the degree level
#' @param UNITIDs optional array of UNITIDs to return, or NULL for everything
#' @param first_only When TRUE only counts first majors. Defaults to FALSE.
#' @details Codes for the leval are
#'   3	Associate's degree
#'   5	Bachelor's degree
#'   7	Master's degree
#'   17	Doctor's degree - research/scholarship
#'   18	Doctor's degree - professional practice
#'   19	Doctor's degree - other
#'   20	Certificates of less than 12 weeks
#'   21	Certificates of at least 12 weeks but less than 1 year
#'   2	Certificates of at least 1 but less than 2 years
#'   4	Certificates of at least 2 but less than 4 years
#'   6	Postbaccalaureate certificate
#'   8	Post-master's certificate
#' @return A dataframe with Year, UNITID, CIP2, and count, including both first and second majors
#' @export

get_cip2_counts <- function(awlevel = "05", UNITIDs = NULL, first_only = FALSE){
  # Use configured default UNITID if none provided
  if (is.null(UNITIDs)) {
    UNITIDs <- get_default_unitid()
  }
  
  idbc <- ensure_connection()

  # find all the tables
  tnames <- my_dbListTables(search_string = "^C20\\d\\d_A$")

  out <- data.frame()

  for(tname in tnames) {

    # use the fall near, not the year on the table name
    year <- as.integer(substr(tname, 2,5))

    # get the lookup table name
    ltable <- dplyr::tbl(idbc, stringr::str_c("valuesets", substr(tname, 4,5))) %>%
      dplyr::filter(varName == "CIPCODE", nchar(Codevalue) == 2) %>%
      dplyr::select(CIP2 = Codevalue, CIPDesc = valueLabel) %>%
      dplyr::collect() %>%
      dplyr::distinct(CIP2, .keep_all = TRUE)

    if(year <= 2007) next # these have different column names

    tdf <- dplyr::tbl(idbc, tname) %>%
      dplyr::filter(AWLEVEL %in% !!awlevel,
             CIPCODE != "99",           # CIP 99 is total
             nchar(CIPCODE) == 2)

    if(!is.null(UNITIDs)) tdf <- tdf %>% dplyr::filter(UNITID %in% UNITIDs)
    if(first_only == TRUE) tdf <- tdf %>% dplyr::filter(MAJORNUM == 1)

    tdf <- tdf %>%
      dplyr::select(UNITID, CIP2  = CIPCODE, MAJORNUM, N = CTOTALT) %>%
      dplyr::collect() %>%
      dplyr::left_join(ltable) %>%
      dplyr::group_by(UNITID, CIP2, CIPDesc) %>%
      dplyr::summarize(N = sum(N)) %>%
      dplyr::mutate(Year = year)

    out <- rbind(out, tdf)
  }

  return(out)
}

