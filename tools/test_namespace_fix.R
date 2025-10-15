#!/usr/bin/env Rscript
# Test script to verify namespace fixes work correctly
# Run this in a clean R session to ensure functions work without tidyverse

cat("=" ,"=", sep = rep("=", 70), "\n")
cat("Testing IPEDSR Namespace Fixes (Bug #9)\n")
cat("This test verifies functions work WITHOUT tidyverse loaded\n")
cat("=", "=\n", sep = rep("=", 70))

# Load only IPEDSR - DO NOT load tidyverse!
library(IPEDSR)

cat("\n✓ IPEDSR loaded\n")
cat("✗ tidyverse NOT loaded (this is intentional!)\n\n")

# Verify tidyverse is not loaded
if ("package:tidyverse" %in% search()) {
  stop("❌ ERROR: tidyverse is loaded! Detach it and try again.")
}

cat("Starting tests...\n\n")

# Track results
results <- list()

# Test wrapper function
test_function <- function(func_name, func_call) {
  cat(sprintf("Testing %s...", func_name))
  
  tryCatch({
    result <- func_call
    if (is.data.frame(result) && nrow(result) > 0) {
      cat(sprintf(" ✅ (%d rows)\n", nrow(result)))
      return(TRUE)
    } else {
      cat(" ✅ (empty result is OK)\n")
      return(TRUE)
    }
  }, error = function(e) {
    cat(sprintf(" ❌\n  Error: %s\n", e$message))
    return(FALSE)
  })
}

# Run tests
cat("━", "━\n", sep = rep("━", 70))
cat("1. Testing get_grad_demo_rates()\n")
cat("━", "━\n", sep = rep("━", 70))
results$grad_demo <- test_function(
  "get_grad_demo_rates()",
  get_grad_demo_rates()
)

cat("\n")
cat("━", "━\n", sep = rep("━", 70))
cat("2. Testing get_grad_pell_rates()\n")
cat("━", "━\n", sep = rep("━", 70))
results$grad_pell <- test_function(
  "get_grad_pell_rates()",
  get_grad_pell_rates()
)

cat("\n")
cat("━", "━\n", sep = rep("━", 70))
cat("3. Testing ipeds_get_enrollment()\n")
cat("━", "━\n", sep = rep("━", 70))
results$enrollment <- test_function(
  "ipeds_get_enrollment()",
  ipeds_get_enrollment()
)

cat("\n")
cat("━", "━\n", sep = rep("━", 70))
cat("4. Testing get_retention()\n")
cat("━", "━\n", sep = rep("━", 70))
results$retention <- test_function(
  "get_retention()",
  get_retention()
)

cat("\n")
cat("━", "━\n", sep = rep("━", 70))
cat("5. Testing get_admit_funnel()\n")
cat("━", "━\n", sep = rep("━", 70))
results$admit_funnel <- test_function(
  "get_admit_funnel()",
  get_admit_funnel()
)

cat("\n")
cat("━", "━\n", sep = rep("━", 70))
cat("6. Testing get_cohort_stats()\n")
cat("━", "━\n", sep = rep("━", 70))
results$cohort_stats <- test_function(
  "get_cohort_stats()",
  get_cohort_stats()
)

cat("\n")
cat("━", "━\n", sep = rep("━", 70))
cat("7. Testing get_cips()\n")
cat("━", "━\n", sep = rep("━", 70))
results$cips <- test_function(
  "get_cips()",
  get_cips()
)

# Summary
cat("\n")
cat("=", "=\n", sep = rep("=", 70))
cat("Test Summary\n")
cat("=", "=\n", sep = rep("=", 70))

passed <- sum(unlist(results))
total <- length(results)

cat(sprintf("\nPassed: %d/%d\n", passed, total))

if (passed == total) {
  cat("\n🎉 All tests passed!\n")
  cat("✅ Functions work correctly without tidyverse loaded\n")
  cat("✅ Namespace fixes are working properly\n")
  cat("✅ Bug #9 is FIXED!\n\n")
} else {
  cat("\n❌ Some tests failed!\n")
  cat("Failed functions:\n")
  for (name in names(results)) {
    if (!results[[name]]) {
      cat(sprintf("  - %s\n", name))
    }
  }
  cat("\n")
  stop("Tests failed - namespace issues remain")
}

cat("=", "=\n", sep = rep("=", 70))
cat("Test complete. You can now use IPEDSR functions without tidyverse!\n")
cat("=", "=\n", sep = rep("=", 70))
