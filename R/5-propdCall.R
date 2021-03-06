#' Calculate Theta
#'
#' Calculate differential proportionality measure, theta.
#'  Used by \code{\link{propd}} to build the \code{@@results}
#'  slot. A numeric \code{alpha} argument will trigger
#'  the Box-Cox transformation.
#'
#' @inheritParams all
#' @param lrv A numeric vector. A vector of pre-computed
#'  log-ratio variances. Optional parameter.
#' @param only A character string. The name of the theta
#'  type to return if only calculating one theta type.
#'  Used to make \code{updateCutoffs} faster.
#' @param weights A matrix. Pre-computed \code{limma}-based
#'  weights. Optional parameter.
#'
#' @return A data.frame of theta values if \code{only = "all"}.
#'  Otherwise, this function returns a numeric vector.
#'
#' @export
calculateTheta <- function(counts, group, alpha, lrv = NA, only = "all",
                           weighted = FALSE, weights = as.matrix(NA)){

  ct <- as.matrix(counts)
  if(missing(alpha)) alpha <- NA
  if(!is.character(group)) group <- as.character(group)
  if(length(unique(group)) != 2) stop("Please use exactly two unique groups.")
  if(length(group) != nrow(counts)) stop("Too many or too few group labels.")
  if(identical(lrv, NA)){ firstpass <- TRUE
  }else{ firstpass <- FALSE }

  group1 <- group == unique(group)[1]
  group2 <- group == unique(group)[2]
  n1 <- sum(group1)
  n2 <- sum(group2)

  # Calculate weights and lrv modifier
  if(weighted){

    if(is.na(weights[1,1])){
      message("Alert: Calculating limma-based weights.")
      packageCheck("limma")
      design <- matrix(0, nrow = nrow(ct), ncol = 2)
      design[group == unique(group)[1], 1] <- 1
      design[group == unique(group)[2], 2] <- 1
      v <- limma::voom(t(counts), design = design)
      weights <- t(v$weights)
    }

    W <- weights
    p1 <- omega(ct[group1,], W[group1,])
    p2 <- omega(ct[group2,], W[group2,])
    p <- omega(ct, W)

  }else{

    W <- ct
    p1 <- n1 - 1
    p2 <- n2 - 1
    p <- n1 + n2 - 1
  }

  # Calculate weighted and/or alpha-transformed LRVs -- W not used if weighted = FALSE
  if(firstpass) lrv <- lrv(ct, W, weighted, alpha, ct, W)
  lrv1 <- lrv(ct[group1,], W[group1,], weighted, alpha, ct, W)
  lrv2 <- lrv(ct[group2,], W[group2,], weighted, alpha, ct, W)

  # Calculate LRM (using alpha-based LRM if appropriate)
  if(only == "all"){
    lrm1 <- lrm(ct[group1,], W[group1,], weighted, alpha, ct, W)
    lrm2 <- lrm(ct[group2,], W[group2,], weighted, alpha, ct, W)
  }

  # Replace NaN thetas (from VLR = 0 or VLR = NaN) with 1
  lrv0 <- is.na(lrv1) | is.na(lrv2) | is.na(lrv) | (lrv == 0) # aVLR triggers NaN
  replaceNaNs <- any(lrv0)
  if(replaceNaNs){
    if(firstpass) message("Alert: Replacing NaN theta values with 1.")
  }

  # Build all theta types unless only != "all"
  if(only == "all" | only == "theta_d"){

    theta <- (p1 * lrv1 + p2 * lrv2) / (p * lrv)
    if(replaceNaNs) theta[lrv0] <- 1
    if(only == "theta_d") return(theta)
  }

  if(only == "all" | only == "theta_e"){

    theta_e <- 1 - pmax(p1 * lrv1, p2 * lrv2) / (p * lrv)
    if(replaceNaNs) theta_e[lrv0] <- 1
    if(only == "theta_e") return(theta_e)
  }

  if(only == "all" | only == "theta_f"){

    theta_f <- pmax(p1 * lrv1, p2 * lrv2) / (p * lrv)
    if(replaceNaNs) theta_f[lrv0] <- 1
    if(only == "theta_f") return(theta_f)
  }

  labels <- labRcpp(ncol(counts))
  return(
    data.frame(
      "Partner" = labels[[1]],
      "Pair" = labels[[2]],
      "theta" = theta,
      "theta_e" = theta_e,
      "theta_f" = theta_f,
      "lrv" = lrv,
      "lrv1" = lrv1,
      "lrv2" = lrv2,
      "lrm1" = lrm1,
      "lrm2" = lrm2,
      "p1" = p1,
      "p2" = p2,
      "p" = p
    ))
}

#' @rdname propd
#' @section Functions:
#' \code{updateCutoffs:}
#'  Use the \code{propd} object to permute theta across a
#'  number of theta cutoffs. Since the permutations get saved
#'  when the object is created, calling \code{updateCutoffs}
#'  will use the same random seed each time.
#' @export
updateCutoffs.propd <- function(object, cutoff = seq(.05, .95, .3)){

  if(identical(object@permutes, data.frame())) stop("Permutation testing is disabled.")

  # Let NA cutoff skip function
  if(identical(cutoff, NA)) return(object)

  # Set up FDR cutoff table
  FDR <- as.data.frame(matrix(0, nrow = length(cutoff), ncol = 4))
  colnames(FDR) <- c("cutoff", "randcounts", "truecounts", "FDR")
  FDR$cutoff <- cutoff
  p <- ncol(object@permutes)
  lrv <- object@results$lrv

  # Use calculateTheta to permute active theta
  for(k in 1:p){

    numTicks <- progress(k, p, numTicks)

    # Tally k-th thetas that fall below each cutoff
    shuffle <- object@permutes[, k]

    if(object@active == "theta_mod"){

      # Calculate theta_mod with updateF (using i-th permuted object)
      if(is.na(object@Fivar)) stop("Please re-run 'updateF' with 'moderation = TRUE'.")
      propdi <- suppressMessages(
        propd(object@counts[shuffle, ], group = object@group, alpha = object@alpha, p = 0,
              weighted = object@weighted))
      propdi <- suppressMessages(
        updateF(propdi, moderated = TRUE, ivar = object@Fivar))
      pkt <- propdi@results$theta_mod

    }else{

      # Calculate all other thetas directly (using calculateTheta)
      pkt <- suppressMessages(
        calculateTheta(object@counts[shuffle, ], object@group, object@alpha, lrv,
                       only = object@active, weighted = object@weighted))
    }

    # Find number of permuted theta less than cutoff
    for(cut in 1:nrow(FDR)){ # randcounts as cumsum
      FDR[cut, "randcounts"] <- FDR[cut, "randcounts"] + sum(pkt < FDR[cut, "cutoff"])
    }
  }

  # Calculate FDR based on real and permuted tallys
  FDR$randcounts <- FDR$randcounts / p # randcounts as mean
  for(cut in 1:nrow(FDR)){
    FDR[cut, "truecounts"] <- sum(object@results$theta < FDR[cut, "cutoff"])
    FDR[cut, "FDR"] <- FDR[cut, "randcounts"] / FDR[cut, "truecounts"]
  }

  # Initialize @fdr
  object@fdr <- FDR

  return(object)
}

#' @rdname propd
#' @section Functions:
#' \code{updateF:}
#'  Use the \code{propd} object to calculate the F-statistic
#'  from theta as described in the Erb et al. 2017 manuscript
#'  on differential proportionality. Optionally calculates a
#'  moderated F-statistic using the limma-voom method. Supports
#'  weighted and alpha transformed theta values.
#' @export
updateF <- function(propd, moderated = FALSE, ivar = "clr"){

  # Check that active theta is theta_d? propd@active
  if(!propd@active == "theta_d"){
    stop("Make theta_d the active theta.")
  }

  group1 <- propd@group == unique(propd@group)[1]
  group2 <- propd@group == unique(propd@group)[2]
  n1 <- sum(group1)
  n2 <- sum(group2)

  if(moderated){

    # A reference is needed for moderation
    propd@counts # Zeros replaced unless alpha provided...
    use <- ivar2index(propd@counts, ivar)

    # Establish data with regard to a reference Z
    if(any(propd@counts == 0)){
      message("Alert: Building reference set with ivar and counts offset by 1.")
      X <- as.matrix(propd@counts + 1)
    }else{
      message("Alert: Building reference set with ivar and counts.")
      X <- as.matrix(propd@counts)
    }

    logX <- log(X)
    z.set <- logX[, use, drop = FALSE]
    z.geo <- rowMeans(z.set)
    if(any(exp(z.geo) == 0)) stop("Zeros present in reference set.")
    z.lr <- as.matrix(sweep(logX, 1, z.geo, "-"))
    z <- exp(z.geo)

    # Fit limma-voom to reference-based data
    message("Alert: Calculating weights with regard to reference.")
    packageCheck("limma")
    z.sr <- t(exp(z.lr) * mean(z)) # scale counts by mean of reference
    design <- matrix(0, nrow = nrow(propd@counts), ncol = 2)
    design[propd@group == unique(propd@group)[1], 1] <- 1
    design[propd@group == unique(propd@group)[2], 2] <- 1
    v <- limma::voom(z.sr, design = design)
    param <- limma::lmFit(v, design)
    param <- limma::eBayes(param)
    z.df <- param$df.prior
    propd@dfz <- param$df.prior
    z.s2 <- param$s2.prior

    # Calculate simple moderation term based only on LRV
    mod <- z.df * z.s2 / propd@results$lrv

    # Moderate F-statistic
    propd@Fivar <- ivar # used by updateCutoffs
    Fprime <- (1 - propd@results$theta) * (n1 + n2 + z.df) /
      ((n1 + n2) * propd@results$theta + mod)
    Fstat <- (n1 + n2 + z.df - 2) * Fprime
    theta_mod <- 1 / (1 + Fprime)

  }else{

    propd@Fivar <- NA # used by updateCutoffs
    Fstat <- (n1 + n2 - 2) * (1 - propd@results$theta) / propd@results$theta
    theta_mod <- 0
  }

  propd@results$theta_mod <- theta_mod
  propd@results$Fstat <- Fstat

  # Calculate unadjusted p-value (d1 = K - 1; d2 = N - K)
  K <- length(unique(propd@group))
  N <- n1 + n2 + propd@dfz
  propd@results$Pval <- pf(Fstat, K - 1, N - K, lower.tail = FALSE)

  return(propd)
}

#' Calculate a theta Cutoff
#'
#' This function uses the F distribution to calculate a cutoff of
#'  theta for a p-value given by the \code{pval} argument.
#'
#' @inheritParams all
#' @param pval A p-value at which to calculate a theta cutoff.
#'
#' @return A cutoff of theta from [0, 1].
#'
#' @export
qtheta <- function(propd, moderated = FALSE, pval = 0.05){

  if(pval < 0 | pval > 1) stop("Provide a p-value cutoff from [0, 1].")

  K <- length(unique(propd@group))
  N <- length(propd@group)

  if(moderated){

    propd <- suppressMessages(updateF(propd, moderated = TRUE))
    z.df <- propd@dfz

    Q <- qf(pval, K - 1, N + z.df - K, lower.tail = FALSE)
    # # Fstat <- (n1 + n2 + z.df - 2) * Fprime
    # # theta_mod <- 1 / (1 + Fprime)
    # # Q = Fstat
    # # Q = (n1 + n2 + z.df - 2) * Fprime
    # # Fprime = 1/theta_mod - 1
    R <- N - 2 + z.df
    # # Q = R * (1/theta_mod - 1)
    # # Q = R/theta_mod - R
    theta_a05 <- R/(Q+R)

  }else{

    Q <- qf(pval, K - 1, N - K, lower.tail = FALSE)
    # # Fstat <- (N - 2) * (1 - propd@theta$theta) / propd@theta$theta
    # # Q = Fstat
    # # Q = (N-2) * (1-theta) / theta
    # # Q / (N-2) = (1/theta) - 1
    # # 1/theta = Q / (N-2) + 1 = Q(N-2)/(N-2)
    # # theta = (N-2)/(Q+(N-2))
    theta_a05 <- (N-2)/(Q+(N-2))
  }

  return(theta_a05)
}
