% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/8-get.R
\name{getResults}
\alias{getResults}
\title{Get Results from Object}
\usage{
getResults(object, cutoff = NA)
}
\arguments{
\item{object}{A \code{propr} or \code{propd} object.}

\item{cutoff}{This argument indicates the value at which to
cutoff the results. For "rho" and "cor", the function
returns pairs with a value greater than the cutoff.
For "theta", "phi", and "phs", the function returns pairs
with a value less than the cutoff. Leave the argument as
\code{NA} to return all results.}
}
\value{
A \code{data.frame} of results.
}
\description{
This function provides a unified wrapper to retrieve results
 from a \code{propr} or \code{propd} object.
}
