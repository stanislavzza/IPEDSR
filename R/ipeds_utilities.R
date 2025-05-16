#' Find matching tables
#' @param idbc database connection
#' @param search_string A string to search for in the table names
#' @return A character vector of table names that match the search string
#' @export
my_dbListTables <- function(idbc, search_string){

  tables <- dbListTables(idbc, table_type = "TABLE")
  tables <- tables[str_detect(tables, search_string)]

  return(tables)
}

#' Convert to friendly names
#' @description Given results from an IPEDS table,
#' create a long dataframe with friendly variable names
#' and translated code values.
#' @param idbc database connector to IPEDS db
#' @param my_table The IPEDS table being accessed
#' @param df Data from the table given
#' @param verbose Logical, defaults to FALSE--Include the long descriptions of vars?
#' @export
get_labels <- function(idbc, my_table, df, verbose = FALSE){
  vars     <- get_variables(idbc, my_table)
  valueset <- get_valueset(idbc, my_table)

  if (!verbose) vars <- vars %>% select(-longDescription)

  df %>%
    mutate(Row = row_number()) %>%
    gather(varName, Codevalue, -UNITID, -Row) %>%
    mutate(Codevalue = as.character(Codevalue)) %>%
    left_join(vars) %>%
    left_join(valueset) %>%
    replace_na(list(valueLabel = "Count")) %>%
    return()
}

#' Get IPEDS variable names
#' @description Given a table name
#' look up the variables and their friendly labels.,
#' e.g. STABBR is state abbreviation.
#' @param idbc database connector to IPEDS db
#' @param my_table The IPEDS table being accessed
#' @export
get_variables <- function(idbc, my_table){

  # find the year. Depends on a four-digit year
  yr <- str_extract(my_table, "\\d\\d\\d\\d") %>% str_sub(3,4)
  fname <- paste0("vartable", yr)

  # get the index for the table
  tbl(idbc, fname ) %>%
    filter(TableName == my_table) %>%
    select(varName, varTitle, longDescription) %>%
    collect() %>%
    return()
}

#' Get valueset
#' @description Given a table name
#' look up the variables, codes, and labels that go with codes
#' (e.g. STABBR has a code "SC" for "South Carolina")
#' @param idbc database connector to IPEDS db
#' @param my_table The IPEDS table being accessed
#' @export
get_valueset <- function(idbc, my_table){

  # find the year. Depends on a four-digit year
  yr <- str_extract(my_table, "\\d\\d\\d\\d") %>% str_sub(3,4)
  fname <- paste0("valuesets", yr)

  # get the index for the table
  tbl(idbc, fname ) %>%
    filter(TableName == my_table) %>%
    select(varName, Codevalue,valueLabel) %>%
    collect() %>%
    return()
}

#' Retrieve IPEDS data with columns renamed
#' @description get a whole table with the columns named for their descriptions,
#' and any code values replaced with the text version.
#' @param idbc Database connection
#' @param table_name The complete name of the table including year
#' @param year2 A two-character year, as in 20XX, so 2020 is "20" and 2021 is "21"
#' @param UNITIDs an optional list of IDs, or NULL for everything
#' @details The year2 input is used to find the var and value tables needed
#'          to upack the codes into text
#' @return A dataframe with human-readable data.
#' @export
get_ipeds_table <- function(idbc, table_name, year2, UNITIDs = NULL){

  values_tname <- str_c("valuesets", year2)
  vars_tname <- str_c("vartable", year2)

  my_data   <- tbl(idbc, table_name) %>%
               select(-starts_with("IALIAS"),
                      -starts_with("DUNS")) # these are Blobs that cause index failure

  if(!is.null(UNITIDs)) {
    my_data <- my_data %>%
      filter(UNITID %in% !!UNITIDs)
  }

  my_data <- my_data %>%
    collect()

  # get any variables that need to be interpolated from numbers to characters,
  # e.g. 1 = public, 2 = private
  my_values <- tbl(idbc,values_tname) %>%
    filter(TableName == !!table_name) %>%
    select(varName, Codevalue, valueLabel) %>%
    collect()

  # replace codes with text strings where this applies
  cols_to_do <- my_values %>%
    select(varName) %>%
    distinct() %>%
    pull() # converts from a dataframe to an array

  for(vname in cols_to_do){
    lookups <- my_values %>%
      filter(varName == !!vname)

    my_data[[vname]] <- lookups$valueLabel[match(my_data[[vname]], lookups$Codevalue )]
  }

  # the column names are meaningless, so let's change those to something better
  # using the IPEDS column name index here:
  my_cols <- tbl(idbc,vars_tname) %>%
      select(varName, varTitle, TableName, longDescription) %>%
      filter(TableName == !!table_name) %>%
      collect() %>%
      select(-TableName)

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
#' @param idbc database connector
#' @param institution_names a character vector of distinct institutional names.
#' @param states An optional character vector of states, which must be the same length
#' as the names. States will help names be more specific. Blanks will be ignored.
#' @return A dataframe with the names and UNITIDs where matches were found. Incomplete cases
#' are dropped.
#' @details Uses the most recent IPEDS files.
#' @export
find_unitids <- function(idbc, institution_names, states){

  #tname <- odbc::dbListTables(idbc, table_name = "hd%") %>% max() # latest one
  tname <- my_dbListTables(idbc, search_string = "^HD\\d{4}$") |> max()

  chars <- tbl(idbc, tname) %>%
    select(UNITID, Name = INSTNM, State = STABBR) %>%
    collect()

  # first try exact matches
  df <- data.frame(Name = institution_names, State = states)

  match_all <- chars %>%
    inner_join(df)

  # match on name
  match_name <- df %>%
    anti_join(match_all) %>%
    select(Name) %>%
    inner_join(chars) %>%
    # remove names with more than one state
    group_by(Name) %>%
    mutate(N = n()) %>%
    ungroup() %>%
    filter(N == 1) %>%
    select(-N)

  rbind(match_all, match_name) %>% return()
}
