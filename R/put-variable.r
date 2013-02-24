#'
#' Takes a vector (or data frame) and save its content to a file in the correct cdb.gz-format.
#' 
#' @param x A data frame or vector
#' @param name Variable name
#' @param path Directory of where the file are to be created
#' @param dims A numeric or character vector specifying the dimension of the data (e.g. year and month)
#' @param attrib List of vector attributes
#' @param compress Degree of compression in .gz file (size/speed - trade off). Zero compression gives most speed.
#' @param lookup If lookup table should be added. It will be saved as a seperate file in the folder of the variable.
#'
#' @importFrom RJSONIO toJSON
#' @export
#'
put_variable <- function(x, name = NULL, path = getwd(), dims = NULL, attrib = NULL, lookup = TRUE, compress = 5) {
    
    # If x is a data frame it will recursively run put_variable over all columns
    if (is.data.frame(x)) {
        sapply(names(x), function(i) {
            put_variable(x = x[[i]], name = i, path = path, dims = dims, 
                attrib = attrib, lookup = lookup, compress = compress)
        })
        return(TRUE)
    } else {

        # Read object name if name argument is missing
        if (is.null(name)) name <- deparse(substitute(x))

        # Errors and warnings
        if (is.null(x)) stop(name, " - variable is NULL")
        if (all(is.na(x))) warning(name, " - all values are missing")
        
        # Check/set vector type and number of bytes
        ## The following types are currently supported:
            # 1 = integer
            # 2 = double
            # 3 = logical
            # 4 = factor
            # 5 = Date
            # 6 = POSIXct
            # 7 = POSIXlt

        if (is.integer(x)) {
            type <- 1L  # integer
            bytes <- 4L  # H_itemSize, note: NA for integers is already -2147483648 in R
            exponent <- 0L
            
        } else if ("POSIXt" %in% class(x)) {  # OBS: must be checked before is.double
            type <- if ("POSIXct" %in% class(x)) 6L else 7L
            x <- as.double(x)  # convert to double
            bytes <- 8L  # save as double
            exponent <- 0L
            
        } else if (is.double(x)) {
            if ("Date" %in% class(x)) {
                type <- 5L  # Date
                bytes <- 8L  # save as double
                exponent <- 0L
                
            } else {
                type <- 2L  # double
                exponent <- find_exp(x)
                
                if (exponent <= 9L) {
                    x <- round(x * 10^exponent, 0)
                    bytes <- check_repr(x)
                    if (bytes <= 4L) {
                        bytes <- 4L
                    }
                } else {
                    bytes <- 8L
                    exponent <- 0L
                }
            }
            
        } else if (is.logical(x)) {
            type <- 3L  # logical
            bytes <- 1L
            exponent <- 0L
            warning(name, " - logical vector; NA is converted to FALSE")
            
        } else if (is.factor(x) || is.character(x)) {
            if (is.character(x)) {
                x <- as.factor(x)
                warning(name, " - character converted to factor")
            }
            
            if (lookup) {
                values <- levels(x)
                lt <- data.frame(key = 1:length(values), value = values)
                put_lookup(lt, name = name, path = path)
            }
            
            type <- 4L  # factor
            bytes <- 4L
            exponent <- 0L
            
        } else {
            stop(name, " - data type is not supported")
        }
        
        ext <- if (compress > 0) "cdb.gz" else "cdb"
        
        # Construct file path
        cdb <- file_path(name, path, dims, ext, create_dir = TRUE)
        
        # Create file and add file extension
        if (compress > 0) {
            bin_file <- gzfile(cdb, open = "wb", compression = compress)
        } else {
            bin_file <- file(cdb, "wb")
        }
        
        # File header
        db_ver <- as.integer(.database_version)
        
        # Add default attributes
        if (is.null(attrib)) attrib <- list()
        attr_raw <- charToRaw(toJSON(attrib, digits = 50))
        attr_len <- length(attr_raw)
        
        vector_len <- length(x)
        
        # Removes attributes from vector
        if (bytes == 8) {
            x <- as.double(x)
        } else {
            x <- as.integer(x)
        }
        
        # Write binary file
        writeBin(type, bin_file, size = 1)
        writeBin(bytes, bin_file, size = 1)
        writeBin(exponent, bin_file, size = 1)
        writeBin(db_ver, bin_file, size = 4)
        
        writeBin(attr_len, bin_file, size = 8)
        writeBin(attr_raw, bin_file)
        
        writeBin(vector_len, bin_file, size = 8)
        writeBin(x, bin_file, size = bytes)  # write each vector element to bin_file
        
        close(bin_file)
        
        message(name, " - successfully written to disk")
        return(TRUE)

    }
} 
