% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/ipeds_completions.R
\name{get_grad_demo_rates}
\alias{get_grad_demo_rates}
\title{Get demographic grad rates}
\usage{
get_grad_demo_rates(idbc, UNITIDs = NULL)
}
\arguments{
\item{idbc}{Database connector}

\item{UNITIDs}{Array of identifiers}
}
\value{
Long dataframe with year, unitid, demographic categories, cohort sizes,
and numbers of grad at 100 and 150%. Four and six year rates are generated.
Only returns data after 2007. Rates are as of August 31 of the identified year.
}
\description{
Get four- and six-year graduation rates for cohort undergraduates for
race and gender
}
