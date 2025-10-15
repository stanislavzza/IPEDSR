# Check for uppercase vs lowercase 2024 tables
library(IPEDSR)
con <- ensure_connection()

all_tables <- DBI::dbListTables(con)
all_2024 <- grep("2024", all_tables, value = TRUE)

upper_2024 <- all_2024[grepl("[A-Z]", all_2024)]
lower_2024 <- all_2024[!grepl("[A-Z]", all_2024)]

cat("Uppercase 2024 tables:", length(upper_2024), "\n")
for(t in upper_2024) cat(" -", t, "\n")

cat("Lowercase 2024 tables:", length(lower_2024), "\n") 
for(t in lower_2024) cat(" -", t, "\n")

# Let's also check if we can query a specific lowercase table
cat("\nTesting if lowercase table exists:\n")
tryCatch({
  result <- DBI::dbGetQuery(con, 'SELECT COUNT(*) as n FROM "hd2024"')
  cat("hd2024 exists with", result$n, "rows\n")
}, error = function(e) {
  cat("hd2024 does not exist:", e$message, "\n")
})