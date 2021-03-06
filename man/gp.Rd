\name{gp}
\alias{gp}

\title{
  Gaussian Process model
}

\description{
  
  Gaussian Process model.

}

\usage{

gp(formula, data, inputs, cov, estim = TRUE, ...)

}

\arguments{
  \item{formula}{

    A formula with a left-hand side specifying the response name, and the
    right-hand side the trend covariates (see examples below). Factors
    are not allowed neither as response nor as covariates.

  }
  \item{data}{

    A data frame containing the response, the inputs specified in
    \code{inputs}, and all the trend variables required in
    \code{formula}.

  }
  \item{inputs}{

    A character vector giving the names of the inputs.

  }
  \item{cov}{

    A covariance kernel object or call.

  }
  \item{estim}{

    Logical. If \code{TRUE}, the model parameters are estimated by
    Maximum Likelihood. The initial values can then be specified using
    the \code{parCovIni} and \code{varNoiseIni} arguments of
    \code{\link{mle,covAll-method}} passed though \code{dots}. If
    \code{FALSE}, a simple Generalised Least Squares estimation will be
    used, see \code{\link{gls,covAll-method}}. Then the value of
    \code{varNoise} must be given and passed through \code{dots} in case
    \code{noise} is \code{TRUE}.

  }
  \item{\dots}{

    Other arguments passed to the estimation method.  This will be the
    \code{\link{mle,covAll-method}} if \code{estim} is \code{TRUE} or
    \code{\link{gls,covAll-method}} if \code{estim} is \code{FALSE}. In
    the first case, the arguments will typically include
    \code{varNoiseIni}. In the second case, they will typically include
    \code{varNoise}. Note that a logical \code{noise} can be used in
    the "mle" case. In both cases, the arguments \code{y}, \code{X},
    \code{F} can not be used since they are automatically passed.

  }

}

\note{
  
  When \code{estim} is \code{TRUE}, the covariance object in \code{cov}
  is expected to provide a gradient when used to compute a covariance
  matrix, since the default value of \code{compGrad} \code{\link{mle}}.  
  
}

\value{
  
  A list object which is given the S3 class \code{"gp"}. The list content
  is very likely to change, and should be used through methods.

}

\author{

  Y. Deville, D. Ginsbourger, O. Roustant

}

\seealso{

  \code{\link{mle}} for a detailed example.

}

\examples{
## ==================================================================
## Example 1. Data sampled from a GP model with a known covTS object
## ==================================================================
set.seed(1234)
myCov <- covTS(inputs = c("Temp", "Humid"),
               kernel = "k1matern5_2",
               dep = c(range = "input"),
               value = c(range = 0.4))
## change coefficients (variances)
coef(myCov) <- c(0.5, 0.8, 2, 16)
d <- myCov@d; n <- 20
## design matrix
X <- matrix(runif(n*d), nrow = n, ncol = d)
colnames(X) <- inputNames(myCov)
## generate the GP realization
C <- covMat(myCov, X = X)
L <- t(chol(C))
zeta <- L \%*\% rnorm(n)
## GP modelling with constant mean
F <- matrix(1, nrow = n, ncol = 1)
varNoise <- 0.05
epsilon <- rnorm(n, sd = sqrt(varNoise))
beta <- 10
y <- F \%*\% beta + zeta + epsilon
## Towards prediction 
fit <- gls(myCov, X = X, y = y, F = F, varNoise = varNoise)

## parIni: add noise to true parameters
parCovIni <- coef(myCov)
parCovIni[] <- 0.9 * parCovIni[] +  0.1 * runif(length(parCovIni))
coefLower(myCov) <- rep(1e-2, 4)
coefUpper(myCov) <- c(5, 5, 20, 20)
est <- gp(y ~ 1, data = data.frame(y = y, X),
          inputs = colnames(X), cov = myCov, 
          noise = TRUE, varNoiseLower = 1e-2, 
          parCovIni = parCovIni) 
summary(est)
coef(est)

## =======================================================================
## Example 2. Predicting an additive function with an additive GP model
## =======================================================================

\dontrun{
    
addfun6d <- function(x){
  res <- x[1]^3 + cos(pi * x[2]) + abs(x[3]) * sin(x[3]^2) +
    3 * x[4]^3 + 3 * cos(pi * x[5]) + 3 * abs(x[6]) * sin(x[6]^2)
}

## 'Fit' is for the learning set, 'Val' for the validation set
set.seed(123)
nFit <- 50   
nVal <- 200
d <- 6 
inputs <- paste("x", 1L:d, sep = "")

## create design matrices with DiceDesign package 
require(DiceDesign)
require(DiceKriging)
set.seed(0)
dataFitIni <- DiceDesign::lhsDesign(nFit, d)$design 
dataValIni <- DiceDesign::lhsDesign(nVal, d)$design 
dataFit <- DiceDesign::maximinSA_LHS(dataFitIni)$design
dataVal <- DiceDesign::maximinSA_LHS(dataValIni)$design

colnames(dataFit) <- colnames(dataVal) <- inputs
testfun <- addfun6d
dataFit <- data.frame(dataFit, y = apply(dataFit, 1, testfun))
dataVal <- data.frame(dataVal, y = apply(dataVal, 1, testfun))

## Creation of "CovTS" object with one range by input
myCov <- covTS(inputs = inputs, d = d, kernel = "k1matern3_2", 
               dep = c(range = "input"))

## Creation of a gp object
fitgp <- gp(formula = y ~ 1, data = dataFit, inputs = inputs,
            cov = myCov, noise = TRUE, 
            parCovIni = rep(1, 2*d),
            parCovLower = c(rep(1e-4, 2*d)),
            parCovUpper = c(rep(5, d), rep(10,d)),
            control = list(maxit = 300, REPORT = 10))
 
predTS <- predict(fitgp, newdata = as.matrix(dataVal[ , inputs]), type = "UK")$mean

## Classical tensor product kernel as a reference for comparison
fitRef <- DiceKriging::km(formula = ~1,
                          design = dataFit[ , inputs],
                          response = dataFit$y,  covtype="matern3_2")
predRef <- predict(fitRef,
                   newdata = as.matrix(dataVal[ , inputs]),
                   type = "UK")$mean
## Compare TS and Ref
RMSE <- data.frame(TS = sqrt(mean((dataVal$y - predTS)^2)),
                   Ref = sqrt(mean((dataVal$y - predRef)^2)),
                   row.names = "RMSE")
print(RMSE)

Comp <- data.frame(y = dataVal$y, predTS, predRef)
plot(predRef ~ y, data = Comp, col = "black", pch = 4,
     xlab = "True", ylab = "Predicted",
     main = paste("Prediction on a validation set (nFit = ",
         nFit, ", nVal = ", nVal, ").", sep = ""))
points(predTS ~ y, data = Comp, col = "red", pch = 20)
abline(a = 0, b = 1, col = "blue", lty = "dotted")
legend("bottomright", pch = c(4, 20), col = c("black", "red"),
       legend = c("Ref", "Tensor Sum"))
       
## detach("package:DiceKriging", unload=TRUE)
## After running this part of the file 
## (to avoid conflicts between packages regarding `coef<-`)

}

##=======================================================================
## Example 3. A "covMan" object
##=======================================================================
myGaussFun <- function(x1, x2, par) { 
  h <- (x1 - x2) / par[1]
  SS2 <- sum(h^2)
  d2 <- exp(-SS2)
  kern <- par[2] * d2
  d1 <- 2 * kern * SS2 / par[1]            
  attr(kern, "gradient") <- c(theta = d1,  sigma2 = d2)
  return(kern)
}

if (require(inline) && require(MASS)) {
    
    ## -- Let us define an equivalent version "myGaussC" with inline package 
    ## (see also another example with Rcpp by typing: ?GPlab).
    kernCode <- "
       SEXP kern, dkern;
       int nprotect = 0, d;
       double SS2 = 0.0, d2, z, *rkern, *rdkern;

       d = LENGTH(x1);
       PROTECT(kern = allocVector(REALSXP, 1)); nprotect++;
       PROTECT(dkern = allocVector(REALSXP, 2)); nprotect++;
       rkern = REAL(kern);
       rdkern = REAL(dkern);

       for (int i = 0; i < d; i++) {
          z = ( REAL(x1)[i] - REAL(x2)[i] ) / REAL(par)[0];
          SS2 += z * z; 
       }

       d2 = exp(-SS2);
       rkern[0] = REAL(par)[1] * d2;
       rdkern[1] =  d2; 
       rdkern[0] =  2 * rkern[0] * SS2 / REAL(par)[0];

       SET_ATTR(kern, install(\"gradient\"), dkern);
       UNPROTECT(nprotect);
       return kern;
   "
    myGaussC <- cfunction(sig = signature(x1 = "numeric", x2 = "numeric",
                              par = "numeric"),
                          body = kernCode)
    
    ## -- Let us define a 4-dimensional covariance structure
    d <- 4
    myGauss <- covMan(
        kernel = myGaussC,
        hasGrad = TRUE,
        d = 4,
        parLower = c(theta = 0.0, sigma2 = 0.0),
        parUpper = c(theta = Inf, sigma2 = Inf),
        parNames = c("theta", "sigma2"),
        label = "my Gaussian kernel"
    )

    ## == Simulates data for covMan and trend ==
    n <- 100; 
    X  <- matrix(runif(n*d), nrow = n)
    colnames(X) <- inputNames(myGauss)
    coef(myGauss) <- myPar <- c(theta = 0.5, sigma2 = 2)
    C <- covMat(object = myGauss, X = X,
                compGrad = FALSE,  index = 1L, checkNames = FALSE)

    ## set.seed(456)
    p <- ncol(X) + 1
    y <- mvrnorm(mu = rep(0, n), Sigma = C) 
    F <- matrix(runif(n * p), nrow = n, ncol = p)
    beta <- (1:p) / p
    y <- tcrossprod(F, t(beta)) + y

    ## == ML estimation. ==
    design <- data.frame(X)
    names(design) <- paste("x", 1:4, sep = "")
    res <- gp(formula = y ~ ., data = data.frame(y = y, design),
             inputs = names(design), cov = myGauss,
             parCovIni = c(0.5, 0.5), varNoiseLower = 1e-4,
             parCovLower = c(1e-5, 1e-5), parCovUpper = c(Inf, Inf)) 
    summary(res)
    coef(res)
    p <- predict(res, newdata = design, type = "UK")           

}

##=======================================================================
## Example 3 (continuing). Another way of improving speed: 
## A kernel admitting matrix arguments
##=======================================================================

## -- Implemented in R, but with a kernel admitting matrices as arguments

myGaussFunVec <- function(X1, X2, par) { 
  # X1, X2 : matrices with same number of column d (dimension)
  n <- nrow(X1)
  d <- ncol(X1)     
  SS2 <- 0
  
  for (j in 1:d){
    Aj <- outer(X1[, j], X2[, j], "-")
    Hj2 <- (Aj / par[1])^2
    SS2 <- SS2 + Hj2
  }
  D2 <- exp(-SS2)
  kern <- par[2]*D2
  D1 <- 2 * kern * SS2 / par[1] 
  attr(kern, "gradient") <- list(theta = D1,  sigma2 = D2)
  
  return(kern)
}

myGaussVec <- covMan(
    kernel = myGaussFunVec,
    hasGrad = TRUE,
    acceptMatrix = TRUE,
    d = 4,
    parLower = c(theta = 0.0, sigma2 = 0.0),
    parUpper = c(theta = Inf, sigma2 = Inf),
    parNames = c("theta", "sigma2"),
    label = "my Gaussian kernel"
)

## == ML estimation. ==
res2 <- gp(formula = y ~ ., data = data.frame(y = y, design),
           inputs = names(design), cov = myGaussVec,
           compGrad = TRUE, 
           parCovIni = c(0.5, 0.5), varNoiseLower = 1e-4,
           parCovLower = c(1e-5, 1e-5), parCovUpper = c(Inf, Inf)) 
summary(res2)
coef(res2)
p2 <- predict(res2, newdata = design, type = "UK")    

}


