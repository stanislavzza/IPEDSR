#' Find matching tables
#' @param search_string A string to search for in the table names
#' @return A character vector of table names that match the search string
#' @export
my_dbListTables <- function(search_string){
  idbc <- ensure_connection()
  tables <- DBI::dbListTables(idbc)
  tables <- tables[stringr::str_detect(toupper(tables), search_string)]
  return(tables)
}

#' Convert to friendly names
#' @description Given results from an IPEDS table,
#' create a long dataframe with friendly variable names
#' and translated code values.
#' @param my_table The IPEDS table being accessed
#' @param df Data from the table given
#' @param verbose Logical, defaults to FALSE--Include the long descriptions of vars?
#' @export
get_labels <- function(my_table, df, verbose = FALSE){
  vars     <- get_variables(my_table)
  valueset <- get_valueset(my_table)

  if (!verbose) vars <- vars %>% dplyr::select(-longDescription)

  df %>%
    dplyr::mutate(Row = dplyr::row_number()) %>%
    tidyr::gather(varName, Codevalue, -UNITID, -Row) %>%
    dplyr::mutate(Codevalue = as.character(Codevalue)) %>%
    dplyr::left_join(vars, by = "varName") %>%
    dplyr::left_join(valueset, by = c("varName", "Codevalue")) %>%
    tidyr::replace_na(list(valueLabel = "Count")) %>%
    return()
}

#' Get IPEDS variable names
#' @description Given a table name
#' look up the variables and their friendly labels.,
#' e.g. STABBR is state abbreviation.
#' @param my_table The IPEDS table being accessed
#' @export
get_variables <- function(my_table){
  idbc <- ensure_connection()
  
  # find the year. Depends on a four-digit year
  yr <- stringr::str_extract(my_table, "\\d\\d\\d\\d") %>% stringr::str_sub(3,4)
  fname <- paste0("vartable", yr)

  # get the index for the table
  dplyr::tbl(idbc, fname ) %>%
    dplyr::filter(TableName == my_table) %>%
    dplyr::select(varName, varTitle, longDescription) %>%
    dplyr::collect() %>%
    return()
}

#' Get valueset
#' @description Given a table name
#' look up the variables, codes, and labels that go with codes
#' (e.g. STABBR has a code "SC" for "South Carolina")
#' @param my_table The IPEDS table being accessed
#' @export
get_valueset <- function(my_table){
  idbc <- ensure_connection()
  
  # find the year. Depends on a four-digit year
  yr <- stringr::str_extract(my_table, "\\d\\d\\d\\d") %>% stringr::str_sub(3,4)
  fname <- paste0("valuesets", yr)

  # get the index for the table
  dplyr::tbl(idbc, fname ) %>%
    dplyr::filter(TableName == my_table) %>%
    dplyr::select(varName, Codevalue,valueLabel) %>%
    dplyr::collect() %>%
    return()
}

#' Retrieve IPEDS data with columns renamed
#' @description get a whole table with the columns named for their descriptions,
#' and any code values replaced with the text version.
#' @param table_name The complete name of the table including year
#' @param year2 A two-character year, as in 20XX, so 2020 is "20" and 2021 is "21"
#' @param UNITIDs an optional list of IDs, or NULL for everything
#' @details The year2 input is used to find the var and value tables needed
#'          to upack the codes into text
#' @return A dataframe with human-readable data.
#' @export
get_ipeds_table <- function(table_name, year2, UNITIDs = NULL){
  idbc <- ensure_connection()

  table_name <- toupper(table_name)
  values_tname <- stringr::str_c("valuesets", year2)
  vars_tname <- stringr::str_c("vartable", year2)

  my_data   <- dplyr::tbl(idbc, table_name) %>%
               dplyr::select(-dplyr::starts_with("IALIAS"),
                      -dplyr::starts_with("DUNS")) # these are Blobs that cause index failure

  if(!is.null(UNITIDs)) {
    my_data <- my_data %>%
      dplyr::filter(UNITID %in% !!UNITIDs)
  }

  my_data <- my_data %>%
    dplyr::collect()

  # get any variables that need to be interpolated from numbers to characters,
  # e.g. 1 = public, 2 = private
  my_values <- dplyr::tbl(idbc,values_tname) %>%
    dplyr::filter(TableName == !!table_name) %>%
    dplyr::select(varName, Codevalue, valueLabel) %>%
    dplyr::collect()

  # replace codes with text strings where this applies
  cols_to_do <- my_values %>%
    dplyr::select(varName) %>%
    dplyr::distinct() %>%
    dplyr::pull() # converts from a dataframe to an array

  for(vname in cols_to_do){
    lookups <- my_values %>%
      dplyr::filter(varName == !!vname)

    my_data[[vname]] <- lookups$valueLabel[match(my_data[[vname]], lookups$Codevalue )]
  }

  # the column names are meaningless, so let's change those to something better
  # using the IPEDS column name index here:
  my_cols <- dplyr::tbl(idbc,vars_tname) %>%
      dplyr::select(varName, varTitle, TableName, longDescription) %>%
      dplyr::filter(TableName == !!table_name) %>%
      dplyr::collect() %>%
      dplyr::select(-TableName)

  # match up the column names in ret_data to the descriptions and swap them
  # 1. get the column names as they are now
  old_cols <- names(my_data)

  # 2. try to match the old col names to the list we have
  new_cols   <- my_cols$varTitle[match(old_cols, my_cols$varName)]
  new_labels <- my_cols$longDescription[match(old_cols, my_cols$varName)]
  new_labels[is.na(new_labels)] <- ""

  # 3. if there are missing values, use the original version
  new_cols[is.na(new_cols)] <- old_cols[is.na(new_cols)]
  new_labels[is.na(new_cols)] <- ""

  # 4. Check for duplicates in the new cols and rename if needed
  dupe_status <- duplicated(new_cols)
  dupe_num    <- sum(dupe_status)
  dupe_cols   <- which(dupe_status) # col number for dupe status == TRUE

  if(dupe_num > 0){
    new_cols[dupe_cols] <- paste(new_cols[dupe_cols], 1:dupe_num)
    new_labels[dupe_cols] <- paste(new_labels[dupe_cols], 1:dupe_num)
  }

  # 5. replace the old column names
  # cf https://stackoverflow.com/questions/51261791/changing-attributes-of-multiple-variables-in-data-frame
  replace_labels <- function(my_data, new_labels){
    col_names <- colnames(my_data)
    purrr::map2(col_names, new_labels, ~ (my_data[[.x]] <-`attr<-`(my_data[[.x]], "label", .y)))
  }

  names(my_data) <- new_cols

  # add the long descriptions as labels
  my_data[] <- my_data %>%
    replace_labels(new_labels)

  return(my_data)
}

#' Find UNITID from name
#' @description Use a school's name to attempt a unique ID match
#' @param institution_names a character vector of distinct institutional names.
#' @param states An optional character vector of states, which must be the same length
#' as the names. States will help names be more specific. Blanks will be ignored.
#' @return A dataframe with the names and UNITIDs where matches were found. Incomplete cases
#' are dropped.
#' @details Uses the most recent IPEDS files.
#' @export
find_unitids <- function(institution_names, states = NULL){
  idbc <- ensure_connection()

  #tname <- odbc::dbListTables(idbc, table_name = "hd%") %>% max() # latest one
  tname <- my_dbListTables(search_string = "^HD\\d{4}$") %>% max()

  chars <- dplyr::tbl(idbc, tname) %>%
    dplyr::select(UNITID, Name = INSTNM, State = STABBR) %>%
    dplyr::collect()

  # first try exact matches
  if (is.null(states)) {
    states <- rep("", length(institution_names))
  }
  
  df <- data.frame(Name = institution_names, State = states)

  match_all <- chars %>%
    dplyr::inner_join(df, by = c("Name", "State"))

  # match on name
  match_name <- df %>%
    dplyr::anti_join(match_all, by = "Name") %>%
    dplyr::select(Name) %>%
    dplyr::inner_join(chars, by = "Name") %>%
    # remove names with more than one state
    dplyr::group_by(Name) %>%
    dplyr::mutate(N = dplyr::n()) %>%
    dplyr::ungroup() %>%
    dplyr::filter(N == 1) %>%
    dplyr::select(-N)

  rbind(match_all, match_name) %>% return()
}
