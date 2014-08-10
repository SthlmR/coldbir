#' Escape characters
#' 
#' Use this to escape character strings.
#' Many thanks to Duncan Murdoch (http://goo.gl/1G1php)!
#' 
#' @param x character string
escape_char <- function(x) {
	regexp <- "\\t|\\n|\\a|\\f|\\r"
	if (any(grepl(regexp, x))) {
		x <- gsub(regexp, " ", x)
		wrn(27)
	}
	return(x)
}

#' Get function arguments
#' 
#' Especially useful in the doc class, where the provided
#' arguments are anything or a list (with anything).
#' 
#' @param ... documentation (provided as a list or as parameters)
get_args <- function(...) {
  args <- list(...)
  
  if (length(args) == 1 && is.list(args[[1]]) && is.null(names(args))) {
    return(args[[1]])
  } else {
    return(args)
  }
}

#' Create new time stamp
#' 
#' Creates a time stamp of the current system time.
new_time_stamp <- function(){
  return(as.double(lubridate::force_tz(Sys.time(), .tzone)))
}


#' Create recursive list from vector
#' 
#' A helper function to convert variable file names to a list representation
#' 
#' @param x character vector
#' @param val endpoint value
#' 
#' @examples \dontrun{
#' x <- c("a", "b", "c")
#' recursive_list(x)
#' }
recursive_list <- function(x, val) {
  r <- list()
  r[[as.character(x[1])]] <- if (length(x[-1]) != 0) recursive_list(x[-1], val) else val
  return(r)
}

#' Sorted modify list
#' 
#' Almost the same as utils::modifyList,
#' but also sorts the resulting list
#' 
#' @param x list
#' @param val list
#' 
#' @examples \dontrun{
#' x <- list(a = list(b = list(c = 1, e = 1), g = 1, h = 1))
#' y <- list(a = list(b = list(c = NULL, d = 1), f = 1, g = NULL))
#' sorted_modify_list(x, y)
#' }
sorted_modify_list <- function (x, val) {
  stopifnot(is.list(x), is.list(val))
  for (v in names(val)) {
    x[[v]] <- if (v %in% names(x) && is.list(x[[v]]) && is.list(val[[v]])) {
      sorted_modify_list(x[[v]], val[[v]])
    } else val[[v]]
  }
  
  # mixedorder works a bit strange if length == 1
  if (length(names(x)) > 1) {
    x <- x[gtools::mixedorder(names(x))]
  }
  
  return(x)
}

#' Clear empty branches
#' 
#' Clear all empty branches in a nested list
#' 
#' @param x list
clear_branch <- function (x) {
  for (i in names(x)) {
    if (sum(unlist(x[[i]])) == 0) {
      x[[i]] <- NULL
    } else {
      x[[i]] <- if (is.list(x[[i]])) clear_branch(x[[i]]) else x[[i]]
    }
  }
  return(x)
}

#' Match two lists
#' 
#' See what part of a list that is also included in another one.
#' Returns the inner join of both lists.
#' 
#' @param x data list, including all database variables
#' @param val matching list, could also include wild cards (._)
list_match <- function (x, val) {
  for (v in names(val)) {
    
    if (v %in% .all) {
      val <- x
      
    # If the name doesn't exist in the other list => 0
    } else if (v %in% names(x)) {
      
      # If any of the recursive sums are 0 => 0
      if (sum(unlist(x[[v]])) == 0 || sum(unlist(val[[v]])) == 0) {
        val[[v]] <- list(. = 0)
        
      # If both are lists run function recursivly
      } else if (is.list(x[[v]]) && is.list(val[[v]])) {
        val[[v]] <- list_match(x[[v]], val[[v]])
      } else if (x[[v]] != 1 && val[[v]] != 1) {
        val[[v]] <- list(. = 0)
      }
      
    # If wildcard is used add all x's values
    } else if (is.na(v)) {
      
      sapply(names(x), function(i) {
        val[[i]] <<- list_match(x[[i]], val$`NA`)
      })
      val$`NA` <- NULL 
    } else val[[v]] <- list(. = 0)
  }
  
  if (length(names(val)) > 1) {
    val <- val[gtools::mixedorder(names(val))]
  }
  
  val <- Coldbir:::clear_branch(val)
  if (length(val) == 0) val <- NULL
  
  return(val)
}

#' Subset nested list
#' 
#' Use a character vector to subset a named nested list
#' 
#' @param x list
#' @param sel character vector (representing the nested names to subset on)
subset_list <- function(x, sel) {
  if (length(sel) > 1) subset_list(x[[sel[1]]], sel[-1]) else x[[sel]]
}

create_colname <- function(name, dims) {
  sep <- if (length(dims) > 0) .col_sep$text else ""
  paste(name, paste(dims, collapse = .col_sep$text), sep = sep)
}

list_to_query_repr <- function(x) {
  
  # Because of `unlist` we cannot use other than "." as column seperator
  x <- names(cdb_unlist(x))
  
  x <- lapply(x, function(p) {
    p <- strsplit(p, .col_sep$regexp)[[1]]
    p <- p[nchar(p) > 0]
    dims <- if (length(p[-1]) != 0) p[-1] else NULL
    list(name = p[1], dims = dims)
  })
  return(x)
}

cdb_unlist <- function(L, nStr = "", del = .col_sep$text) {
  if (is.null(L)) {
    return(NULL)
  } else if (!is.list(L)) {
    x <- 1; names(x) <- nStr
    return(x)
  }
  
  res <- integer(0) 
  actNstr <- names(L)
  
  for(i in 1:length(L)) {
    if (nStr!="" ) actNstr[i] <- ifelse(actNstr[i] == ".", nStr, paste(nStr, actNstr[i], sep = del))
    res <- c(res, cdb_unlist(L = L[[i]], nStr = actNstr[i]))
  }
  
  return(res)
}
