#' Get financials
#' @param UNITIDs vector of UNITIDs to retrieve
#' @return Dataframe with endowment, revenue and other statistics
#' @export
get_finances <- function(UNITIDs = NULL){
  idbc <- ensure_connection()

  # find all the tables
  tnames <- my_dbListTables(search_string = "^F\\d{4}_F2")

  out <- data.frame()

  for(tname in tnames) {

    # use the fall near, not the year on the table name
    year <- 2000 + as.integer(substr(tname, 2,3))


    if(year < 2009){
      df <- dplyr::tbl(idbc,tname) %>%
        dplyr::select(UNITID,
               F2A05, # Total restricted net assets
               F2A05A, # Permanently restricted net assets included in total restricted net assets
               F2B01,  # total revenue
               F2B02,  # total expenses
               Total_unrestricted_net_assets = F2A04,
               Total_expenses = F2E131,
               Change_in_net_assets = F2B04,
               Net_assets = F2B05,
               Cost_instruction = F2E011,
               Cost_instruction_salary  = F2E012,
               Cost_acad_support = F2E041,
               Cost_student_serv = F2E051,
               Cost_inst_support = F2E061,
               Cost_aux_ent      = F2E071,
               Cost_total_salary = F2E132,
               Cost_total_benefit = F2E133,
               Cost_operations    = F2E134,
               Cost_depreciation  = F2E135,
               Cost_interest      = F2E136,
               Cost_other         = F2E137,
               Endowment          = F2H02,
               Investment_return  = F2D10, # from endowment
               Net_tuition_revenue = F2D01, # it really is; checked against audit
               Funded_aid         = F2C05,
               Inst_aid           = F2C06
        )

      if (!is.null(UNITIDs)) {
        df <- df %>% dplyr::filter(UNITID %in% !!UNITIDs)
      }

      df <- df %>%
        dplyr::collect() %>%
        dplyr::mutate( Year = year,
                Temporarily_restricted_net_assets = F2A05 - F2A05A,
                Property_Plant_Equipment_net_depreciation = NA,
                Debt_Property_Plant_Equipment = NA,
                Net_total_revenues = F2B01 - F2B02,
                Endowment = as.numeric(Endowment)) %>%
        dplyr::select(-F2A05, -F2A05A, -F2B01, -F2B02)

    } else {

      df <- dplyr::tbl(idbc,tname) %>%
        dplyr::select(UNITID,
               Total_unrestricted_net_assets = F2A04,
               Temporarily_restricted_net_assets = F2A05B,
               Property_Plant_Equipment_net_depreciation = F2A19,
               Debt_Property_Plant_Equipment = F2A03A,
               Total_expenses = F2E131,
               Change_in_net_assets = F2B04,
               Net_assets = F2B05,
               Net_total_revenues = F2D182,
               Cost_instruction = F2E011,
               Cost_instruction_salary = F2E012,
               Cost_acad_support = F2E041,
               Cost_student_serv = F2E051,
               Cost_inst_support = F2E061,
               Cost_aux_ent      = F2E071,
               Cost_total_salary = F2E132,
               Cost_total_benefit = F2E133,
               Cost_operations    = F2E134,
               Cost_depreciation  = F2E135,
               Cost_interest      = F2E136,
               Cost_other         = F2E137,
               Endowment          = F2H02,
               Investment_return  = F2D10, # from endowment and other
               Net_tuition_revenue = F2D01,
               # institutional aid, funded and unfunded
               Funded_aid         = F2C05,
               Inst_aid           = F2C06) %>%
        dplyr::mutate(Year = year,
               Endowment = as.numeric(Endowment))

      if (!is.null(UNITIDs)) {
        df <- df %>% dplyr::filter(UNITID %in% !!UNITIDs)
      }

      df <- df %>% dplyr::collect()
    }
    out <- rbind(out, df)

  } # end of loop
  return(out)
}

#' Get IPEDS tuition
#' @param UNITIDs IPEDS school IDs. If NULL, gets everything
#' @return A dataframe with UNITID, Year, Tuition, Fees, RoomBoard for undergrad
#' @export
get_tuition <- function(UNITIDs = NULL){
  idbc <- ensure_connection()

  # find all the tables
  tnames <- my_dbListTables(search_string = "^IC\\d{4}_AY$")

  out <- data.frame()

  for(tname in tnames) {

    # use the fall near, not the year on the table name
    year <- as.integer(substr(tname, 3,6))

    if(year == 2005) next # it's screwed up

    # some of the column names are lowercase, sigh
    df <-  try(
      dplyr::tbl(idbc, tname)  %>%
        dplyr::select(UNITID,
               Tuition = TUITION1,
               Fees    = FEE1,
               RoomBoard = chg5ay2), TRUE
    )

    if(inherits(df, "try-error")) {

      df <-  try(
        dplyr::tbl(idbc, tname)  %>%
          dplyr::select(UNITID,
                 Tuition = TUITION1,
                 Fees    = FEE1,
                 RoomBoard = CHG5AY2), TRUE
      )
    }

    if (!is.null(UNITIDs)) {
      df <- df %>% dplyr::filter(UNITID %in% !!UNITIDs)
    }

    df <- df %>% dplyr::collect() %>%
      dplyr::mutate(Year = year) %>%
      dplyr::mutate(Tuition = as.integer(Tuition),
             Fees = as.integer(Fees),
             RoomBoard = as.integer(RoomBoard),
             TotalCost = Tuition + Fees + RoomBoard)

    out <- rbind(out, df)
  }

  return(out)
}
