#' Read vector from disk
#'
#' Reads a numeric vector from disk
#'
#' @param name Variable name
#' @param path Directory of where the variable is located
#' @param dims A numeric or character vector specifying the dimension of the data (e.g. year and month)
#' @param na Specification of how missing values should be coded
#' 
#' @importFrom RJSONIO fromJSON
#' @export
#'
get_variable <- function(name, path = getwd(), dims = NULL, na = NA) {

    # Get file path
    cdb <- file_path(name, path, dims, ext = c("cdb.gz", "cdb"), create_dir = FALSE)
    
    # Connect to compressed/uncompressed file
    if (file.exists(cdb[1])) {
        bin_file <- gzfile(cdb[1], "rb")
        
    } else if (file.exists(cdb[2])) {
        bin_file <- file(cdb[2], "rb")
        
    } else {
        stop(name, " - file does not exist")
    }
    
    type <- readBin(bin_file, integer(), n = 1, size = 1, signed = FALSE)
    bytes <- readBin(bin_file, integer(), n = 1, size = 1, signed = FALSE)
    exponent <- readBin(bin_file, integer(), n = 1, size = 1, signed = FALSE)
    db_ver <- readBin(bin_file, integer(), n = 1, size = 4)
    
    attr_len <- readBin(bin_file, integer(), n = 1, size = 8)
    attr_str <- rawToChar(readBin(bin_file, raw(), n = attr_len))
    
    vector_len <- readBin(bin_file, integer(), n = 1, size = 8)
    
    if (bytes <= 4) {
        x <- readBin(bin_file, integer(), n = vector_len, size = bytes)
    } else {
        x <- readBin(bin_file, double(), n = vector_len)
    }
    
    close(bin_file)
    
    # Check if using an old version of colbir
    if (db_ver != as.integer(.database_version))
        stop(name, " - version of coldbir package and file format does not match")

    # Prepare data depending on vector type
    
    ## integer or factor
    if (type %in% c(1, 4)) {
        if (!is.na(na)) 
            x[is.na(x)] <- as.integer(na)
    
    ## double
    } else if (type == 2) {
        if (exponent > 0) 
            x <- x/10^exponent
        if (!is.na(na))
            x[is.na(x)] <- as.double(na)
        
    ## logical
    } else if (type == 3) {
        x <- (x > 0L)
        if (!is.na(na)) 
            x[is.na(x)] <- as.logical(na)
        
    ## Date
    } else if (type == 5) {
        x <- as.Date(x, origin = "1970-01-01")
        
    ## POSIXct
    } else if (type == 6) {
        x <- as.POSIXct(x, origin = "1970-01-01")
        
    ## POSIXlt
    } else if (type == 7) {
        x <- as.POSIXlt(x, origin = "1970-01-01")
    }
    
    # Add attributes to vector
    if (attr_str != "") attributes(x) <- c(attributes(x), as.list(fromJSON(attr_str)))
    
    return(x)
} 
