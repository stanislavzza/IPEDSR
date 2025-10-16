#' Get IPEDS faculty counts
#' @param idbc Database connector
#' @param UNITIDs IPEDS school IDs. If NULL, gets everything
#' @param before_2011 If true, includes old data
#' @return A dataframe with UNITID, Year, Tuition, Fees, RoomBoard for undergrad
#' @details The faculty status codes for rank and tenure were different before 2011, making
#' comparisons more difficult. By default, those records are omitted.
#' @export
get_faculty <- function(idbc, UNITIDs = NULL, before_2011 = FALSE){

  # find all the tables
  # through 2011, the tables are sYYYY_f, and after that
  # it's sYYYY_is
  #tnames1 <- odbc::dbListTables(idbc, table_name = "s_____f", table_type = "TABLE")
  tnames1 <- my_dbListTables(idbc, search_string = "^S\\d{4}_F$")
  #tnames2 <- odbc::dbListTables(idbc, table_name = "s_____is", table_type = "TABLE")
  tnames2 <- my_dbListTables(idbc, search_string = "^S\\d{4}_IS$")
  tnames <- c(tnames1, tnames2)

  out <- NULL

  for(tname in tnames) {

    # use the fall near, not the year on the table name
    year <- as.integer(substr(tname, 2,5)) -1

    if(year < 2011 & !before_2011) next # skip old data unless directed otherwise

    df <- tbl(idbc, tname)

    if (!is.null(UNITIDs)) {
      df <- df %>% filter(UNITID %in% !!UNITIDs)
    }

    df <- df %>%
      collect()

    # make sure cols are upper case (sigh)
    names(df) <- toupper(names(df))

    # three columns contain descriptor codes that subset the results in columns
    drop_cols <- "ARANK"

    # Delete the exhaustive tenure statuses
    if( !is.na( match("SISCAT", names(df)) )) {
        df <- df %>%
          select(-SISCAT)
    }

    #  Keep the short faculty status (tenure/not), but not the elaborations
    if( !is.na( match("FACSTAT", names(df)) )) {
        df <- df %>%
          filter(FACSTAT %in% c(0,10,20,30,40,50))

        df0 <- get_labels(idbc, tname, df %>% select(UNITID, FACSTAT)) %>%
          select(UNITID, Row, Tenure = valueLabel)

        drop_cols <- c(drop_cols,"FACSTAT") # leave the out of the big gather
    } else {
      df0 <- df %>% select(UNITID) %>% distinct()
    }

    # Faculty rank
    df1 <- get_labels(idbc, tname, df %>% select(UNITID, ARANK)) %>%
      select(UNITID, Row, Rank = valueLabel)

    # demographic counts
    df2 <- get_labels(idbc, tname, df %>% select(-all_of(drop_cols))) %>%
      mutate(varTitle = str_remove(varTitle, " $"), # remove trailing blanks
             Column = paste0(varTitle,":",valueLabel)) %>%
      select(UNITID, Row, Column, Value = Codevalue) %>%
      mutate(Value = as.integer(Value))

    # combine it all
    df <- df1 %>%
       left_join(df0) %>%
       left_join(df2) %>%
       mutate(Year = year)

    if (is.null(out)) {
      out <- df
    } else {
      out <- full_join(out, df)
    }
  }

  # Keep only columns that are found in the most recent year
  most_recent <- max(out$Year)

  keep_cols <- df %>%
    filter(Year == most_recent) %>%
    select(Column)  %>%
    distinct()

 out %>%
    filter(Column %in% keep_cols$Column) %>%
    spread(Column, Value) %>%
   ungroup() %>%
   return()
}

#' Get employees
#' @param idbc A database connector
#' @param UNITIDs an array of UNITIDs, defaulting to Furman
#' @return a dataframe with employee information
#' @export
get_employees <- function(idbc, UNITIDs = 218070){

  # find all the tables
  #tnames <- odbc::dbListTables(idbc, table_name = "EAP%")
  tnames <- my_dbListTables(idbc, search_string = "^EAP\\d{4}$")

  out <- data.frame()

  for(tname in tnames) {

    # use the fall near, not the year on the table name
    year <- as.integer(substr(tname, 4,7))

    if(year < 2012) next # old format, won't try to compare

    tdf <- get_ipeds_table(idbc, tname, year2 = as.character(year %% 100), UNITIDs) %>%
      mutate(Year = year)

    # the 2017 table has unwanted columns
    tdf <- tdf %>% select(-starts_with("XE"))

    out <- rbind(out, tdf)
  }

  out <- out %>%
    filter(`Faculty and tenure status` %in%
             c("All staff",
               "With faculty status, total",
               "With faculty status, tenured",
               "With faculty status, on tenure track",
               "Without faculty status",
               "Faculty/tenure status not applicable, nondegree-granting institutions"),
           Occupation %in% c("All staff", "Management"),
           !(Occupation == "Management" & `Faculty and tenure status` == "Without faculty status")) %>%
    select(UNITID,
           Year,
           N = `Full-time employees (excluding medical schools)`,
           N_PT = `Part-time employees (excluding medical schools)`,
           FacultyStatus = `Faculty and tenure status`,
           Occupation) %>%
    mutate( Occupation = case_when(str_detect(FacultyStatus,"With faculty status") ~ "Faculty",
                                  Occupation == "Management" ~ "Management",
                                  FacultyStatus == "All staff" ~ "All employees",
                                  TRUE ~ "Staff"),
            FacultyStatus = if_else(Occupation == "Faculty", FacultyStatus, NA_character_))

    # add up the two staff rows
    out <- out %>%
    group_by(Year, UNITID, Occupation, FacultyStatus) %>%
    summarize(N = sum(N), N_PT = sum(N_PT)) %>%
    ungroup() %>%
    return()
}

#' Faculty salaries
#' @param idbc A database connector
#' @param UNITIDs an array of UNITIDs
#' @param years an array of years to pull
#' @return a dataframe with faculty salaries by year and UNITID
#' @export
get_ipeds_faculty_salaries <- function(idbc, UNITIDs = NULL, years = NULL) {

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

  tnames <- data.frame(Table = my_dbListTables(idbc, search_string = "^SAL\\d{4}_.+$")) |>
            mutate(Year = as.integer(substr(Table, 4,7)) - 1,
                   Suffix = substr(Table, 9,12)) |>
            filter( (Year < 2011 & Suffix == "A") | (Year >= 2011 & Suffix == "IS"))

  # if necessary, filter to the specified years
  if(!is.null(years)) {
    tnames <- tnames %>%
      filter(Year %in% !!years)
  }

  out <- data.frame()

  for(i in 1:nrow(tnames)) {
    year = tnames$Year[i]
    tname = tnames$Table[i]

    df <- tbl(idbc, tname) %>%
      filter(UNITID %in% !!UNITIDs) %>%
      collect() %>%
      mutate(Year = !!year) |>
      left_join(ranks)

    if(year < 2011){
      df <- df |>
        left_join(contract) |>
        filter(Contract == "Equated 9-month contract") |>
        select(UNITID, Year, Rank, N = EMPCNTT, AvgSalary = AVESALT)
    } else if (year < 2016) {
      df <- df |>
        select(UNITID, Year, Rank,
               N = SATOTLT,
               AvgSalary = SAAVMNT) |>
        mutate(AvgSalary = AvgSalary*9)
    } else {
      df <- df |>
        select(UNITID, Year, Rank,
               N = SAINSTT,
               AvgSalary = SAEQ9AT)
    }

    out <- rbind(out, df)

  }
  return(out)
}
