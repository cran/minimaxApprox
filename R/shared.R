# Copyright Avraham Adler (c) 2023
# SPDX-License-Identifier: MPL-2.0+

# Printing convenience function.
fC <- function(x, d = 6L, f = "g", w = -1L) {
  formatC(x, digits = d, format = f, width = w)
}

# Default Chebyshev nodes.
chebNodes <- function(n, a, b) {
  n <- as.integer(n)
  sort(0.5 * (a + b + (b - a) * cos((2 * seq_len(n) - 1) * pi / (2 * n))))
}

# Call the function being approximated on the points x.
callFun <- function(fn, x) {
  if (!is.function(fn)) stop("Unable to parse function.")
  do.call(match.fun(fn), args = list(x = x))
}

# Check that the values passed are oscillating in sign
isOscil <- function(x) all(abs(diff(sign(x))) == 2)

evalFunc <- function(x, R, basis) {
  calcFunc <- switch(EXPR = basis, m = polyCalc, chebCalc)
  ret <- calcFunc(x, R$a)
  if ("b" %in% names(R)) {
    ret <- ret / calcFunc(x, R$b)
  }

  ret
}

# Function to calculate error between known and calculated values.
remErr <- function(x, R, fn, relErr, basis) {
  if (relErr) {
    y <- callFun(fn, x)
    (evalFunc(x, R, basis) - y) / y
  } else {
    evalFunc(x, R, basis) - callFun(fn, x)
  }
}

# Function to identify roots of the error equation for use as bounds in finding
# the maxima and minima.
findRoots <- function(x, R, fn, relErr, basis) {
  r <- double(length(x) - 1L)
  for (i in seq_along(r)) {
    intv <- c(x[i], x[i + 1L])
    root <- tryCatch(uniroot(remErr, interval = intv, extendInt = "no", R = R,
                             fn = fn, relErr = relErr, basis = basis,
                             tol = sqrt(.Machine$double.eps)),
                     error = function(cond) simpleError(trimws(cond$message)))

    # If there is no root in the interval, take the endpoint closest to zero.
    if (inherits(root, "simpleError")) {
      r[i] <- intv[which.min(abs(intv))]
    } else {
      r[i] <- root$root
    }
  }

  r
}

# Function to identify new x positions. This algorithm uses the multi-switch
# paradigm, not the single switch.
switchX <- function(r, l, u, R, fn, relErr, basis) {
  bottoms <- c(l, r)
  tops <- c(r, u)
  x <- double(length(bottoms))
  attr(x, "ZeroBasis") <- FALSE
  maximize <- sign(remErr(l, R, fn, relErr, basis)) == 1
  for (i in seq_along(x)) {
    intv <- c(bottoms[i], tops[i])
    # Tighter tolerances than the default lead to issues (AA: 2024-01-31).
    extrma <- tryCatch(optimize(remErr, interval = intv, R = R, fn = fn,
                                relErr = relErr, basis = basis,
                                maximum = maximize),
                       error = function(cond) simpleError(trimws(cond$message)))

    # If no extremum then the take endpoint with "better" value depending if we
    # are maximizing or minimizing.
    if (inherits(extrma, "simpleError")) {
      endPtErr <- remErr(intv, R, fn, relErr, basis)
      if (maximize) {
        x[i] <- intv[which.max(endPtErr)]
      } else {
        x[i] <- intv[which.min(endPtErr)]
      }
    } else {
      x[i] <- extrma[[1L]]
    }

    # Test endpoints for max/min even if an extremum was found.
    p <- c(bottoms[i], x[i], tops[i])
    E <- remErr(p, R, fn, relErr, basis)

    if (maximize) {
      x[i] <- p[which.max(E)]
    } else {
      x[i] <- p[which.min(E)]
    }

    # Test for 0 value at function if relative error
    if (relErr && callFun(fn, x[i]) == 0) {
      attr(x, "ZeroBasis") <- TRUE
      peturb <- 1e-12
      if (x[i] == l) {
        x[i] <- x[i] + peturb
      } else if (x[i] == u) {
        x[i] <- x[i] - peturb
      } else {
        xreplace <- c(x[i] - peturb, x[i] + peturb)
        fnreplace <- callFun(fn, xreplace)
        if (maximize) {
          x[i] <- xreplace[which.max(fnreplace)]
        } else {
          x[i] <- xreplace[which.min(fnreplace)]
        }
      }
    }

    # Flip maximize.
    maximize <- !maximize
  }

  x
}

# Check Remez iterations for convergence.
isConverged <- function(errs, expe, convrat, tol) {
  aerrs <- abs(errs)
  mxae <- max(aerrs)
  mnae <- min(aerrs)
  a_mxa_exp <- abs(mxae - expe)
  mx_mn <- mxae - mnae

  # Check observed errors are close enough to expected by ratio or tolerance.
  errDistance <- mxae / expe <= convrat ||
    (a_mxa_exp <= tol && a_mxa_exp > .Machine$double.eps)

  # Check observed errors are close enough to each other by ratio or tolerance.
  errMagnitude <- mxae / mnae <= convrat ||
    (mx_mn <= tol && mx_mn > .Machine$double.eps)

  # Converged if magnitude and distance are close and error oscillates in sign.
  isOscil(errs) && errDistance && errMagnitude
}

isUnchanging <- function(errs, errs_last, convrat, tol) {
  denomProblem <- which(errs_last == 0)
  # If any are actually 0, then perturb them by 1e-12. Ratio becomes 1 and
  # difference remains 0.
  if (length(denomProblem) > 0L) {
    errs[denomProblem] <- errs[denomProblem] + 1e-12
    errs_last[denomProblem] <- errs_last[denomProblem] + 1e-12
  }
  errsDiff <- abs(errs - errs_last)
  all(abs(errs / errs_last) <= convrat) ||
    (all(errsDiff <= tol) && all(errsDiff > .Machine$double.eps))
}

# Check denominator polynomial for zero in the requested range.
checkDenom <- function(a, l, u, basis) {
  calcFn <- if (basis == "m") polyCalc else chebCalc
  dngrRt <- tryCatch(uniroot(calcFn, c(l, u), extendInt = "no", a = a,
                             tol = .Machine$double.eps),
                     error = function(cond) simpleError(trimws(cond$message)))
  if (inherits(dngrRt, "simpleError")) {
    return(NULL)
  } else {
    return(dngrRt$root)
  }
}

# Check for coefficient irrelevancy.
checkIrrelevant <- function(a, l, u, zt) {
  n <- length(a)
  if (!is.null(zt) && n > 0) {
    xmax <- max(abs(l), abs(u))
    a <- ifelse(abs(a * xmax^(seq_len(n) - 1L)) <= zt, 0, a)
  }

  a
}
