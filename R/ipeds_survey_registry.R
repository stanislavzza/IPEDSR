#' IPEDS Survey Registry
#' 
#' @description
#' Central registry of IPEDS survey table patterns and metadata. This provides
#' a single source of truth for survey identifiers, regex patterns, and survey
#' characteristics across all years in the database.
#' 
#' @details
#' Each survey has:
#' - **pattern**: Regex to match all tables for this survey across years
#' - **description**: Human-readable description of the survey
#' - **years_available**: Function to extract years from matched table names
#' - **table_format**: Description of how years/suffixes are encoded
#' - **notes**: Any special considerations (format changes, missing years, etc.)

#' IPEDS Survey Registry
#' 
#' @description
#' Registry of all IPEDS surveys with their regex patterns and metadata.
#' Use \code{get_survey_pattern()} to retrieve patterns for use in queries.
#' 
#' @format A named list where each element contains:
#' \describe{
#'   \item{pattern}{Regex pattern matching all tables for this survey}
#'   \item{description}{Human-readable survey description}
#'   \item{table_format}{How year is encoded in table name}
#'   \item{format_changes}{List of year/format changes if applicable}
#'   \item{notes}{Additional information about the survey}
#' }
#' 
#' @examples
#' # Get pattern for faculty salary surveys
#' get_survey_pattern("salaries")
#' 
#' # List all available surveys
#' list_surveys()
#' 
#' # Get metadata about a survey
#' get_survey_info("enrollment")
#' 
#' @export
IPEDS_SURVEY_REGISTRY <- list(
  
  # Personnel/HR Surveys
  salaries = list(
    pattern = "^sal\\d{4}_.+$",
    description = "Faculty Salaries (Instructional Staff)",
    table_format = "sal<YYYY>_<suffix>",
    format_changes = list(
      "pre-2012" = "sal<YYYY>_a (e.g., sal2010_a)",
      "2012+" = "sal<YYYY>_is for instructional staff (e.g., sal2015_is)"
    ),
    notes = "Suffix '_nis' exists for non-instructional staff. Format changed in 2012."
  ),
  
  faculty_staff = list(
    pattern = "^s\\d{4}_(f|is)$",
    description = "Fall Staff Survey (Faculty counts and demographics)",
    table_format = "s<YYYY>_<suffix>",
    format_changes = list(
      "pre-2012" = "s<YYYY>_f (e.g., s2010_f)",
      "2012+" = "s<YYYY>_is (e.g., s2015_is)"
    ),
    notes = "Format changed in 2012 from '_f' to '_is' suffix"
  ),
  
  employees = list(
    pattern = "^eap\\d{4}$",
    description = "Employees by Assigned Position (EAP)",
    table_format = "eap<YYYY>",
    notes = "Simple year-based naming, no suffixes"
  ),
  
  # Enrollment Surveys
  enrollment_fall = list(
    pattern = "^ef\\d{4}a$",
    description = "Fall Enrollment (12-month unduplicated headcount)",
    table_format = "ef<YYYY>a",
    format_changes = list(
      "2007-2009" = "Variable names changed multiple times",
      "2010+" = "Current variable schema"
    ),
    notes = "Check year for variable name changes (EFALEVEL, EFTOTLT, etc.)"
  ),
  
  enrollment_residence = list(
    pattern = "^ef\\d{4}d$",
    description = "Fall Enrollment - Residence and Migration",
    table_format = "ef<YYYY>d",
    notes = "Used for retention rate calculations"
  ),
  
  # Admissions Surveys  
  admissions_pre2014 = list(
    pattern = "^ic\\d{4}$",
    description = "Institutional Characteristics - Admissions (pre-2014)",
    table_format = "ic<YYYY>",
    notes = "Used for admissions data before 2014; format changed in 2014"
  ),
  
  admissions_2014plus = list(
    pattern = "^adm\\d{4}$",
    description = "Admissions Survey (2014+)",
    table_format = "adm<YYYY>",
    notes = "New format starting 2014; use IC tables for earlier years"
  ),
  
  # Completions/Graduation Surveys
  completions = list(
    pattern = "^c\\d{4}_a$",
    description = "Completions by CIP Code (Awards/Degrees Conferred)",
    table_format = "c<YYYY>_a",
    notes = "Awards for July 1 - June 30 of the year shown"
  ),
  
  graduation_rates = list(
    pattern = "^gr20\\d\\d$",
    description = "Graduation Rates Survey",
    table_format = "gr<YYYY>",
    format_changes = list(
      "pre-2008" = "Different format, skip these",
      "2008+" = "Current format with demographics"
    ),
    notes = "Format changed in 2008; rates as of August of year shown"
  ),
  
  graduation_pell = list(
    pattern = "^gr20\\d\\d_pell_ssl$",
    description = "Graduation Rates by Pell Status and Subsidized Loan Status",
    table_format = "gr<YYYY>_pell_ssl",
    notes = "Available for recent years only"
  ),
  
  # Financial Aid Surveys
  financial_aid = list(
    pattern = "^sfa\\d{4}",
    description = "Student Financial Aid Survey",
    table_format = "sfa<YYYY><suffix>",
    notes = "Multiple tables per year; exclude SFAV tables"
  ),
  
  # Finance Surveys
  finances = list(
    pattern = "^f\\d{4}_f2",
    description = "Finance Survey (Revenues, Expenses, Assets)",
    table_format = "f<YYYY>_f2",
    notes = "F2 is the most detailed finance table"
  ),
  
  tuition_fees = list(
    pattern = "^ic\\d{4}_ay$",
    description = "Institutional Characteristics - Student Charges (Tuition & Fees)",
    table_format = "ic<YYYY>_ay",
    notes = "Year 2005 has data issues, skip it"
  ),
  
  # Institutional Characteristics
  directory = list(
    pattern = "^hd\\d{4}$",
    description = "Institutional Characteristics - Directory Information (HD)",
    table_format = "hd<YYYY>",
    notes = "Core directory info: name, address, control, sector, etc."
  ),
  
  # Metadata Tables
  valuesets = list(
    pattern = "^valuesets\\d\\d$",
    description = "Value Sets (Code to Label Mappings)",
    table_format = "valuesets<YY>",
    notes = "Two-digit year (e.g., valuesets23 for 2023)"
  ),
  
  vartable = list(
    pattern = "^vartable\\d\\d$",
    description = "Variable Definitions and Descriptions",
    table_format = "vartable<YY>",
    notes = "Two-digit year (e.g., vartable23 for 2023)"
  )
)


#' Get Survey Pattern from Registry
#' 
#' @description
#' Retrieve the regex pattern for a specific IPEDS survey type.
#' Use this in \code{my_dbListTables()} to get all tables for a survey.
#' 
#' @param survey_name Name of the survey (see \code{list_surveys()})
#' @param validate If TRUE, warns if survey name not found (default: TRUE)
#' 
#' @return Character string with regex pattern, or NULL if not found
#' 
#' @examples
#' \dontrun{
#' # Get all faculty salary tables
#' pattern <- get_survey_pattern("salaries")
#' tables <- my_dbListTables(search_string = pattern)
#' 
#' # Get all enrollment tables
#' pattern <- get_survey_pattern("enrollment_fall")
#' tables <- my_dbListTables(search_string = pattern)
#' }
#' 
#' @export
get_survey_pattern <- function(survey_name, validate = TRUE) {
  if (!survey_name %in% names(IPEDS_SURVEY_REGISTRY)) {
    if (validate) {
      available <- paste(names(IPEDS_SURVEY_REGISTRY), collapse = ", ")
      warning("Survey '", survey_name, "' not found in registry.\n",
              "Available surveys: ", available)
    }
    return(NULL)
  }
  
  return(IPEDS_SURVEY_REGISTRY[[survey_name]]$pattern)
}


#' List All Available Surveys
#' 
#' @description
#' Get a list of all registered IPEDS surveys with their descriptions.
#' 
#' @param category Optional category filter: "personnel", "enrollment", 
#'   "admissions", "completions", "finance", "directory", "metadata"
#' @param as_dataframe If TRUE, returns a data frame; if FALSE, prints to console
#' 
#' @return Data frame with survey names and descriptions (if as_dataframe=TRUE)
#' 
#' @examples
#' \dontrun{
#' # List all surveys
#' list_surveys()
#' 
#' # Get as data frame for filtering
#' surveys_df <- list_surveys(as_dataframe = TRUE)
#' }
#' 
#' @export
list_surveys <- function(category = NULL, as_dataframe = FALSE) {
  surveys <- names(IPEDS_SURVEY_REGISTRY)
  descriptions <- sapply(surveys, function(s) {
    IPEDS_SURVEY_REGISTRY[[s]]$description
  })
  
  df <- data.frame(
    survey = surveys,
    description = descriptions,
    row.names = NULL,
    stringsAsFactors = FALSE
  )
  
  if (as_dataframe) {
    return(df)
  } else {
    cat("\nAvailable IPEDS Surveys:\n")
    cat(rep("=", 70), "\n", sep = "")
    for (i in seq_len(nrow(df))) {
      cat(sprintf("%-25s %s\n", df$survey[i], df$description[i]))
    }
    cat(rep("=", 70), "\n", sep = "")
    invisible(df)
  }
}


#' Get Detailed Survey Information
#' 
#' @description
#' Retrieve complete metadata about a survey including format changes,
#' table naming conventions, and special notes.
#' 
#' @param survey_name Name of the survey
#' 
#' @return List with all survey metadata, or NULL if not found
#' 
#' @examples
#' \dontrun{
#' # Get info about salary survey
#' info <- get_survey_info("salaries")
#' cat("Pattern:", info$pattern, "\n")
#' cat("Format:", info$table_format, "\n")
#' }
#' 
#' @export
get_survey_info <- function(survey_name) {
  if (!survey_name %in% names(IPEDS_SURVEY_REGISTRY)) {
    available <- paste(names(IPEDS_SURVEY_REGISTRY), collapse = ", ")
    warning("Survey '", survey_name, "' not found in registry.\n",
            "Available surveys: ", available)
    return(NULL)
  }
  
  info <- IPEDS_SURVEY_REGISTRY[[survey_name]]
  
  cat("\nSurvey:", survey_name, "\n")
  cat(rep("=", 70), "\n", sep = "")
  cat("Description:  ", info$description, "\n")
  cat("Pattern:      ", info$pattern, "\n")
  cat("Table Format: ", info$table_format, "\n")
  
  if (!is.null(info$format_changes)) {
    cat("\nFormat Changes:\n")
    for (period in names(info$format_changes)) {
      cat("  ", period, ": ", info$format_changes[[period]], "\n", sep = "")
    }
  }
  
  if (!is.null(info$notes)) {
    cat("\nNotes: ", info$notes, "\n")
  }
  
  cat(rep("=", 70), "\n", sep = "")
  
  invisible(info)
}


#' Get Tables for Survey Type
#' 
#' @description
#' Convenience function to get all table names for a survey type,
#' optionally filtered by year range.
#' 
#' @param survey_name Name of the survey
#' @param year_min Minimum year (optional, 4-digit)
#' @param year_max Maximum year (optional, 4-digit)
#' 
#' @return Character vector of table names
#' 
#' @examples
#' \dontrun{
#' # Get all salary tables
#' tables <- get_survey_tables("salaries")
#' 
#' # Get enrollment tables for 2015-2020
#' tables <- get_survey_tables("enrollment_fall", 
#'                              year_min = 2015, 
#'                              year_max = 2020)
#' }
#' 
#' @export
get_survey_tables <- function(survey_name, year_min = NULL, year_max = NULL) {
  pattern <- get_survey_pattern(survey_name, validate = TRUE)
  
  if (is.null(pattern)) {
    return(character(0))
  }
  
  tables <- my_dbListTables(search_string = pattern)
  
  # Filter by year if specified
  if (!is.null(year_min) || !is.null(year_max)) {
    # Extract 4-digit years from table names
    years <- as.integer(stringr::str_extract(tables, "\\d{4}"))
    
    if (!is.null(year_min)) {
      tables <- tables[years >= year_min]
      years <- years[years >= year_min]
    }
    
    if (!is.null(year_max)) {
      tables <- tables[years <= year_max]
    }
  }
  
  return(tables)
}
