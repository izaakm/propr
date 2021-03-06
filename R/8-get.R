#' Get Results from Object
#'
#' This function provides a unified wrapper to retrieve results
#'  from a \code{propr} or \code{propd} object.
#'
#' @param object A \code{propr} or \code{propd} object.
#' @param cutoff This argument indicates the value at which to
#'  cutoff the results. For "rho" and "cor", the function
#'  returns pairs with a value greater than the cutoff.
#'  For "theta", "phi", and "phs", the function returns pairs
#'  with a value less than the cutoff. Leave the argument as
#'  \code{NA} to return all results.
#'
#' @return A \code{data.frame} of results.
#'
#' @export
getResults <- function(object, cutoff = NA){

  # Unify @results slot subset procedure
  if(!is.na(cutoff)){

    if(class(object) == "propr"){

      if(object@metric == "rho" | object@metric == "cor"){

        outcome <- "propr"
        keep <- object@results[,outcome] >= cutoff

      }else if(object@metric == "phi" | object@metric == "phs"){

        outcome <- "propr"
        keep <- object@results[,outcome] <= cutoff

      }else{

        stop("Provided 'propr' metric not recognized.")
      }

    }else if(class(object) == "propd"){

      outcome <- "theta"
      keep <- object@results[,outcome] <= cutoff

    }else{

      stop("Provided 'object' not recognized.")
    }

    # Apply numeric cutoff
    df <- object@results[keep,]

  }else{

    # Apply NA cutoff
    df <- object@results
  }

  # Name features of the new data.frame
  if(nrow(df) == 0) stop("No results remain after cutoff.")
  names <- colnames(object@counts)
  df$Partner <- names[df$Partner]
  df$Pair <- names[df$Pair]
  return(df)
}

#' Get Network from Object
#'
#' This function provides a unified wrapper to build networks
#'  from \code{propr} and \code{propd} objects.
#'
#' @param object Any \code{propr} or \code{propd} object.
#' @param cutoff A cutoff argument for \code{object}, passed
#'  to \code{\link{getResults}}.
#' @param propr.object,thetad.object,thetae.object A \code{propr}
#'  object or an appropriate \code{propd} object.
#' @param propr.cutoff,thetad.cutoff,thetae.cutoff A cutoff
#'  argument passed to \code{\link{getResults}}.
#' @inheritParams all
#'
#' @return A network object.
#'
#' @export
getNetwork <- function(object, cutoff = NA, propr.object, propr.cutoff = NA,
                       thetad.object, thetad.cutoff = NA,
                       thetae.object, thetae.cutoff = NA,
                       col1, col2, d3 = FALSE){

  if(!missing(object)){
    if(class(object) == "propr"){
      message("Alert: Treating 'object' as the proportionality network.")
      propr.object <- object
      propr.cutoff <- cutoff
    }else if(class(object) == "propd" & object@active == "theta_d"){
      message("Alert: Treating 'object' as the disjointed proportionality network.")
      thetad.object <- object
      thetad.cutoff <- cutoff
    }else if(class(object) == "propd" & object@active == "theta_e"){
      message("Alert: Treating 'object' as the emergent proportionality network.")
      thetae.object <- object
      thetae.cutoff <- cutoff
    }else{
      stop("Provide a valid object to the 'object' argument.")
    }
  }

  g <- igraph::make_empty_graph(directed = FALSE)

  # Add propr nodes to network
  if(!missing(propr.object)){

    if(class(propr.object) != "propr") stop("Provide a valid object to the 'propr.object' argument.")
    propr.df <- getResults(propr.object, propr.cutoff)
    g <- migraph.add(g, propr.df$Partner, propr.df$Pair)
  }

  # Add propd nodes to network
  if(!missing(thetad.object)){

    if(class(thetad.object) != "propd") stop("Provide a valid object to the 'thetad.object' argument.")
    if(thetad.object@active != "theta_d") stop("Provide a valid object to the 'thetad.object' argument.")
    thetad.group <- unique(thetad.object@group)
    thetad.df <- getResults(thetad.object, thetad.cutoff)
    g <- migraph.add(g, thetad.df$Partner, thetad.df$Pair)
  }

  # Add propd nodes to network
  if(!missing(thetae.object)){

    if(class(thetae.object) != "propd") stop("Provide a valid object to the 'thetae.object' argument.")
    if(thetae.object@active != "theta_e") stop("Provide a valid object to the 'thetae.object' argument.")
    thetae.group <- unique(thetae.object@group)
    thetae.df <- getResults(thetae.object, thetae.cutoff)
    g <- migraph.add(g, thetae.df$Partner, thetae.df$Pair)
  }

  # Add propr edges to network
  if(!missing(propr.object)){

    g <- migraph.color(g, propr.df$Partner, propr.df$Pair, "forestgreen")
    message("Green: Pair positively proportional across all samples.")

    invProp <- propr.df$propr < 0
    if(any(invProp)){

      g <- migraph.color(g, propr.df$Partner[invProp], propr.df$Pair[invProp], "burlywood4")
      message("Brown: Pair inversely proportional across all samples.")
    }
  }

  # Add propd edges to network
  if(!missing(thetad.object)){

    g <- migraph.color(g, thetad.df[thetad.df$lrm1 > thetad.df$lrm2, "Partner"],
                       thetad.df[thetad.df$lrm1 > thetad.df$lrm2, "Pair"], "coral1") # red
    g <- migraph.color(g, thetad.df[thetad.df$lrm1 < thetad.df$lrm2, "Partner"],
                       thetad.df[thetad.df$lrm1 < thetad.df$lrm2, "Pair"], "lightseagreen") # blue
    message("Red: Pair has higher LRM in group ", thetad.group[1],
            " than in group ", thetad.group[2])
    message("Blue: Pair has higher LRM in group ", thetad.group[2],
            " than in group ", thetad.group[1])
  }

  # Add propd edges to network
  if(!missing(thetae.object)){

    g <- migraph.color(g, thetae.df[thetae.df$lrv1 < thetae.df$lrv2, "Partner"],
                       thetae.df[thetae.df$lrv1 < thetae.df$lrv2, "Pair"], "gold2") # gold
    g <- migraph.color(g, thetae.df[thetae.df$lrv1 > thetae.df$lrv2, "Partner"],
                       thetae.df[thetae.df$lrv1 > thetae.df$lrv2, "Pair"], "blueviolet") # purple
    message("Gold: Nearly all of total LRV explained by ", thetae.group[2])
    message("Purple: Nearly all of total LRV explained by ", thetae.group[1])
  }

  # Finalize network
  if(!missing(col1)) g <- migraph.color(g, col1, col = "darkred")
  if(!missing(col2)) g <- migraph.color(g, col2, col = "darkslateblue")
  g <- migraph.clean(g)

  # Plot network
  if(d3){
    packageCheck("rgl")
    coords <- igraph::layout_with_fr(g, dim = 3)
    suppressWarnings(igraph::rglplot(g, layout = coords))
  }else{
    plot(g)
  }

  return(g)
}

#' Get (Log-)ratios from Object
#'
#' This function provides a unified wrapper to retrieve (log-)ratios
#'  from \code{propr} and \code{propd} objects.
#'
#' When the \code{alpha} argument is provided, this function returns
#'  the (log-)ratios as \code{(partner^alpha - pair^alpha) / alpha}.
#'
#' @inheritParams getResults
#' @param melt A boolean. Toggles whether to melt the results for
#'  visualization with \code{ggplot2}.
#'
#' @return A \code{data.frame} of (log-)ratios.
#'
#' @export
getRatios <- function(object, cutoff = NA, melt = FALSE){

  # Get results based on cutoff
  df <- getResults(object, cutoff)

  index <- colnames(object@counts) %in% union(df$Partner, df$Pair)
  ct <- object@counts[, index]
  alpha <- object@alpha

  # Get (log-)ratios [based on alpha]
  lr <- ratios(ct, alpha)

  # Melt data if appropriate
  if(melt){
    return(wide2long(lr))
  }else{
    return(lr)
  }
}
