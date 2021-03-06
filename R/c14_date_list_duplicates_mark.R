#### mark_duplicates ####

#' @name duplicates
#' @title Mark and remove duplicates in a \strong{c14_date_list}
#'
#' @description Duplicates are found in \code{c14bazAAR::mark_duplicates()}
#' by comparison of \strong{labnr}s.
#' Only dates with exactly equal \strong{labnr}s are considered duplicates.
#' Duplicate groups are numbered (from 0) and these numbers linked to
#' the individual dates in the new column \strong{duplicate_group}.
#' While \code{c14bazAAR::mark_duplicates()} only finds duplicates,
#' \code{c14bazAAR::remove_duplicates()} removes them with three different strategies
#' according to the value of the arguments \code{preferences} and \code{supermerge}:
#' \enumerate{
#'   \item Option 1: By merging all dates in a \strong{duplicate_group}. All non-equal variables
#'   in the duplicate group are turned to \code{NA}. This is the default option.
#'   \item Option 2: By selecting individual database entries in a \strong{duplicate_group}
#'   according to a trust hierarchy as defined by the parameter \code{preferences}.
#'   In case of duplicates within one database the first occurrence in the table (top down)
#'   is selected. All databases not mentioned in \code{preferences} are dropped.
#'   \item Option 3: Like option 2, but in this case the different datasets in a
#'   \strong{duplicate_group} are merged column by column to
#'   create a superdataset with a maximum of information. The column \strong{sourcedb} is
#'   dropped in this case to indicate that multiple databases have been merged. Data
#'   citation is a lot more difficult with this option. It can be activated with \code{supermerge}.
#' }
#' The option \code{log} allows to add a new column \strong{duplicate_remove_log}
#' that documents the variety of values provided by all databases for this
#' duplicated date.
#' \code{c14bazAAR::remove_duplicates()} needs the column \strong{duplicate_group}
#' and calls \code{c14bazAAR::mark_duplicates()} if it is missing.
#'
#' @param x an object of class c14_date_list
#' @param preferences character vector with the order of source databases by
#' which the deduping should be executed. If e.g. preferences = c("radon", "calpal")
#' and a certain date appears in radon and euroevol, then only the radon entry remains.
#' Default: NULL. With preferences = NULL all overlapping, conflicting information in
#' individual columns of one duplicated date is removed. See Option 2 and 3.
#' @param supermerge boolean. Should the duplicated datasets be merged on the column level?
#' Default: FALSE. See Option 3.
#' @param log logical. If log = TRUE, an additional column is added that contains a string
#' documentation of all variants of the information for one date from all conflicting
#' databases. Default = TRUE.
#'
#' @return an object of class c14_date_list with the additional
#' columns \strong{duplicate_group} or \strong{duplicate_remove_log}
#'
#' @rdname duplicates
#'
#' @examples
#' library(magrittr)
#'
#' test_data <- tibble::tribble(
#'   ~sourcedb, ~labnr,  ~c14age, ~c14std,
#'  "A",       "lab-1", 1100,    10,
#'  "A",       "lab-1", 2100,    20,
#'  "B",       "lab-1", 3100,    30,
#'  "A",       "lab-2", NA,      10,
#'  "B",       "lab-2", 2200,    20,
#'  "C",       "lab-3", 1300,    10
#' ) %>% as.c14_date_list()
#'
#' # mark duplicates
#' test_data %>% mark_duplicates()
#'
#' # remove duplicates with option 1:
#' test_data %>% remove_duplicates()
#'
#' # remove duplicates with option 2:
#' test_data %>% remove_duplicates(
#'   preferences = c("A", "B")
#' )
#'
#' # remove duplicates with option 3:
#' test_data %>% remove_duplicates(
#'   preferences = c("A", "B"),
#'   supermerge = TRUE
#' )
#'
#' @export
mark_duplicates <- function(x) {
  UseMethod("mark_duplicates")
}

#' @rdname duplicates
#' @export
mark_duplicates.default <- function(x) {
  stop("x is not an object of class c14_date_list")
}

#' @rdname duplicates
#' @export
mark_duplicates.c14_date_list <- function(x) {

  x %>% check_if_columns_are_present("labnr")

  message(paste0("Marking duplicates... ", {if (nrow(x) > 10000) {"This may take several minutes."}}))

  message("-> Search for accordances in Lab Codes...")
  partners <- x[["labnr"]] %>% generate_list_of_equality_partners()

  message("-> Writing duplicate groups...")
  x %<>% add_equality_group_number(partners)

  x %>%
    as.c14_date_list() %>%
    return()
}

#### helper functions ####

#' generate_list_of_equality_partners
#'
#' @param x vector
#'
#' @return list of unique partners
#'
#' @keywords internal
#' @noRd
generate_list_of_equality_partners <- function(x) {
  x %>% pbapply::pblapply(
    function(y){
      if(!is.na(y)){
        # core algorithm: search for dates which contain the
        # labnr string of another one
        # grep(y, x[["labnr"]], fixed = T, useBytes = T)
        # better: check for exact equality
        which(y == x)
      } else {
        NA
      }
    }
  ) %>%
    magrittr::extract(sapply(., function(x) {length(x)}) > 1) %>%
    unique() %>%
    return()
}

#' add_equality_group_number
#'
#' @param x c14_date_list
#' @param partner_list partner list produced by generate_list_of_equality_partners()
#'
#' @return c14_date_list with additional column duplicate_group
#'
#' @keywords internal
#' @noRd
add_equality_group_number <- function(x, partner_list) {
  x$duplicate_group <- NA

  if(length(partner_list) > 0) {
    amount_duplicate_groups <- length(partner_list)
    pb <- utils::txtProgressBar(
      min = 0, max = amount_duplicate_groups,
      style = 3,
      width = 50,
      char = "+"
    )
    group_counter = 0
    for (p1 in 1:amount_duplicate_groups) {
      x$duplicate_group[partner_list[[p1]]] <- group_counter
      group_counter <- group_counter + 1
      utils::setTxtProgressBar(pb, p1)
    }
    close(pb)
  }

  return(x)
}
