# Create Tables24 to catalog 2024 data tables
# This creates a table similar to Tables23 that describes the 2024 data tables

library(DBI)
source("R/database_management.R")

# Connect to database
con <- get_ipeds_connection(read_only = FALSE)

# Define the 2024 tables and their metadata
tables24_data <- data.frame(
  SurveyOrder = c(10, 10, 10, 10, 20, 30, 31),
  SurveyNumber = c(1, 1, 1, 1, 2, 3, 3),
  Survey = c(
    "Institutional Characteristics",
    "Institutional Characteristics", 
    "Institutional Characteristics",
    "Institutional Characteristics",
    "12-month Enrollment",
    "Finance",
    "Finance"
  ),
  YearCoverage = c(
    "Academic year 2024-25",
    "Academic year 2024-25",
    "Academic year 2024-25", 
    "Academic year 2024-25",
    "July 1, 2023 to June 30, 2024",
    "Fiscal year 2024",
    "Fiscal year 2024"
  ),
  TableName = c("HD2024", "FLAGS2024", "IC2024", "EFFY2024", "EFFY2024", "EFIA2024", "DRVC2024"),
  Tablenumber = c(10, 11, 12, 13, 14, 15, 16),
  TableTitle = c(
    "Directory information",
    "Response status for all survey components", 
    "Educational offerings, organization, admissions, services and athletic associations",
    "Fall enrollment by race/ethnicity and gender",
    "12-month unduplicated headcount",
    "Finance data",
    "Finance derived variables"
  ),
  Release = c(
    "Provisional/final (institutions are not allowed to revise these data)",
    "Provisional",
    "Provisional", 
    "Provisional",
    "Provisional",
    "Provisional",
    "Provisional"
  ),
  `Release date` = rep("TBD 2025", 7),
  F11 = rep(NA, 7),
  F12 = rep(NA, 7), 
  F13 = rep(NA, 7),
  F14 = rep(NA, 7),
  F15 = rep(NA, 7),
  F16 = rep(NA, 7),
  Description = c(
    "This table contains directory information for every institution in the 2024 IPEDS universe. Includes name, address, city, state, zip code and various URL links to the institution's home page, admissions, financial aid offices and the net price calculator. Identifies institutions as currently active, institutions that participate in Title IV federal financial aid programs for which IPEDS is mandatory. It also includes variables derived from the 2024-25 Institutional Characteristics survey, such as control and level of institution, highest level and highest degree offered and Carnegie classifications.",
    "This table contains response status information for each survey component for every institution in the 2024-25 IPEDS universe. This table identifies institutions that have responded; institutions that did not respond and have imputed data; survey applicability. It will also identify institutions whose data represents multiple campuses (parent/child reporting). For final/revised releases, it will also identify those institutions that submitted revised data by survey component.",
    "This table contains data on program and award level offerings, control and affiliation and special learning opportunities. Several variables including open admissions policy, distance education offerings and library services are updated based on admissions data collected in the winter. Beginning in 2020-21, the less-than-1-year certificate award level is divided into the following two award levels: certificates of less-than-12-weeks and certificates of at least 12 weeks but less than 1 year.",
    "This table contains enrollment data by race/ethnicity and gender for fall 2024.",
    "This table contains 12-month unduplicated headcount enrollment data.",
    "This table contains financial data reported by institutions for fiscal year 2024.",
    "This table contains derived variables calculated from finance data."
  ),
  stringsAsFactors = FALSE
)

# Fix column names (R doesn't like spaces)
colnames(tables24_data)[which(colnames(tables24_data) == "Release.date")] <- "Release date"

cat("Creating Tables24 with", nrow(tables24_data), "rows\n")
print(tables24_data[, c("TableName", "TableTitle")])

# Write to database
dbWriteTable(con, "Tables24", tables24_data, overwrite = TRUE)
cat("Tables24 successfully created in database\n")

# Verify the table
cat("\nVerification:\n")
result <- dbGetQuery(con, "SELECT COUNT(*) as count FROM Tables24")
cat("Tables24 has", result$count, "rows\n")

cat("\nSample from Tables24:\n")
sample_data <- dbGetQuery(con, "SELECT TableName, TableTitle FROM Tables24")
print(sample_data)

dbDisconnect(con)
cat("\nTables24 creation complete!\n")