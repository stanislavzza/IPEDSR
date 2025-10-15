#' Get IPEDS faculty counts
#' @param UNITIDs IPEDS school IDs. If NULL, uses configured default_unitid.
#' @param before_2011 If true, includes old data
#' @return A dataframe with UNITID, Year, Tuition, Fees, RoomBoard for undergrad
#' @details The faculty status codes for rank and tenure were different before 2011, making
#' comparisons more difficult. By default, those records are omitted.
#' @export
get_faculty <- function(UNITIDs = NULL, before_2011 = FALSE){
  # Use configured default UNITID if none provided
  if (is.null(UNITIDs)) {
    UNITIDs <- get_default_unitid()
  }
  
  idbc <- ensure_connection()

  # find all the tables
  # through 2011, the tables are sYYYY_f, and after that
  # it's sYYYY_is
  #tnames1 <- odbc::dbListTables(idbc, table_name = "s_____f", table_type = "TABLE")
  tnames1 <- my_dbListTables(search_string = "^S\\d{4}_F$")
  #tnames2 <- odbc::dbListTables(idbc, table_name = "s_____is", table_type = "TABLE")
  tnames2 <- my_dbListTables(search_string = "^S\\d{4}_IS$")
  tnames <- c(tnames1, tnames2)

  out <- NULL

  for(tname in tnames) {

    # use the fall near, not the year on the table name
    year <- as.integer(substr(tname, 2,5)) -1

    if(year < 2011 & !before_2011) next # skip old data unless directed otherwise

    df <- dplyr::tbl(idbc, tname)

    if (!is.null(UNITIDs)) {
      df <- df %>% dplyr::filter(UNITID %in% !!UNITIDs)
    }

    df <- df %>%
      dplyr::collect()

    # make sure cols are upper case (sigh)
    names(df) <- toupper(names(df))

    # three columns contain descriptor codes that subset the results in columns
    drop_cols <- "ARANK"

    # Delete the exhaustive tenure statuses
    if( !is.na( match("SISCAT", names(df)) )) {
        df <- df %>%
          dplyr::select(-SISCAT)
    }

    #  Keep the short faculty status (tenure/not), but not the elaborations
    if( !is.na( match("FACSTAT", names(df)) )) {
        df <- df %>%
          dplyr::filter(FACSTAT %in% c(0,10,20,30,40,50))

        df0 <- get_labels(tname, df %>% dplyr::select(UNITID, FACSTAT)) %>%
          dplyr::select(UNITID, Row, Tenure = valueLabel)

        drop_cols <- c(drop_cols,"FACSTAT") # leave the out of the big gather
    } else {
      df0 <- df %>% dplyr::select(UNITID) %>% dplyr::distinct()
    }

    # Faculty rank
    df1 <- get_labels(tname, df %>% dplyr::select(UNITID, ARANK)) %>%
      dplyr::select(UNITID, Row, Rank = valueLabel)

    # demographic counts
    df2 <- get_labels(tname, df %>% dplyr::select(-dplyr::all_of(drop_cols))) %>%
      dplyr::mutate(varTitle = stringr::str_remove(varTitle, " $"), # remove trailing blanks
             Column = paste0(varTitle,":",valueLabel)) %>%
      dplyr::select(UNITID, Row, Column, Value = Codevalue) %>%
      dplyr::mutate(Value = as.integer(Value))

    # combine it all - specify join keys to avoid messages and ensure correct joins
    df <- df1 %>%
       dplyr::left_join(df0, by = c("UNITID", "Row")) %>%
       dplyr::left_join(df2, by = c("UNITID", "Row")) %>%
       dplyr::mutate(Year = year)

    if (is.null(out)) {
      out <- df
    } else {
      # Use bind_rows instead of full_join to stack years
      out <- dplyr::bind_rows(out, df)
    }
  }

  # Keep only columns that are found in the most recent year
  most_recent <- max(out$Year)

  keep_cols <- out %>%
    dplyr::filter(Year == most_recent) %>%
    dplyr::select(Column) %>%
    dplyr::distinct()

 out %>%
    dplyr::filter(Column %in% keep_cols$Column) %>%
    # Remove duplicates before spreading to avoid "duplicate keys" error
    dplyr::distinct(UNITID, Row, Rank, Tenure, Column, Year, .keep_all = TRUE) %>%
    tidyr::spread(Column, Value) %>%
   dplyr::ungroup() %>%
   return()
}

#' Get employees
#' @param UNITIDs an array of UNITIDs, defaulting to Furman
#' @return a dataframe with employee information
#' @export
get_employees <- function(UNITIDs = 218070){
  idbc <- ensure_connection()

  # find all the tables
  #tnames <- odbc::dbListTables(idbc, table_name = "EAP%")
  tnames <- my_dbListTables(search_string = "^EAP\\d{4}$")

  out <- data.frame()

  for(tname in tnames) {

    # use the fall near, not the year on the table name
    year <- as.integer(substr(tname, 4,7))

    if(year < 2012) next # old format, won't try to compare

    tdf <- get_ipeds_table(tname, year2 = as.character(year %% 100), UNITIDs) %>%
      dplyr::mutate(Year = year)

    # the 2017 table has unwanted columns
    tdf <- tdf %>% dplyr::select(-dplyr::starts_with("XE"))

    out <- rbind(out, tdf)
  }

  out <- out %>%
    dplyr::filter(`Faculty and tenure status` %in%
             c("All staff",
               "With faculty status, total",
               "With faculty status, tenured",
               "With faculty status, on tenure track",
               "Without faculty status",
               "Faculty/tenure status not applicable, nondegree-granting institutions"),
           Occupation %in% c("All staff", "Management"),
           !(Occupation == "Management" & `Faculty and tenure status` == "Without faculty status")) %>%
    dplyr::select(UNITID,
           Year,
           N = `Full-time employees (excluding medical schools)`,
           N_PT = `Part-time employees (excluding medical schools)`,
           FacultyStatus = `Faculty and tenure status`,
           Occupation) %>%
    dplyr::mutate( Occupation = dplyr::case_when(stringr::str_detect(FacultyStatus,"With faculty status") ~ "Faculty",
                                  Occupation == "Management" ~ "Management",
                                  FacultyStatus == "All staff" ~ "All employees",
                                  TRUE ~ "Staff"),
            FacultyStatus = dplyr::if_else(Occupation == "Faculty", FacultyStatus, NA_character_))

    # add up the two staff rows
    out <- out %>%
    dplyr::group_by(Year, UNITID, Occupation, FacultyStatus) %>%
    dplyr::summarize(N = sum(N), N_PT = sum(N_PT)) %>%
    dplyr::ungroup() %>%
    return()
}

#' Faculty salaries
#' @param UNITIDs an array of UNITIDs, or NULL. If NULL, uses configured default_unitid.
#' @param years an array of years to pull
#' @return a dataframe with faculty salaries by year and UNITID
#' @export
get_ipeds_faculty_salaries <- function(UNITIDs = NULL, years = NULL) {
  # Use configured default UNITID if none provided
  if (is.null(UNITIDs)) {
    UNITIDs <- get_default_unitid()
  }
  
  idbc <- ensure_connection()

  ranks <- data.frame(ARANK = 1:7,
                      Rank = c("Professor",
                      "Associate professor",
                      "Assistant professor",
                      "Instructor",
                      "Lecturer",
                      "No academic rank",
                      "All faculty total"))

  contract <- data.frame(CONTRACT = c(1,2,4),
                         Contract = c(
                          "9/10-month contract",
                          "11/12-month contract",
                          "Equated 9-month contract")
  )

  tnames <- data.frame(Table = my_dbListTables(search_string = "^SAL\\d{4}_.+$")) |>
            dplyr::mutate(Year = as.integer(substr(Table, 4,7)) - 1,
                   Suffix = substr(Table, 9,12)) |>
            dplyr::filter( (Year < 2011 & Suffix == "A") | (Year >= 2011 & Suffix == "IS"))

  # if necessary, filter to the specified years
  if(!is.null(years)) {
    tnames <- tnames %>%
      dplyr::filter(Year %in% !!years)
  }

  out <- data.frame()

  for(i in seq_len(nrow(tnames))) {
    year = tnames$Year[i]
    tname = tnames$Table[i]

    df <- dplyr::tbl(idbc, tname) %>%
      dplyr::filter(UNITID %in% !!UNITIDs) %>%
      dplyr::collect() %>%
      dplyr::mutate(Year = !!year) |>
      dplyr::left_join(ranks)

    if(year < 2011){
      df <- df |>
        dplyr::left_join(contract) |>
        dplyr::filter(Contract == "Equated 9-month contract") |>
        dplyr::select(UNITID, Year, Rank, N = EMPCNTT, AvgSalary = AVESALT)
    } else if (year < 2016) {
      df <- df |>
        dplyr::select(UNITID, Year, Rank,
               N = SATOTLT,
               AvgSalary = SAAVMNT) |>
        dplyr::mutate(AvgSalary = AvgSalary*9)
    } else {
      df <- df |>
        dplyr::select(UNITID, Year, Rank,
               N = SAINSTT,
               AvgSalary = SAEQ9AT)
    }

    out <- rbind(out, df)

  }
  return(out)
}
