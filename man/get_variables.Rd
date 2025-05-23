% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/ipeds_utilities.R
\name{get_variables}
\alias{get_variables}
\title{Get IPEDS variable names}
\usage{
get_variables(idbc, my_table)
}
\arguments{
\item{idbc}{database connector to IPEDS db}

\item{my_table}{The IPEDS table being accessed}
}
\description{
Given a table name
look up the variables and their friendly labels.,
e.g. STABBR is state abbreviation.
}
