dat1 <- read.csv("HeightData.csv", row.names = 1)


n.sims <- 20

# To 2 m tall: < 0.05 m error
# To 5 m tall: < 0.25 m error
# 5 m tall and above: < 0.50 m error



# STORE THE COEFFICIENTS AND THE MODEL PREDICTIONS
coef.mtx <- matrix(NA, nrow = n.sims, ncol = 8)
pred.mtx <- matrix(NA, ncol = n.sims, nrow = 292)

pb <- txtProgressBar(min = 1, max = n.sims, initial = 1, style = 3)

idx <- 1

for(i in names(dat3)[-1]){

    # This is the non-linear quantile regression
  mod <- nlrq(Increment ~ a * exp(b * get(i, dat3)), start = list(a = 1, b = 0), tau = 0.95)
  mod.summ <- summary(mod)
  mod.cf <- coefficients(mod.summ)
  
  coef.mtx[idx,] <- mod.cf
  pred.mtx[,idx] <- predict(mod, get(i, dat3))
  idx <- idx + 1
  setTxtProgressBar(pb, idx)
}

coef.df <- data.frame(coef.mtx)
names(coef.df) <- c("a.est", "b.est", "a.se", "b.se", "t.a", "t.b", "p.a", "p.b")

perc95 <- function(x) {quantile(x, c(0.05, 0.5, 0.95))}
pred.summ <- apply(pred.mtx, 1, perc95) 
matplot(y = t(pred.summ), x = dat1$Height, lty = c(2,1,2), type = 'l', col = c('grey', 'black', 'grey'))

true.mod <- nlrq(Increment ~ a * exp(b * Height), data = dat1, tau = 0.95, start = list(a = 1, b = 0), trace = T)
p <- predict(true.mod, dat1$Height)
lines(p ~ dat1$Height, col = 'blue')


idx <- 1
for(i in names(dat3)[-1]){
  # Corrected version
  # This is the least squares fit.
  # mod <- nls(Increment ~ a * exp(b * get(i, dat3)), start = list(a = 1, b = 0), trace = T)
  
  # This is the non-linear quantile regression
  mod <- nlrq(Increment ~ a * exp(b * get(i, dat3)), start = list(a = 1, b = 0), tau = 0.95)
  mod.summ <- summary(mod)
  mod.cf <- coefficients(mod.summ)
  
  coef.mtx[idx,] <- mod.cf
  pred.mtx[,idx] <- predict(mod, get(i, dat3))
  idx <- idx + 1
  setTxtProgressBar(pb, idx)
}

coef.df <- data.frame(coef.mtx)
names(coef.df) <- c("a.est", "b.est", "a.se", "b.se", "t.a", "t.b", "p.a", "p.b")

perc95 <- function(x) {quantile(x, c(0.05, 0.5, 0.95))}
pred.summ <- apply(pred.mtx, 1, perc95) 
matplot(y = t(pred.summ), x = dat1$Height, lty = c(2,1,2), type = 'l', col = c('grey', 'black', 'grey'))

true.mod <- nlrq(Increment ~ a * exp(b * Height), data = dat1, tau = 0.95, start = list(a = 1, b = 0), trace = T)
p <- predict(true.mod, dat1$Height)
lines(p ~ dat1$Height, col = 'blue')
