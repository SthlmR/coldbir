# devtools::test(".")

path <- tempfile()
size <- 1e3

context("init database")
    db <- cdb(path)
    test_that("init cdb", {
        expect_equal(path, get_path(db))
    })

context("variable (integer)")
    x <- sample(c(0, 1, 10000, .Machine$integer.max, NA), size, replace = TRUE)
    db["integer"] <- x
    test_that("get variable", {
        expect_error(db["non-existing"])
        expect_equal(x, db["integer"])
    })

context("variable (double)")
    x <- sample(c(-100, -50, 0, 50, 100, NA), size, replace = TRUE)
    db["double"] <- x
    test_that("get variable", {
        expect_equal(x, db["double"])
    })

context("variable (POSIXct)")
    x <- .POSIXct(runif(size) * unclass(Sys.time()))
    db["POSIXct"] <- x
    test_that("get variable", {
        expect_equal(as.character(x), as.character(db["POSIXct"]))
    })

# Remove all temporary test files
system(sprintf("rm -r %s", path))
