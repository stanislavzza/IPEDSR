#' Get cohort retention and graduation history
#' @param UNITIDs an array of IDs or NULL. If NULL, uses configured default_unitid.
#' @return Cohort year and size, and rates and numbers of returning and
#' graduating students.
#' @details This report omits Year because it's keyed on Chort.
#' The columns Yr1 through Yr6 estimate enrollment.
#' @export
get_cohort_stats <- function(UNITIDs = NULL){
  # Use configured default UNITID if none provided
  if (is.null(UNITIDs)) {
    UNITIDs <- get_default_unitid()
  }

  ret  <- get_retention(UNITIDs) %>%
          dplyr::select(-Year) %>%
          dplyr::mutate(Retention = Retention / 100)

  grad <- get_grad_rates(UNITIDs) %>%
          dplyr::select(-Year, -Cohort_size) %>%
          tidyr::replace_na(list(Still_enrolled = 0))

  ret %>%
        dplyr::left_join(grad) %>%
        # class counts
        dplyr::mutate( Yr1 = Cohort_size,
                Yr2 = round(Yr1 * Retention),
                Yr4 = round(Yr1 * (Grad_rate + Still_enrolled)),
                Yr5 = round(Yr4 - Grad_rate_4yr*Yr1),
                Yr6 = round(Yr5 - Grad_rate_5yr*Yr1)) %>%
    return()
}



#' Get IPEDS enrollment
#' @description Use the efYEAR tables to retrieve student counts.
#' @param idbc Database connector for the IPEDS database.
#' @param UNITIDs The schools to retrieve, or NULL (default) for all.
#' @param StudentTypeCode One or more numeric codes to specify what type of student
#' to filter to. See Details for, well, details. Defaults to 1, all students.
#' @details The StudentTypeCode is one or more of
#' 1	= All students total
#' 2	= All students, Undergraduate total
#' 3	= All students, Undergraduate, Degree/certificate-seeking total
#' 4	= All students, Undergraduate, Degree/certificate-seeking, First-time
#' 5	= All students, Undergraduate, Other degree/certificate-seeking
#' 19	= All students, Undergraduate, Other degree/certifcate-seeking, Transfer-ins
#' 20	= All students, Undergraduate, Other degree/certifcate-seeking, Continuing
#' 11	= All students, Undergraduate, Non-degree/certificate-seeking
#' 12	= All students, Graduate
#' 21	= Full-time students total
#' 22	= Full-time students, Undergraduate total
#' 23	= Full-time students, Undergraduate, Degree/certificate-seeking total
#' 24	= Full-time students, Undergraduate, Degree/certificate-seeking, First-time
#' 25	= Full-time students, Undergraduate, Degree/certificate-seeking, Other degree/certificate-seeking
#' 39	= Full-time students, Undergraduate, Other degree/certifcate-seeking, Transfer-ins
#' 40	= Full-time students, Undergraduate, Other degree/certifcate-seeking, Continuing
#' 31	= Full-time students, Undergraduate, Non-degree/certificate-seeking
#' 32	= Full-time students, Graduate
#' 41	= Part-time students total
#' 42	= Part-time students, Undergraduate total
#' 43	= Part-time students, Undergraduate, Degree/certificate-seeking total
#' 44	= Part-time students, Undergraduate, Degree/certificate-seeking, First-time
#' 45	= Part-time students, Undergraduate, Degree/certificate-seeking, Other degree/certificate-seeking
#' 59	= Part-time students, Undergraduate, Other degree/certifcate-seeking, Transfer-ins
#' 60	= Part-time students, Undergraduate, Other degree/certifcate-seeking, Continuing
#' 51	= Part-time students, Undergraduate, Non-degree/certificate-seeking
#' 52	= Part-time students, Graduate
#' @return A dataframe with UNITID, Year, Total, Men, Women, White, Black, Hispanic, and NRAlien.
#' @export
ipeds_get_enrollment <- function(UNITIDs = NULL, StudentTypeCode = 1){
  # Use configured default UNITID if none provided
  if (is.null(UNITIDs)) {
    UNITIDs <- get_default_unitid()
  }
  
  idbc <- ensure_connection()

  # student codes
  student_codes <- tibble::tribble(
    ~StudentTypeCode, ~StudentType,
    1	,"All students total",
    2	,"All students, Undergraduate total",
    3	,"All students, Undergraduate, Degree/certificate-seeking total",
    4	,"All students, Undergraduate, Degree/certificate-seeking, First-time",
    5	,"All students, Undergraduate, Other degree/certificate-seeking",
    19,"All students, Undergraduate, Other degree/certifcate-seeking, Transfer-ins",
    20,"All students, Undergraduate, Other degree/certifcate-seeking, Continuing",
    11,"All students, Undergraduate, Non-degree/certificate-seeking",
    12,"All students, Graduate",
    21,"Full-time students total",
    22,"Full-time students, Undergraduate total",
    23,"Full-time students, Undergraduate, Degree/certificate-seeking total",
    24,"Full-time students, Undergraduate, Degree/certificate-seeking, First-time",
    25,"Full-time students, Undergraduate, Degree/certificate-seeking, Other degree/certificate-seeking",
    39,"Full-time students, Undergraduate, Other degree/certifcate-seeking, Transfer-ins",
    40,"Full-time students, Undergraduate, Other degree/certifcate-seeking, Continuing",
    31,"Full-time students, Undergraduate, Non-degree/certificate-seeking",
    32,"Full-time students, Graduate",
    41,"Part-time students total",
    42,"Part-time students, Undergraduate total",
    43,"Part-time students, Undergraduate, Degree/certificate-seeking total",
    44,"Part-time students, Undergraduate, Degree/certificate-seeking, First-time",
    45,"Part-time students, Undergraduate, Degree/certificate-seeking, Other degree/certificate-seeking",
    59,"Part-time students, Undergraduate, Other degree/certifcate-seeking, Transfer-ins",
    60,"Part-time students, Undergraduate, Other degree/certifcate-seeking, Continuing",
    51,"Part-time students, Undergraduate, Non-degree/certificate-seeking",
    52,"Part-time students, Graduate")

  # find all the tables
  #tnames <- odbc::dbListTables(idbc, table_name = "ef%a")
  tnames <- my_dbListTables(search_string = "^EF\\d{4}A$")

  out <- data.frame()

  for(tname in tnames) {

    # use the fall near, not the year on the table name
    year <- as.integer(substr(tname, 3,6))

    # the varnames switched in 2008
    if(tname <= "EF2007A"){

      tdf <- dplyr::tbl(idbc, tname) %>%
        dplyr::filter( EFALEVEL %in% !!StudentTypeCode) %>%
        dplyr::select(UNITID,
               StudentTypeCode = EFALEVEL,
               Total = EFRACE24,
               Men = EFRACE15,
               Women = EFRACE16,
               White = EFRACE22,
               Black = EFRACE18,
               Hispanic = EFRACE21,
               NRAlien = EFRACE17)
    } else if(tname <= "EF2009A"){

      tdf <- dplyr::tbl(idbc, tname) %>%
        dplyr::filter( EFALEVEL %in% !!StudentTypeCode) %>%
        dplyr::select(UNITID,
               StudentTypeCode = EFALEVEL,
               Total = EFTOTLT,
               Men = EFTOTLM,
               Women = EFTOTLW,
               White = EFRACE22,
               Black = EFRACE18,
               Hispanic = EFRACE21,
               NRAlien = EFNRALT)

    } else {

      tdf <- dplyr::tbl(idbc, tname) %>%
        dplyr::filter( EFALEVEL %in% !!StudentTypeCode) %>%
        dplyr::select(UNITID,
               StudentTypeCode = EFALEVEL,
               Total = EFTOTLT,
               Men = EFTOTLM,
               Women = EFTOTLW,
               White = EFWHITT,
               Black = EFBKAAT,
               Hispanic = EFHISPT,
               NRAlien = EFNRALT)
    }

    if(!is.null(UNITIDs)) {
      tdf <- tdf %>%
        dplyr::filter(UNITID %in% !!UNITIDs)
    }

    tdf <- tdf %>%
      dplyr::collect() %>%
      dplyr::mutate(Year = year)

    out <- rbind(out, tdf)
  }

  # add code descriptions
  out <- out %>%
    dplyr::left_join(student_codes)

  return(out)
}

#' Get cohort size and retention rates
#' @param idbc database connector
#' @param UNITIDs optional IDs to retrieve, or NULL for everything
#' @return a dataframe with UNITID, Year, Retention, CohortSize
#' @details The cohort  = year - 1 since the retention rate is reported a year
#' later. A cohort column is included to make this clear.
#' @export
get_retention <- function(UNITIDs = NULL){
  # Use configured default UNITID if none provided
  if (is.null(UNITIDs)) {
    UNITIDs <- get_default_unitid()
  }
  
  idbc <- ensure_connection()
  # find all the tables
  # tnames <- odbc::dbListTables(idbc, table_name = "ef20__D")
  tnames <- my_dbListTables(search_string = "^EF\\d{4}D$")

  out <- data.frame()

  for(tname in tnames) {
    # the year is the cohort year, but the retention rate
    # applies to the prior year
    year <- as.integer(substr(tname, 3,6))

    if (year < 2007) {
      df <- dplyr::tbl(idbc,tname) %>%
        dplyr::select(UNITID,
               # cohort size not available
               Retention   = RET_PCF)
    } else {
      df <- dplyr::tbl(idbc,tname) %>%
        dplyr::select(UNITID,
               Cohort_size = RRFTCTA,
               Retention   = RET_PCF)
    }

    if(!is.null(UNITIDs)) {
      df <- df %>%
        dplyr::filter(UNITID %in% !!UNITIDs)
    }

    df <- df %>%
      dplyr::collect() %>%
      dplyr::mutate(Year = year)

    # add blank cohort column if it doesn't exist
    if(!"Cohort_size" %in% names(df)) {
      df <- df %>%
        dplyr::mutate(Cohort_size = NA)
    }

    df <- df |> dplyr::select(UNITID, Year, Cohort_size, Retention)

    out <- rbind(out, df)
  }
  # fix it so that the retention rate lines up with the cohort size
  # otherwise the retention rate and cohort size are mismatched
  out <- out %>%
    dplyr::group_by(UNITID) %>%
    dplyr::arrange(Year) %>%
    dplyr::mutate(Cohort = Year - 1) %>%
    dplyr::ungroup()

  return(out)
}

#' Admit Funnel
#' @param idbc database connector
#' @param UNITIDs optional list of UNITIDs to filter to. If NULL, uses configured default_unitid.
#' @export
get_admit_funnel <- function(UNITIDs = NULL){
  # Use configured default UNITID if none provided
  if (is.null(UNITIDs)) {
    UNITIDs <- get_default_unitid()
  }
  
  idbc <- ensure_connection()

  # output data
  out <- data.frame()

  # find all the tables before 2014
  #tnames <- odbc::dbListTables(idbc, table_name = "ic____", table_type = "TABLE")
  tnames <- my_dbListTables(search_string = "^IC\\d{4}$")
  for(tname in tnames) {

    # use the fall near, not the year on the table name
    year <- as.integer(substr(tname, 3,6))

    if(year >= 2014) next # spec changed

    df <- dplyr::tbl(idbc, tname) %>%
      dplyr::select(UNITID,
             Male_apps      = APPLCNM,
             Female_apps    = APPLCNW,
             Male_admits    = ADMSSNM,
             Female_admits  = ADMSSNW,
             Male_enrolls   = ENRLFTM,
             Female_enrolls = ENRLFTW,
             SATVR25,  # standardized test quartiles
             SATVR75,
             SATMT25,
             SATMT75,
             ACTCM25,
             ACTCM75,
             ACTEN25,
             ACTEN75,
             ACTMT25,
             ACTMT75,
             SATNUM,
             SATPCT,
             ACTNUM,
             ACTPCT
      )


    if (!is.null(UNITIDs)) df<- df %>% dplyr::filter(UNITID %in% !!UNITIDs)

    df <- df |>
      dplyr::collect() %>%
      dplyr::mutate(
        Male_apps      = as.integer(Male_apps),
        Female_apps    = as.integer(Female_apps),
        Male_admits    = as.integer(Male_admits),
        Female_admits  = as.integer(Female_admits),
        Male_enrolls   = as.integer(Male_enrolls),
        Female_enrolls = as.integer(Female_enrolls),
        Total_apps = Male_apps + Female_apps,
        Total_admits = Male_admits + Female_admits,
        Total_enrolls = Male_enrolls + Female_enrolls,
        Acceptance_rate = Total_admits / Total_apps,
        Yield_rate     = Total_enrolls / Total_admits,
        SATVR25 = as.integer(SATVR25),  # standardized test quartiles
        SATVR75 = as.integer(SATVR75),
        SATMT25 = as.integer(SATMT25),
        SATMT75 = as.integer(SATMT75),
        ACTCM25 = as.integer(ACTCM25),
        ACTCM75 = as.integer(ACTCM75),
        ACTEN25 = as.integer(ACTEN25),
        ACTEN75 = as.integer(ACTEN75),
        ACTMT25 = as.integer(ACTMT25),
        ACTMT75 = as.integer(ACTMT75),
        SATNUM = as.integer(SATNUM),
        SATPCT = as.integer(SATPCT),
        ACTNUM = as.integer(ACTNUM),
        ACTPCT = as.integer(ACTPCT),
        Year = year
      )
    out <- rbind(out, df)
  }

  # after 2014
  # find all the tables before 2014
  #tnames <- odbc::dbListTables(idbc, table_name = "adm____", table_type = "TABLE")
  tnames <- my_dbListTables(search_string = "^ADM\\d{4}$")
  for(tname in tnames) {

    # use the fall near, not the year on the table name
    year <- as.integer(substr(tname, 4,7))

    if(year < 2014) next # spec changed

    df <- dplyr::tbl(idbc, tname) %>%
      dplyr::select(UNITID,
             Male_apps      = APPLCNM,
             Female_apps    = APPLCNW,
             Male_admits    = ADMSSNM,
             Female_admits  = ADMSSNW,
             Male_enrolls   = ENRLFTM,
             Female_enrolls = ENRLFTW,
             SATVR25,  # standardized test quartiles
             SATVR75,
             SATMT25,
             SATMT75,
             ACTCM25,
             ACTCM75,
             ACTEN25,
             ACTEN75,
             ACTMT25,
             ACTMT75,
             SATNUM,
             SATPCT,
             ACTNUM,
             ACTPCT,
      )

    if (!is.null(UNITIDs)) df<- df %>% dplyr::filter(UNITID %in% !!UNITIDs)

    df <- df |>
      dplyr::collect() %>%
      dplyr::mutate(
        Male_apps      = as.integer(Male_apps),
        Female_apps    = as.integer(Female_apps),
        Male_admits    = as.integer(Male_admits),
        Female_admits  = as.integer(Female_admits),
        Male_enrolls   = as.integer(Male_enrolls),
        Female_enrolls = as.integer(Female_enrolls),
        Total_apps = Male_apps + Female_apps,
        Total_admits = Male_admits + Female_admits,
        Total_enrolls = Male_enrolls + Female_enrolls,
        Acceptance_rate = Total_admits / Total_apps,
        Yield_rate     = Total_enrolls / Total_admits,
        SATVR25 = as.integer(SATVR25),  # standardized test quartiles
        SATVR75 = as.integer(SATVR75),
        SATMT25 = as.integer(SATMT25),
        SATMT75 = as.integer(SATMT75),
        ACTCM25 = as.integer(ACTCM25),
        ACTCM75 = as.integer(ACTCM75),
        ACTEN25 = as.integer(ACTEN25),
        ACTEN75 = as.integer(ACTEN75),
        ACTMT25 = as.integer(ACTMT25),
        ACTMT75 = as.integer(ACTMT75),
        SATNUM = as.integer(SATNUM),
        SATPCT = as.integer(SATPCT),
        ACTNUM = as.integer(ACTNUM),
        ACTPCT = as.integer(ACTPCT),
        Year = year
      )
    out <- rbind(out, df)
  }

  return(out)

}


#' Get financial aid
#' @param idbc IPEDS database connection
#' @param UNITIDs Optional list of UNITIDs to filter to. If NULL, uses configured default_unitid.
#' @export

get_fa_info <- function(UNITIDs = NULL){
  # Use configured default UNITID if none provided
  if (is.null(UNITIDs)) {
    UNITIDs <- get_default_unitid()
  }
  idbc <- ensure_connection()
  # input should be a sfa file, eg.
  # df <- read_csv("data/IPEDS/2017/sfa1617.csv", guess_max = 5000) %>%
  # adds a given year to the df

  # find all the tables
  #tnames <- odbc::dbListTables(idbc, table_name = "sfa%")
  tnames <- my_dbListTables(search_string = "^SFA\\d{4}")

  # leave out the sfav ones
  #tnames <- tnames[!str_detect(tnames,"SFAV")]

  tname_prefixes <- unique(substr(tnames,1,7))

  out <- data.frame()

  for(tname_prefix in tname_prefixes) {
    Year <- 2000 + as.integer(substr(tname_prefix,4,5))
    print(Year)

    tname_set <- tnames[ str_detect(tnames, tname_prefix)]

    # start by joining all the tables in the set
    df <- dplyr::tbl(idbc,tname_set[1])

    if(length(tname_set) == 2) df <- df %>% dplyr::left_join(dplyr::tbl(idbc,tname_set[2]))
    if(length(tname_set) == 3) df <- df %>% dplyr::left_join(dplyr::tbl(idbc,tname_set[3]))

    if(Year < 2011) { ############ Old ones lacked some data

      df <- df %>%
        dplyr::select(UNITID,
               N_undergraduates   = SCFA2,
               N_fall_cohort      = SCFA1N,
               Percent_PELL       = FGRNT_P,
               N_inst_aid         = IGRNT_N,
               Avg_inst_aid       = IGRNT_A,
               P_inst_aid         = IGRNT_P

        )

      if (!is.null(UNITIDs)) {
        df <- df %>% dplyr::filter(UNITID %in% !!UNITIDs)
      }

      df <- df %>%
        dplyr::collect() %>%
        dplyr::mutate(
          T_inst_aid         = N_inst_aid * Avg_inst_aid,
          Avg_net_price      = NA,
          Avg_net_price_0k   = NA,
          Avg_net_price_30k  = NA,
          Avg_net_price_48k  = NA,
          Avg_net_price_75k  = NA,
          Avg_net_price_110k = NA,
          N_0k               = NA,
          N_30k              = NA,
          N_48k              = NA,
          N_75k              = NA,
          N_110k             = NA,
          Year = Year)

    } else { # 2011 on
      df <- df %>%
        dplyr::select(UNITID,
               N_undergraduates   = SCFA2,
               N_fall_cohort      = SCFA1N,
               Percent_PELL       = FGRNT_P,
               N_inst_aid         = IGRNT_N,
               Avg_inst_aid       = IGRNT_A,
               P_inst_aid         = IGRNT_P,
               T_inst_aid         = IGRNT_T,
               Avg_net_price      = NPGRN2,
               Avg_net_price_0k   = NPT412, # Title IV only
               Avg_net_price_30k  = NPT422,
               Avg_net_price_48k  = NPT432,
               Avg_net_price_75k  = NPT442,
               Avg_net_price_110k = NPT452,#,
               N_0k               = GRN4G12,
               N_30k              = GRN4G22,
               N_48k              = GRN4G32,
               N_75k              = GRN4G42,
               N_110k             = GRN4G52
        )

      if (!is.null(UNITIDs)) {
        df <- df %>% dplyr::filter(UNITID %in% !!UNITIDs)
      }

      df <- df %>%
        dplyr::collect() %>%
        dplyr::mutate(Year = Year)
    }
    out <- rbind(out,df)
  }
  return(out)
}

