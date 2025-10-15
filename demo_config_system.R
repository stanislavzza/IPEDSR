# Example: Testing IPEDSR Configuration System

library(IPEDSR)

# ============================================================================
# Demo: Setting up default institution
# ============================================================================

cat("\n=== IPEDSR Configuration Demo ===\n\n")

# 1. View current configuration (should be empty initially)
cat("1. Current configuration (initially empty):\n")
view_ipedsr_config()

cat("\n\n2. Setting default institution to Furman University (218070):\n")
set_ipedsr_config(default_unitid = 218070)

cat("\n\n3. Now let's test the functions:\n\n")

# 3a. Without specifying UNITID - should use default
cat("3a. get_characteristics() with NO UNITID specified:\n")
cat("    (Should return data for UNITID 218070)\n")
# chars <- get_characteristics(year = 2023)
# print(head(chars))

# 3b. With explicit UNITID - should override default
cat("\n3b. get_characteristics(UNITIDs = 139755) with EXPLICIT UNITID:\n")
cat("    (Should return data for UNITID 139755 - Davidson College)\n")
# chars_davidson <- get_characteristics(year = 2023, UNITIDs = 139755)
# print(head(chars_davidson))

# 4. Test session-level override with R options
cat("\n\n4. Testing session-level override:\n")
options(IPEDSR.default_unitid = 190150)  # Wake Forest
cat("   Set session option to 190150 (Wake Forest)\n")
cat("   get_characteristics() should now use 190150\n")
# chars_wake <- get_characteristics(year = 2023)
# print(head(chars_wake))

# Clear the option
options(IPEDSR.default_unitid = NULL)
cat("   Cleared session option - back to config file default (218070)\n")

# 5. View final configuration
cat("\n\n5. Final configuration:\n")
view_ipedsr_config()

# ============================================================================
# Practical workflow example
# ============================================================================

cat("\n\n=== Practical Workflow Example ===\n")

cat("\nScenario: Institutional researcher at Furman analyzing peer data\n\n")

# Set once (persists across sessions)
cat("Step 1: One-time setup\n")
cat("  set_ipedsr_config(default_unitid = 218070)\n\n")

# Daily analysis becomes simple
cat("Step 2: Daily analysis (no UNITIDs needed!)\n")
cat("  my_chars <- get_characteristics()\n")
cat("  my_finances <- get_finances()\n")
cat("  my_grad_rates <- get_grad_rates()\n\n")

# Peer comparisons when needed
cat("Step 3: Peer comparisons (explicit UNITIDs)\n")
peers <- c(218070, 139755, 190150)
cat("  peers <- c(218070, 139755, 190150)\n")
cat("  peer_data <- get_characteristics(UNITIDs = peers)\n\n")

# Hierarchy demonstration
cat("\n=== Configuration Hierarchy (highest to lowest priority) ===\n")
cat("1. Function arguments:       get_characteristics(UNITIDs = 123456)\n")
cat("2. R options (session):      options(IPEDSR.default_unitid = 123456)\n")
cat("3. Environment variables:    IPEDSR_DEFAULT_UNITID=123456 in .Renviron\n")
cat("4. Config file (persistent): set_ipedsr_config(default_unitid = 123456)\n")

cat("\n\nConfiguration system successfully implemented!\n")
cat("See CONFIGURATION_GUIDE.md for complete documentation.\n\n")
