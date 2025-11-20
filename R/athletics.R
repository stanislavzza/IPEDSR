#' Get athletics summary data from EADA survey
#' @param idbc database connector
#' @param UNITIDs optional array of UNITIDs to filter to
#' @export
#' @return A dataframe with Year, UNITID and selected summary statistics from the EADA
#' data set.
#' @export
get_athletics <- function(idbc, UNITIDs = NULL){

  # through 2011, the tables are sYYYY_f, and after that
  # it's sYYYY_is
  tnames <- my_dbListTables(idbc, search_string = "^EADA_\\d\\d\\d\\d$")
  dnames <- my_dbListTables(idbc, search_string = "^EADA_DICT_\\d\\d\\d\\d$")

  out <- data.frame()

  for (tname in tnames){
    Year = as.integer(substr(tname, 6,9))

    if (Year <=  2005){

        df <- tbl(idbc, tname) %>% #collect()
          select(UNITID = unitid,
                 Athlete_men = c8,
                 Athlete_women = c9,
                 Athlete_Aid = A7,
                 Athlete_Revenue = d105,
                 Athlete_Expense = d114,
                 Classification = value_name)

        if(!is.null(UNITIDs)) df <- df %>% filter(UNITID %in% !!UNITIDs)

        df <- df %>%
          collect() %>%
          mutate(Athlete_N = Athlete_men + Athlete_women,
                 Year = Year)

      } else if(Year == 2018) {

        df <- tbl(idbc, tname) %>%
          select(UNITID = unitid,
                 Athlete_men = UNDUP_CT_PARTIC_MEN,
                 Athlete_women = UNDUP_CT_PARTIC_WOMEN,
                 Athlete_Aid = STUDENTAID_TOTAL,
                 Athlete_Revenue = GRND_TOTAL_REVENUE,
                 Athlete_Expense = GRND_TOTAL_EXPENSE,
                 Classification = ClassificationName) # good lord

        if(!is.null(UNITIDs)) df <- df %>% filter(UNITID %in% !!UNITIDs)

        df <- df |>
          collect() %>%
          mutate(Athlete_N = Athlete_men + Athlete_women,
                 Year = Year)
      } else {
        df <- tbl(idbc, tname) %>%
          select(UNITID = unitid,
                 Athlete_men = UNDUP_CT_PARTIC_MEN,
                 Athlete_women = UNDUP_CT_PARTIC_WOMEN,
                 Athlete_Aid = STUDENTAID_TOTAL,
                 Athlete_Revenue = GRND_TOTAL_REVENUE,
                 Athlete_Expense = GRND_TOTAL_EXPENSE,
                 Classification = classification_name)

        if(!is.null(UNITIDs)) df <- df %>% filter(UNITID %in% !!UNITIDs)

        df <- df |>
          collect() %>%
          mutate(Athlete_N = Athlete_men + Athlete_women,
                 Year = Year)

      }

      out <- rbind(out, df)
  }

  return(out)
}


#' Get athletics detailed sports data from EADA survey
#' @param idbc database connector
#' @param UNITIDs optional array of UNITIDs to filter to
#' @return A dataframe with Year, UNITID and selected sports summary statistics from the EADA in long format
#' data set.
#' @export
get_athletics_sports <- function(idbc, UNITIDs = NULL){


  tnames <- my_dbListTables(idbc, search_string = "^EADA_DETAIL")

  out <- data.frame()

  for (tname in tnames){
    # table name is the correct year -- don't subtract one
    Year = as.integer(substr(tname, 13,16))

    if (Year <=  2005)  next

    df <- tbl(idbc, tname) %>%
        select(UNITID = unitid,
               Sport  = Sports,
               Sport_men = PARTIC_MEN,
               Sport_women = PARTIC_WOMEN,
               Sport_expense = TOTAL_EXPENSE_ALL,
               Sport_expense_men = EXPENSE_MENALL,
               Sport_expense_women = EXPENSE_WOMENALL)

    if(!is.null(UNITIDs)) df <- df %>% filter(UNITID %in% !!UNITIDs)

    df <- df %>%
        collect() %>%
        mutate(Year = Year) %>%
        replace_na(list(Sport_men = 0,
                        Sport_women = 0,
                        Sport_expense = 0,
                        Sport_expense_men = 0,
                        Sport_expense_women = 0)) %>%
      # some sports don't exist at an institution
      filter(Sport_men + Sport_women > 0)


    out <- rbind(out, df)
  }

  return(out)
}
