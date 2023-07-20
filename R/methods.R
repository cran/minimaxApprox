# Print method (hide i and basis/x but leave in list and not in attribute)
print.minimaxApprox <- function(x, round = 6L, ...) {
  if (attr(x, "type") == "Polynomial") {
    coefficients <- list(a = x$a)
  } else {
    coefficients <- list(a = x$a, b = x$b)
  }

  round <- as.integer(round)
  diagnostics <- list(x$EE,
                      x$OE,
                      Ratio = round(x$OE / x$EE, round),
                      Difference = abs(x$OE - x$EE),
                      Warnings = x$Warning)

  names(diagnostics)[1:2] <- if (attr(x, "relErr")) {
    c("ExpectedRelError", "ObservedRelError")
  } else {
    c("ExpectedAbsError", "ObservedAbsError")
  }

  print(c(coefficients, diagnostics))
}

coef.minimaxApprox <- function(object, ...) {
  if (attr(object, "type") == "Polynomial") {
    coef <- list(a = object$a)
  } else {
    coef <- list(a = object$a, b = object$b)
  }

  coef
}

# Plot method for errors and basis points
plot.minimaxApprox <- function(x, y = NULL, ...) {
  if (!is.null(y)) {
    message("The y values are taken from the minimaxApprox object. ",
            "Passed y values are ignored.")
  }
  args <- list(...)
  rng <- attr(x, "range")
  fn <- attr(x, "func")
  relErr <- attr(x, "relErr")
  z <- seq(rng[1], rng[2], length.out = 1001L)
  zz <- remErr(z, x, fn, relErr)
  y <- remErr(x$x, x, fn, relErr)

  # Default y-axis label
  ylab <- if (relErr) "Relative Error" else "Absolute Error"

  # Default y-axis limits
  ybnd <- max(x$EE, x$OE)
  if ("ylim" %in% names(args)) {
    ylim <- args$ylim
  } else {
    ylim <- c(-ybnd, ybnd)
  }

  plot(z, zz, type = "l", xlab = "x", ylab = ylab, ...)
  abline(h = 0)
  points(x$x, y, col = "red", pch = 16L)
  abline(h = c(-x$OE, x$OE), lty = 2L, col = "blue")
  abline(h = c(-x$EE, x$EE), lty = 3L, col = "red")
  legend(x = "bottomleft", inset = c(0.35, 1), col = c("red", "red", "blue"),
         lty = c(NA, 3L, 2L), legend = c("Basis", "Exp Err", "Obs Err"),
         pch = c(16L, NA, NA), bg = "transparent", xpd = TRUE)
}