# IPEDSR Configuration Guide

## Setting Your Default Institution

IPEDSR allows you to set a default institution UNITID so you don't have to specify it every time you call a function. This is particularly useful for institutional researchers who primarily work with their own institution's data.

### Quick Start

```r
library(IPEDSR)

# Set your default institution (e.g., Furman University)
set_ipedsr_config(default_unitid = 218070)

# Now you can call functions without specifying UNITIDs
get_characteristics()          # Returns data for 218070
get_finances()                # Returns data for 218070
get_grad_rates()             # Returns data for 218070
```

### Configuration System

IPEDSR uses a hierarchical configuration system with the following priority (highest to lowest):

1. **Function arguments** (always takes precedence)
2. **R options** (session-specific)
3. **Environment variables** (system-wide)
4. **Configuration file** (persistent, user-specific)

### Configuration File Approach (Recommended)

The configuration file is stored in your system's user data directory and persists across R sessions.

#### Setting Configuration

```r
# Set default institution
set_ipedsr_config(default_unitid = 218070)

# Set multiple values at once
set_ipedsr_config(
  default_unitid = 218070,
  default_peer_group = c(139755, 190150, 218070)
)

# Replace entire configuration (overwrites existing)
set_ipedsr_config(default_unitid = 218070, .overwrite = TRUE)
```

#### Viewing Configuration

```r
# View all configuration settings
view_ipedsr_config()

# Get specific value
get_ipedsr_config("default_unitid")

# Get with default if not set
get_ipedsr_config("default_unitid", default = 218070)
```

#### Resetting Configuration

```r
# Reset all configuration (will prompt for confirmation)
reset_ipedsr_config()

# Reset without confirmation
reset_ipedsr_config(confirm = TRUE)
```

### R Options Approach (Session-Level)

For temporary overrides within a session, you can use R options:

```r
# Set for current session only
options(IPEDSR.default_unitid = 139755)

# Use functions - they'll use the session option
get_characteristics()  # Returns data for 139755

# Clear the option
options(IPEDSR.default_unitid = NULL)
```

### Environment Variables Approach (System-Wide)

For system-wide configuration, add to your `.Renviron` file:

```bash
# In ~/.Renviron
IPEDSR_DEFAULT_UNITID=218070
```

Then restart R:

```r
# Functions will automatically use the environment variable
get_characteristics()
```

### Override Hierarchy Examples

```r
# Scenario 1: Config file sets default to 218070
set_ipedsr_config(default_unitid = 218070)
get_characteristics()  # Uses 218070 from config file

# Scenario 2: Session option overrides config file
options(IPEDSR.default_unitid = 139755)
get_characteristics()  # Uses 139755 from session option

# Scenario 3: Function argument overrides everything
get_characteristics(UNITIDs = 190150)  # Uses 190150 from argument
```

### Working with Peer Groups

While the default_unitid affects individual institution queries, you can still easily work with peer groups:

```r
# Set your institution as default
set_ipedsr_config(default_unitid = 218070)

# Get data for just your institution
my_data <- get_characteristics()

# Get data for peer group (overrides default)
peers <- c(218070, 139755, 190150)
peer_data <- get_characteristics(UNITIDs = peers)

# Compare your institution to peers
library(dplyr)
my_vs_peers <- peer_data %>%
  mutate(IsMine = UNITID == 218070)
```

### Configuration File Location

The configuration file is stored at:

- **macOS**: `~/Library/Application Support/IPEDSR/config.yaml`
- **Windows**: `%APPDATA%/IPEDSR/config.yaml`
- **Linux**: `~/.local/share/IPEDSR/config.yaml`

You can edit this file manually if needed, but it's recommended to use the `set_ipedsr_config()` function.

### Future Configuration Options

The configuration system is designed to be extensible. Future versions may include additional options such as:

- Default peer group lists
- Default years or date ranges
- Preferred label settings
- Custom variable mappings

### Troubleshooting

#### "yaml package not found"

If you see an error about the yaml package:

```r
install.packages("yaml")
```

#### Check what value is being used

```r
# See the configuration hierarchy
view_ipedsr_config()

# Check what a specific function will use
get_ipedsr_config("default_unitid")
```

#### Reset to factory defaults

```r
reset_ipedsr_config(confirm = TRUE)
```

### Best Practices

1. **Set institution-specific defaults in .Rprofile**: For personal research
2. **Use function arguments for peer comparisons**: Explicit is better than implicit
3. **Document configuration in project READMEs**: Help collaborators understand your setup
4. **Use session options for temporary changes**: Avoid modifying config file repeatedly

### Example Workflow

```r
# One-time setup (per user/computer)
library(IPEDSR)
set_ipedsr_config(default_unitid = 218070)  # Furman University

# Daily analysis workflow
library(IPEDSR)

# Quick queries for your institution
chars <- get_characteristics()
finances <- get_finances()
grad_rates <- get_grad_rates()

# Peer comparisons when needed
peer_ids <- c(218070, 139755, 190150)
peer_comparison <- get_characteristics(UNITIDs = peer_ids)

# Your default is always there when you need it
enrollment <- ipeds_get_enrollment()  # Uses default
```

This makes IPEDSR much more convenient for daily institutional research work!
