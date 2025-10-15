#!/usr/bin/env Rscript
# Test updated get_variables() and get_valueset() functions

library(IPEDSR)

cat(paste(rep("=", 70), collapse=""), "\n")
cat("Testing get_variables() and get_valueset() functions\n")
cat(paste(rep("=", 70), collapse=""), "\n\n")

# Test 1: get_variables() with full table name
cat("Test 1: get_variables('HD2023')\n")
tryCatch({
  vars <- get_variables("HD2023")
  cat(sprintf("  ✓ Found %d variables\n", nrow(vars)))
  cat(sprintf("  Sample: %s = %s\n", vars$varName[1], vars$varTitle[1]))
}, error = function(e) {
  cat("  ✗ Error:", conditionMessage(e), "\n")
})

# Test 2: get_variables() with lowercase table name
cat("\nTest 2: get_variables('hd2023') - lowercase\n")
tryCatch({
  vars <- get_variables("hd2023")
  cat(sprintf("  ✓ Found %d variables\n", nrow(vars)))
}, error = function(e) {
  cat("  ✗ Error:", conditionMessage(e), "\n")
})

# Test 3: get_variables() with separate year parameter
cat("\nTest 3: get_variables('HD', year = 2023)\n")
tryCatch({
  vars <- get_variables("HD", year = 2023)
  cat(sprintf("  ✓ Found %d variables\n", nrow(vars)))
}, error = function(e) {
  cat("  ✗ Error:", conditionMessage(e), "\n")
})

# Test 4: get_valueset() with full table name
cat("\nTest 4: get_valueset('HD2023')\n")
tryCatch({
  vals <- get_valueset("HD2023")
  cat(sprintf("  ✓ Found %d value sets\n", nrow(vals)))
  cat(sprintf("  Sample: %s code %s = %s\n", 
              vals$varName[1], vals$Codevalue[1], vals$valueLabel[1]))
}, error = function(e) {
  cat("  ✗ Error:", conditionMessage(e), "\n")
})

# Test 5: get_valueset() with variable filter
cat("\nTest 5: get_valueset('HD2023', variable_name = 'SECTOR')\n")
tryCatch({
  vals <- get_valueset("HD2023", variable_name = "SECTOR")
  cat(sprintf("  ✓ Found %d codes for SECTOR\n", nrow(vals)))
  if (nrow(vals) > 0) {
    cat("  Codes:\n")
    for (i in 1:min(3, nrow(vals))) {
      cat(sprintf("    %s = %s\n", vals$Codevalue[i], vals$valueLabel[i]))
    }
  }
}, error = function(e) {
  cat("  ✗ Error:", conditionMessage(e), "\n")
})

# Test 6: get_valueset() with separate year
cat("\nTest 6: get_valueset('HD', year = 2023, variable_name = 'CONTROL')\n")
tryCatch({
  vals <- get_valueset("HD", year = 2023, variable_name = "CONTROL")
  cat(sprintf("  ✓ Found %d codes for CONTROL\n", nrow(vals)))
  if (nrow(vals) > 0) {
    cat("  Codes:\n")
    for (i in 1:nrow(vals)) {
      cat(sprintf("    %s = %s\n", vals$Codevalue[i], vals$valueLabel[i]))
    }
  }
}, error = function(e) {
  cat("  ✗ Error:", conditionMessage(e), "\n")
})

# Test 7: Test with older year (2015)
cat("\nTest 7: get_variables('HD', year = 2015)\n")
tryCatch({
  vars <- get_variables("HD", year = 2015)
  cat(sprintf("  ✓ Found %d variables for HD2015\n", nrow(vars)))
}, error = function(e) {
  cat("  ✗ Error:", conditionMessage(e), "\n")
})

cat("\n", paste(rep("=", 70), collapse=""), "\n")
cat("✅ All tests completed!\n")
cat(paste(rep("=", 70), collapse=""), "\n")
