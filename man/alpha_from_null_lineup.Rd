% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/estimate_alpha.R
\name{alpha_from_null_lineup}
\alias{alpha_from_null_lineup}
\title{Numerically estimate alpha using the average number of c-interesting panels}
\usage{
alpha_from_null_lineup(Zc, c = m/K, m = 20, K = 30)
}
\arguments{
\item{Zc}{Average number of panels with at least c selections}

\item{c}{The number of selections a panel must have to be interesting (can be non-integer)}

\item{m}{The number of null panels in the lineup}

\item{K}{The total number of null panel selections (or, in a Rorschach lineup, the total number of evaluations)}
}
\description{
Numerically estimate alpha using the average number of c-interesting panels
}
