dat1 <- read.csv("tfgrowth.csv", row.names = 1)

## create data
dat2<- replicate(1000, ifelse(dat1$Height <= 3,dat1$Height + sample(c(-1,1),
                                        size=length(dat1$Height),replace=T) * rnorm(length(dat1$Height), 0.05, 0.01), 
                                          ifelse(dat1$Height > 3 & dat1$Height <= 5, dat1$Height + sample(c(-1,1), 
                                            size=length(dat1$Height),replace=T) * rnorm(length(dat1$Height), 0.25, 0.1),  
                                              dat1$Height + sample(c(-1,1),size=length(dat1$Height),replace=T) * rnorm(length(dat1$Height), 0.75, 0.5))))


#replace negative values with 0
dat2[dat2 < 0] <- 0


## makes some column names 
some.names <- paste0("new ", 1:1000)
colnames(dat2) <- some.names

## stick data together
Increment <- dat1$Increment
dat3 <- as.data.frame(dat3 <- cbind(Increment,dat2))


## create an empty list to store output in 
#storage <- list()
storage.list <- vector("list")
#NEED TO WORK OUT WHAT OUTPUTS YOU WANT FROM MODEL!!!
storage.esta <- vector("numeric")
storage.estb <- vector("numeric")
storage.sea <- vector("numeric")
storage.seb <- vector("numeric")
storage.pa <- vector("numeric")
storage.pb <- vector("numeric")

ceof.mtx <- matrix(NA, nrow = 1000, ncol = 6)

## run model and store output in the list. you can probably use apply instead of a for loop here if you need it be quicker
## this is just the first solution I could find. . 
for(i in names(dat3)[-1]){
  #storage.list[[i]] <- summary(lm(Increment ~ get(i), dat3))
  #storage.list[[i]] <- summary(nls(Increment ~ a * exp(b * get(i), dat3), start = list(a = 1, b = 0), trace = T))
  # Corrected version
  storage.list[[i]] <- summary(nls(Increment ~ a * exp(b * get(i, dat3)), start = list(a = 1, b = 0), trace = T))
  
  storage.esta[i] <- storage.list[[i]]$coefficients[1,1]
  storage.estb[i] <- storage.list[[i]]$coefficients[2,1]
  storage.sea[i] <- storage.list[[i]]$coefficients[1,2]
  storage.seb[i] <- storage.list[[i]]$coefficients[2,2]
  storage.pa[i] <- storage.list[[i]]$coefficients[1,4]
  storage.pb[i] <- storage.list[[i]]$coefficients[2,4]
}

head(storage)
