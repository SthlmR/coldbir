path <- tempfile()
size <- 1e3
db <- cdb(path, log_level = 1)

context("INITIALIZE DATABASE")
##############################
test_that("init cdb", {
    expect_equal(path, db$path)
})

context("VARIABLE TYPES")
#########################
x <- sample(c(0, 1, 10000, .Machine$integer.max, NA), size, replace = TRUE)
db["integer"] <- x
test_that("integer", {
    expect_error(db["non-existing"])
    expect_equal(x, db["integer"])
})

x <- sample(c(-100, -50, 0, 50, 100, NA), size, replace = TRUE)
db["double"] <- x
test_that("double", {
    expect_equal(x, db["double"])
})

x <- .POSIXct(runif(size) * unclass(Sys.time()))
db["POSIXct"] <- x
test_that("POSIXct", {
    expect_equal(as.character(x), as.character(db["POSIXct"]))
})

context("VARIABLE DOCUMENTATION")
#################################
x <- list(a = "text", b = list(c = 1, d = 2), c = "åäö")
db["x"] <- doc(x)
test_that("get documentation", {
    expect_error(db["non-existing"])
    expect_equal(list(x), db$get_doc("x"))
})

context("VARIABLE DIMENSIONS")
##############################
x <- sample(1:5, size, replace = T)
dims <- c(2012, "test")
db["x", dims] <- x
test_that("put/get variable with dimensions", {
  expect_error(db["non-existing", dims])
  expect_equal(x, db["x", dims])
  expect_true(file.exists(file.path(db$path, "x", "data", "d[2012][test].cdb.gz")))
})

x <- sample(1:5, size, replace = T)
dims <- NULL
db["x", dims] <- x

test_that("put/get variable with dims = NULL", {
  expect_error(db["non-existing", dims])
  expect_equal(x, db["x", dims])
  expect_true(file.exists(file.path(db$path, "x", "data", "d.cdb.gz")))
})

context("DATASETS")
###################
x <- data.table(MASS::survey)

# In addition we change the column names
# to specifically test issue 49.
setnames(x, c("Wr.Hnd", "NW.Hnd", "Pulse"), c("var", "x", "z"))

db[, "survey"] <- x

# Order columns by name since the folders in the database
setcolorder(x, sort(names(x)))

test_that("get dataset", {
  expect_equal(x, db[, "survey"])
})

# CLEAN UP
system(sprintf("rm -r %s", path))
