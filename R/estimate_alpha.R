#' Functions to produce visual estimate of alpha


#' Simulate data from a lineup evaluation experiment using the Dirichlet-Multinomial model
#' 
#' @param alpha The Dirichlet parameter which is related to the number of interesting panels
#' @param m The number of null panels in the lineup
#' @param K The total number of null panel selections (or, in a Rorschach lineup, the total number of evaluations)
#' @param N Number of lineups to simulate
#' @importFrom gtools rdirichlet
#' @importFrom stats rmultinom
sim_lineup_model <- function(alpha, m = 19, K = 22, N = 50) {
  theta <- gtools::rdirichlet(1, rep(alpha, m))
  sels <- stats::rmultinom(N, size = K, prob = theta)
  sels
}

#' Compute the expected number of c-interesting panels for a lineup experiment
#' 
#' @param alpha The Dirichlet parameter which is related to the number of interesting panels
#' @param c The number of selections a panel must have to be interesting (can be non-integer)
#' @param m The number of null panels in the lineup
#' @param K The total number of null panel selections (or, in a Rorschach lineup, the total number of evaluations)
#' @export
expected_number_panels <- function(alpha, c=m/K, m = 20, K=30) {
  x <- ceiling(c):K
  summation <- choose(K, x) * beta(x + alpha, K - x + (m - 1)*alpha)
  
  m/beta(alpha, (m - 1)*alpha)*sum(summation)
}

#' Simulate the number of c-interesting panels for a lineup experiment
#' 
#' @param alphas Numeric vector of alpha values to conduct simulations for
#' @param c The number of selections a panel must have to be interesting (can be non-integer)
#' @param m The number of null panels in the lineup
#' @param K The total number of null panel selections (or, in a Rorschach lineup, the total number of evaluations)
#' @param N_points The number of points to simulate for each value of alpha
#' @param avg_n_sims The number of simulations to average to get a single point value.
#'          Averaging several simulations reduces the visual noise but also decreases 
#'          the separation between possible values for a more continuous appearance.
#' @export
#' @importFrom tidyr unnest
#' @importFrom tibble tibble
#' @importFrom purrr map
#' @importFrom dplyr mutate group_by summarize
#' @examples 
#' sim_interesting_panels()
sim_interesting_panels <- function(alphas = 10^seq(-2, 2, .05), c = m/K, m = 19, K = 30, 
                                   N_points = 10, avg_n_sims = 10) {
  # Each point (of N_points) is an average of avg_n_sims separate lineups
  # First, generate all of the lineups and count the number of interesting panels
  df <- tibble::tibble(
    alpha = alphas,
    plot_sels = purrr::map(.data$alpha, sim_lineup_model, N = N_points*avg_n_sims, K = K),
    interesting_panels = purrr::map(.data$plot_sels,
      ~tibble::tibble(n_interesting = colSums(.x >= c),
                      rep = 1:ncol(.x) - 1))
  ) %>% 
    tidyr::unnest(.data$interesting_panels)
  
  # Then, average the panels together a bit
  df2 <- df %>%
    dplyr::mutate(point_num = (rep - (rep %% avg_n_sims))/N_points) %>%
    dplyr::group_by(.data$alpha, .data$point_num) %>%
    dplyr::summarize(n_interesting = mean(.data$n_interesting))
  
  df2
}

#' Create a plot for visual estimation of alpha
#' 
#' @param c The number of selections a panel must have to be interesting (can be non-integer)
#' @param m The number of null panels in the lineup
#' @param K The total number of null panel selections (or, in a Rorschach lineup, the total number of evaluations)
#' @param alphas Numeric vector of alpha values to conduct simulations for
#' @param ... additional arguments to sim_interesting_panels
#' @export
#' @importFrom dplyr arrange mutate `%>%` count group_by
#' @importFrom purrr map_dbl
#' @importFrom tibble tibble
#' @importFrom tidyr crossing
#' @import ggplot2
#' @examples 
#' alpha_from_data_lineup()
alpha_from_data_lineup <- function(c = m/K, m = 19, K = 30, alphas = 10^seq(-3, 2, .05), ...) {
  n <- z <- NULL
  
  # Get theoretical function
  model_df <- tibble::tibble(alpha = alphas,
                             n_sel_plots = alphas %>% 
                               purrr::map_dbl(expected_number_panels, c = c)
  )
  
  # Get simulated data
  prior_pred_mean <- sim_interesting_panels(c = c, m = m, K = K, alphas = alphas, ...) %>%
    dplyr::arrange(.data$alpha) %>%
    dplyr::mutate(label = sprintf("alpha == %f", .data$alpha) %>%
                    factor(levels = sprintf("alpha == %f", alphas), ordered = T))
  
  # Compute # points from prior_pred_mean
  pts_per_alpha <- prior_pred_mean %>% dplyr::group_by(.data$alpha) %>% dplyr::count() %>% `[[`("n") %>% mean
  
  # minor break points
  mb <- tidyr::crossing(x = c(2.5, 5, 7.5), y = 10^(seq(-4, 5))) %>%
    dplyr::mutate(z = .data$x*.data$y) %>%
    `[`("z") %>%
    unlist() %>%
    as.numeric
  
  bks <- 10^seq(-4, 5, 1)
  
  # Finally, the actual plot
  ggplot() +
    geom_point(aes(x = .data$alpha, y = .data$n_interesting),data = prior_pred_mean, alpha = 1/pts_per_alpha) +
    geom_line(aes(x = .data$alpha, y = .data$n_sel_plots), data = model_df, color = "blue", size = 1) +
    scale_x_log10(name = expression(alpha), breaks = bks,
                  minor_breaks = mb,
                  labels = bks) +
    coord_cartesian(xlim = range(alphas)) +
    scale_y_continuous(name = sprintf("Average number of panels with at least %.2f selection(s)", c), breaks = 1:K)
  
}

#' Numerically estimate alpha using the average number of c-interesting panels
#' 
#' @param Zc Average number of panels with at least c selections
#' @param c The number of selections a panel must have to be interesting (can be non-integer)
#' @param m The number of null panels in the lineup
#' @param K The total number of null panel selections (or, in a Rorschach lineup, the total number of evaluations)
#' @export
#' @importFrom dplyr mutate filter
#' @importFrom stats optim
alpha_from_null_lineup <- function(Zc, c = m/K, m = 20, K = 30) {
  stopifnot(Zc < K, Zc > 0)
  stopifnot(c > 0, m > 1, K > 1)
  
  optfun <- function(alpha, X, c, m, K) {
    if (alpha <= 0) return(Inf)
    
    (X - expected_number_panels(alpha = alpha, c = c, m = m, K = K))^2
  }
  
  # Get good initialization values
  df <- data.frame(alpha = 10^seq(-2, 2, .5)) %>%
    dplyr::mutate(objval = purrr::map_dbl(.data$alpha, optfun, X = Zc, c = c, m = m, K = K)) %>%
    dplyr::filter(.data$objval == min(.data$objval))

  
  res <- optim(list(alpha = df$alpha), optfun, 
               X = Zc, c = c, m = m, K = K, 
               method = "Brent", lower = 1e-4, upper = 100)
  
  names(res) <- c("alpha", "sum_sq_error", "counts", "convergence", "message")
  
  if (res$alpha < 0.01) warning("Warning: alpha estimate is too low to be reliable. Null panel generation method may produce null plots which are too visually distinct.")
  
  res
}