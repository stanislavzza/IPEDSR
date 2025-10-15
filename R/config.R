#' IPEDSR Configuration Management
#' 
#' Functions for managing user-specific configuration settings

#' Get the path to the configuration file
#' @return Character string with the config file path
#' @keywords internal
get_config_path <- function() {
  data_dir <- rappdirs::user_data_dir("IPEDSR", "FurmanIR")
  if (!dir.exists(data_dir)) {
    dir.create(data_dir, recursive = TRUE, showWarnings = FALSE)
  }
  file.path(data_dir, "config.yaml")
}

#' Get IPEDSR configuration
#' @param key Optional specific configuration key to retrieve. If NULL, returns all configuration.
#' @param default Default value to return if key is not found
#' @return Configuration value(s)
#' @export
#' @examples
#' \dontrun{
#' # Get all configuration
#' get_ipedsr_config()
#' 
#' # Get specific value
#' get_ipedsr_config("default_unitid")
#' 
#' # Get with default if not set
#' get_ipedsr_config("default_unitid", default = 218070)
#' }
get_ipedsr_config <- function(key = NULL, default = NULL) {
  
  # First check R options (session-level override)
  if (!is.null(key)) {
    option_name <- paste0("IPEDSR.", key)
    option_value <- getOption(option_name, default = NULL)
    if (!is.null(option_value)) {
      return(option_value)
    }
  }
  
  # Then check environment variables
  if (!is.null(key)) {
    env_name <- paste0("IPEDSR_", toupper(gsub("\\.", "_", key)))
    env_value <- Sys.getenv(env_name, unset = "")
    if (env_value != "") {
      # Try to convert to integer if it looks like a UNITID
      if (key == "default_unitid" && grepl("^[0-9]+$", env_value)) {
        return(as.integer(env_value))
      }
      return(env_value)
    }
  }
  
  # Finally check config file
  config_path <- get_config_path()
  
  if (!file.exists(config_path)) {
    return(if (is.null(key)) list() else default)
  }
  
  tryCatch({
    config <- yaml::read_yaml(config_path)
    
    if (is.null(key)) {
      return(config)
    } else {
      value <- config[[key]]
      return(if (is.null(value)) default else value)
    }
  }, error = function(e) {
    warning("Error reading config file: ", e$message)
    return(if (is.null(key)) list() else default)
  })
}

#' Set IPEDSR configuration
#' @param ... Named configuration values to set (e.g., default_unitid = 218070)
#' @param .overwrite If FALSE (default), merge with existing config. If TRUE, replace entire config.
#' @return Invisibly returns the updated configuration
#' @export
#' @examples
#' \dontrun{
#' # Set default institution
#' set_ipedsr_config(default_unitid = 218070)
#' 
#' # Set multiple values
#' set_ipedsr_config(
#'   default_unitid = 218070,
#'   default_peer_group = c(139755, 190150, 218070)
#' )
#' 
#' # Replace entire configuration
#' set_ipedsr_config(default_unitid = 218070, .overwrite = TRUE)
#' }
set_ipedsr_config <- function(..., .overwrite = FALSE) {
  
  new_config <- list(...)
  
  if (length(new_config) == 0) {
    message("No configuration values provided.")
    return(invisible(NULL))
  }
  
  config_path <- get_config_path()
  
  # Load existing config if not overwriting
  if (!.overwrite && file.exists(config_path)) {
    existing_config <- tryCatch(
      yaml::read_yaml(config_path),
      error = function(e) list()
    )
  } else {
    existing_config <- list()
  }
  
  # Merge configurations
  final_config <- if (.overwrite) new_config else utils::modifyList(existing_config, new_config)
  
  # Write configuration
  tryCatch({
    yaml::write_yaml(final_config, config_path)
    message("Configuration saved to: ", config_path)
    message("\nCurrent configuration:")
    print_config(final_config)
    invisible(final_config)
  }, error = function(e) {
    stop("Error writing config file: ", e$message)
  })
}

#' Reset IPEDSR configuration
#' @param confirm If TRUE, skip confirmation prompt
#' @return Invisibly returns TRUE if reset was successful
#' @export
#' @examples
#' \dontrun{
#' # Reset configuration (will prompt for confirmation)
#' reset_ipedsr_config()
#' 
#' # Reset without confirmation
#' reset_ipedsr_config(confirm = TRUE)
#' }
reset_ipedsr_config <- function(confirm = FALSE) {
  config_path <- get_config_path()
  
  if (!file.exists(config_path)) {
    message("No configuration file exists. Nothing to reset.")
    return(invisible(FALSE))
  }
  
  if (!confirm) {
    response <- readline(prompt = "Are you sure you want to reset all configuration? (yes/no): ")
    if (tolower(trimws(response)) != "yes") {
      message("Reset cancelled.")
      return(invisible(FALSE))
    }
  }
  
  tryCatch({
    file.remove(config_path)
    message("Configuration reset successfully.")
    invisible(TRUE)
  }, error = function(e) {
    stop("Error resetting configuration: ", e$message)
  })
}

#' View current IPEDSR configuration
#' @return Invisibly returns the configuration list
#' @export
#' @examples
#' \dontrun{
#' view_ipedsr_config()
#' }
view_ipedsr_config <- function() {
  config <- get_ipedsr_config()
  
  if (length(config) == 0) {
    message("No configuration file found.")
    message("\nTo set configuration, use:")
    message("  set_ipedsr_config(default_unitid = YOUR_UNITID)")
    message("\nConfiguration hierarchy:")
    message("  1. Function arguments (highest priority)")
    message("  2. R options (session-level): options(IPEDSR.default_unitid = VALUE)")
    message("  3. Environment variables: IPEDSR_DEFAULT_UNITID=VALUE")
    message("  4. Config file (persistent): set_ipedsr_config()")
  } else {
    message("Current IPEDSR Configuration:")
    message("Location: ", get_config_path())
    message("")
    print_config(config)
    message("\nConfiguration hierarchy:")
    message("  1. Function arguments (highest priority)")
    message("  2. R options: options(IPEDSR.default_unitid = VALUE)")
    message("  3. Environment variables: IPEDSR_DEFAULT_UNITID=VALUE")
    message("  4. Config file (lowest priority)")
  }
  
  invisible(config)
}

#' Print configuration in a readable format
#' @param config Configuration list
#' @keywords internal
print_config <- function(config) {
  for (name in names(config)) {
    value <- config[[name]]
    if (length(value) > 1) {
      cat(sprintf("  %s: [%s]\n", name, paste(value, collapse = ", ")))
    } else {
      cat(sprintf("  %s: %s\n", name, value))
    }
  }
}

#' Get default UNITID from configuration
#' @param override Optional UNITID value that takes precedence over config
#' @return Integer UNITID or NULL if not configured
#' @keywords internal
get_default_unitid <- function(override = NULL) {
  if (!is.null(override)) {
    return(override)
  }
  
  get_ipedsr_config("default_unitid", default = NULL)
}

#' Check if package dependencies are available
#' @keywords internal
check_yaml_available <- function() {
  if (!requireNamespace("yaml", quietly = TRUE)) {
    stop(
      "Package 'yaml' is required for configuration management.\n",
      "Install it with: install.packages('yaml')",
      call. = FALSE
    )
  }
}

# Check yaml availability when config functions are called
.onLoad <- function(libname, pkgname) {
  # Silently check if yaml is available
  # Don't require it on load, only when config functions are used
  invisible(NULL)
}
