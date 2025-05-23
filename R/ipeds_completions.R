#' Get completions by school and CIP
#' @param idbc database connector
#' @param years The years of data to retrieve; the table name minus one. Years before 2007 are invalid.
#' @param ids if NULL, everything, otherwise use the array of UNITIDs
#' @param awlevel Award level, defaults to "05" for Bachelors
#' @return a dataframe with institutional characteristics, year, and graduates by CIP
#' @details The CIP code is 2-digit for economy of results
#' @export
get_ipeds_completions <- function(idbc, years, UNITIDs = NULL, awlevel = "05"){
  # get grads

  grads <- get_cips(idbc, UNITIDs, years) %>%
    filter(MAJORNUM == 1) %>%
    inner_join(get_cipcodes(idbc, 2)) %>%
    group_by(Year, UNITID, CIPCODE, Subject) %>%
    summarize(Graduates = sum(N))

  return(grads)
}


#' Get grad rates
#' @param idbc Database connector
#' @param UNITIDs Array of identifiers, or NULL for all schools
#' @return Dataframe with year and cohort and cohort size, unitid, 6 year cumulative grad rate,
#' and 4-, 5-, and 6- year rates.
#' @details The four, five, and six year rates are all for the same cohort, and
#' all reported at the same time, which is six years after entry. The four year rate
#' means four or less years, but five and six mean exactly those many years.
#' @export
get_grad_rates <- function(idbc, UNITIDs = NULL){
  nan_to_na <- function(x){
    if_else(is.nan(x), NA_real_, x)
  }

  # expects ef<Year>d.csv

  # find all the tables
  tnames <- my_dbListTables(idbc, search_string = "^GR20\\d\\d$")

  out <- data.frame()

  for(tname in tnames) {

    # use the fall near, not the year on the table name
    year <- as.integer(substr(tname, 3,6))

    # filter to the data we want
    df <- tbl(idbc,tname) %>%
      filter(GRTYPE %in% c(2, # cohort size
                           3, # grads within 150%
                           8, # same as 2 -- cohort size
                           13, # four year grads
                           14, # five years
                           15,  # six year
                           43  # still enrolled
      ))

    # restrict to a list of IDs?
    if (!is.null(UNITIDs)) {
      df <- df %>% filter(UNITID %in% !!UNITIDs)
    }

    # The cohort column name depends on the year
    if(year < 2008){
      df <- df %>%
        select(UNITID, GRTYPE, N = GRRACE24 )
    } else {
      df <- df %>%
        select(UNITID, GRTYPE, N = GRTOTLT)
    }

    # get the data and do calculations

    df <- df %>%
      collect() %>%
      ######### Have data ##################
    spread(GRTYPE, N, sep = "_") %>%
      mutate(Grad_rate = GRTYPE_3 / GRTYPE_2,
             Grad_rate_4yr = GRTYPE_13 / GRTYPE_8,
             Grad_rate_5yr = GRTYPE_14 / GRTYPE_8,
             Grad_rate_6yr = GRTYPE_15 / GRTYPE_8,
             Still_enrolled = {if ("GRTYPE_43" %in% names(.))
               GRTYPE_43 / GRTYPE_8
               else NA_real_},
             Year = year,
             Cohort = year - 6) %>%
      select(UNITID, Year, Cohort,
             Cohort_size = GRTYPE_2,
             Grad_rate, # cumulative 6-year
             #Cohort_size_4yr = GRTYPE_2, # for backwards compatibility
             Grad_rate_4yr, # four years or less
             Grad_rate_5yr, # exactly five years
             Grad_rate_6yr,
             Still_enrolled) # exactly six years

    out <- rbind(out, df)

  }
  return(out)
}

#' Get demographic grad rates
#' @description Get four- and six-year graduation rates for cohort undergraduates for
#' race and gender
#' @param idbc Database connector
#' @param UNITIDs Array of identifiers
#' @return Long dataframe with year, unitid, demographic categories, cohort sizes,
#' and numbers of grad at 100 and 150%. Four and six year rates are generated.
#' Only returns data after 2007. Rates are as of August 31 of the identified year.
#' @export
get_grad_demo_rates <- function(idbc, UNITIDs = NULL){
  nan_to_na <- function(x){
    if_else(is.nan(x), NA_real_, x)
  }

  # find all the tables
  tnames <- my_dbListTables(idbc, search_string = "^GR20\\d\\d$")

  out <- data.frame()

  for(tname in tnames) {

    # rates as of August of this year
    year <- as.integer(substr(tname, 3,6))

    if(year < 2008) next # format changed

    df <- tbl(idbc,tname) %>%
      filter(GRTYPE %in% c(2,3, 13)) %>% # 2 is cohort size, 3 is grads in 150%, 13 is 100%
      select(UNITID,
             GRTYPE,
             Total =     GRTOTLT,
             Men   = GRTOTLM,
             Women = GRTOTLW,
             Asian = GRASIAT,
             Black = GRBKAAT,
             Hispanic = GRHISPT,
             Islander = GRNHPIT,
             White = GRWHITT,
             Multirace = GR2MORT,
             UnknownRace = GRUNKNT,
             Nonresident = GRNRALT)

    if (!is.null(UNITIDs)) {
      df <- df %>% filter(UNITID %in% !!UNITIDs)
    }

    df <- df %>%
      collect() %>%
      mutate(GRTYPE = case_when(GRTYPE == 2 ~ "Cohort",
                                GRTYPE == 3 ~ "Completed150",
                                GRTYPE == 13 ~ "Completed")) %>%
      gather(Type, N, -GRTYPE, -UNITID) %>%
      spread(GRTYPE, N) %>%
      mutate( Grad_rate_4yr = nan_to_na(Completed / Cohort),
              Grad_rate_6yr = nan_to_na(Completed150 / Cohort)) %>%
      mutate(Year = year)

    out <- rbind(out, df)

  }
  return(out)
}

#' Get pell grad rates
#' @description Get six-year graduation rates for cohort undergraduates for
#' Pell and Stafford students.
#' @param idbc Database connector
#' @param UNITIDs Array of identifiers
#' @return Dataframe with year, unitid, and four year rates having column names
#' that identify the demographic (total means everyone). Only returns data after
#' 2015. Rates are as of August 31 of the identified year.
#' @export
get_grad_pell_rates <- function(idbc, UNITIDs = NULL){
  nan_to_na <- function(x){
    if_else(is.nan(x), NA_real_, x)
  }

  # find all the tables
  tnames <- my_dbListTables(idbc, search_string = "^GR20\\d\\d_PELL_SSL$")

  out <- data.frame()

  for(tname in tnames) {

    # rates as of August of this year
    year <- as.integer(substr(tname, 3,6))

    df <- tbl(idbc,tname) %>%
      # just bachelor's seeking
      filter(PSGRTYPE ==	2) %>%
      select(UNITID,
             PellCohort = PGADJCT,
             PellCompleters = PGCMBAC,
             StaffordCohort = SSADJCT,
             StaffordCompleters = SSCMBAC)

    if (!is.null(UNITIDs)) {
      df <- df %>% filter(UNITID %in% !!UNITIDs)
    }

    df <- df %>%
      collect() %>%
      mutate( Pell_rate_6yr = nan_to_na(PellCompleters / PellCohort),
              Stafford_rate_6yr = nan_to_na(StaffordCompleters / StaffordCohort),
              Year = year)

    out <- rbind(out, df)

  }
  return(out)
}


