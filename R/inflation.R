#' Cumulative inflation rates
#' @description Calculates a cumulative inflation rate for a given time period.
#' @param idbc database connector to the IPEDS database
#' @param start_year the first year to include
#' @param end_year the last year to include
#' @return a list with three elements: annual data, cumulative rate, and average annual rate.
#' @details The result is the cumulative inflation rate from the start year to the end year.
#' The calculation multiplies by one plus the  rate for each year. Finally, one
#' is subtracted to give a cumlative rate.
#' @export
cum_inflation <- function(idbc, start_year, end_year){
  inflation <- tbl(idbc, "Inflation") |>
               filter(Year >= start_year, Year <= end_year) |>
               select(Year, InflationRate) |>
               collect() |>
               # the rate is like .03. Turn it into a multiplier 1.03
               mutate(Multiplier = InflationRate + 1,
                      lograte = log(Multiplier),
                      const_dollar = exp(cumsum(lograte)),
                      const_dollar = const_dollar  / min(const_dollar )) |>
    select(-lograte)

  cum_rate <- prod(inflation$Multiplier)

  annual_rate <- exp( log(cum_rate) / (end_year - start_year + 1) )

  return(list(annual = inflation,
              cum_rate = cum_rate - 1,
              annual_rate = annual_rate - 1))


}
