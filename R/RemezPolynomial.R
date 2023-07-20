# Copyright Avraham Adler (c) 2023
# SPDX-License-Identifier: MPL-2.0+

# Function to create augmented Vandermonde matrix for polynomial approximation
polyMat <- function(x, y, relErr) {
  n <- length(x)
  A <- vanderMat(x, n - 2L)
  altSgn <- (-1) ^ (seq_len(n) - 1L)
  # For relative error, need to weight the E by f(x)
  if (relErr) altSgn <- altSgn * y
  cbind(A, altSgn, deparse.level = 0L)
}

# Function to calculate coefficients given matrix and known values
polyCoeffs <- function(x, fn, relErr) {
  y <- callFun(fn, x)
  PP <- solve(polyMat(x, y, relErr), y)
  list(a = PP[-length(PP)], E = PP[length(PP)])
}

# Main function to calculate and return the minimax polynomial approximation
remPoly <- function(fn, lower, upper, degree, relErr, opts) {

  # Initial x's
  x <- chebNodes(degree + 2L, lower, upper)

  # Initial Polynomial Guess
  PP <- polyCoeffs(x, fn, relErr)
  errs_last <- remErr(x, PP, fn, relErr)
  converged <- FALSE
  unchanged <- FALSE
  unchanging_i <- 0L
  i <- 0L
  repeat {
    # Check for maxiter
    if (i >= opts$maxiter) break
    i <- i + 1L
    r <- findRoots(x, PP, fn, relErr)
    x <- switchX(r, lower, upper, PP, fn, relErr)
    PP <- polyCoeffs(x, fn, relErr)
    errs <- remErr(x, PP, fn, relErr)
    mxae <- max(abs(errs))
    expe <- abs(PP$E)

    if (opts$showProgress) {
      message("i: ", i, " E: ", fC(expe), " maxErr: ", fC(mxae))
    }

    # Check for convergence
    if (isConverged(errs, expe, opts$convrat, opts$tol) &&
        i >= opts$miniter) {
      converged <- TRUE
      break
    }

    # Check that solution is evolving. If solution is not evolving then further
    # iterations will just not help.
    if (all(errs / errs_last <= opts$convrat) ||
        all(abs(errs - errs_last) <= opts$tol)) {
      unchanging_i <- unchanging_i + 1L
      if (unchanging_i >= opts$conviter) {
        unchanged <- TRUE
        break
      }
    }
    errs_last <- errs
  }

  list(a = PP$a, expe = expe, mxae = mxae, i = i, x = x, converged = converged,
       unchanged = unchanged, unchanging_i = unchanging_i)
}