#*******************************************************************************
#Summary: Contains all of the functions involved in carrying out this simulation,
#         i.e. a function go generate populations, replicates, replicates across
#         epv, and one to call all of the other functions and conduct the
#         entire simulation. A plot matching Courvoisier's paper is replicated.

#Author: Raul J.T.A.
#*******************************************************************************


#********************************************************************************
# Preliminary settings ------------
#********************************************************************************

#loading packages
library(tidyverse)
library(foreach)
library(doParallel)
library(snow)
library(DescTools)

#functions to create populations
odds_ratio <- function(p1,p0){
  (p1/(1-p1))/(p0/(1-p0))
}
or_tab <- function(tab){
 or <-  (tab[1,1] * tab[2,2]) / (tab[1,2] * tab[2,1])
}

#odds ratios for simulations (use only one to test functions)
true_or <-  c(1.0, 1.2, 1.5, 2.0)

#satisfies above constraint constraint
p1 <- c(.5, .52277438, .55051526, .58578645)
p0 <- c(.5, .47722562, .44949474, .41421355)

#satisfies proportion of events approx 25%
#p1 <- .26707198
#p0 <- .23292802
#tolerance=.0001

#********************************************************************************
# Simulation functions------------
#********************************************************************************

#generates the appropriate population given an odds ratio
generate_population <- function(true_or, p0, p1, tolerance=.0001){
  
  pop_or <- 0
  #creating two random sub-populations each of size 50,000 to meet true OR
  while (abs(true_or - pop_or) > tolerance) {
    
    #creating population-outcome from which samples (replicates) will be drawn. 
    x1 <- rbinom(50000, 1, p1)
    x0 <- rbinom(50000, 1,p0)
    pop_outcome <- c(x1,x0)
    
    #adding whether the observation belonged to x1 or x0 to calc OR later on.
    location1 <- rep_len("X1", 50000)
    location0 <- rep_len("X0", 50000)
    location <- c(location1, location0)
    
    #creating data and contingency table to obtain or
    dat <- cbind.data.frame(pop_outcome, location, stringsAsFactors = T)
    tab <- table(dat)
    
    pop_or = (tab[1,1] * tab[2,2]) / (tab[1,2] * tab[2,1])
  }
  
  #creating another variable of random uniform variates to shuffle data
  randomizer <- runif(100000, min = 0, max = 1)
  dat <- cbind.data.frame(pop_outcome, location, randomizer,stringsAsFactors=F)
  dat <- arrange(dat,randomizer)
  dat <- dat %>% select(pop_outcome, location)
}


#backbone: performs sequential sampling to collect all of the samples
generate_replicates <- function(dat, epv, iterations = 500,cores=detectCores()-2){
  
  replicates <- vector(mode = "list",length = iterations)
  
  if(cores>1){
    start <- Sys.time()
  
  cl <- makeCluster(cores)
  registerDoParallel(cl)
  
  replicates <- foreach(j = 1:iterations) %dopar% {
  
    #initializing vector holding indices and data.frame
    indices <-  rep(NULL,10000)
    sample_outcome <- as.data.frame(matrix(nrow=10000,ncol = 2))
    i <- 1
    dat_copy <- dat
  
    #sequential sampling until epv constraint is met
  while(sum(sample_outcome$V1,na.rm = T) < epv){
    indices[i] <- sample(nrow(dat_copy), 1)
    sample_outcome[i,] <- dat_copy[indices[i],]
    dat_copy <- dat_copy[-c(indices[i]),]
    i <- i+1
  }
  replicates[[j]] <- na.omit(sample_outcome)
  } 
  stopCluster(cl)
    print(Sys.time()-start)
  return(replicates)

  } else{
    start <- Sys.time()
    for(j in 1:iterations){
      
      #initializing vector holding indices and data.frame
      indices <-  rep(NULL,10000)
      sample_outcome <- as.data.frame(matrix(nrow=10000,ncol = 2))
      i <- 1
      dat_copy <- dat
      
      #sequential sampling until epv constraint is met
      while(sum(sample_outcome$V1,na.rm = T) < epv){
        indices[i] <- sample(nrow(dat_copy), 1)
        sample_outcome[i,] <- dat_copy[indices[i],]
        dat_copy <- dat_copy[-c(indices[i]),]
        i <- i+1
      }
     replicates[[j]] <- na.omit(sample_outcome)
    } 
    print(Sys.time()-start)
    return(replicates)
    
  }
}

#generates one row in plot
#epv needed to produce one row and number of iterations
epv <- c(3, 5, 7, 10, 15, 20, 25)
iter <- 50

generate_replicates_across_epv <- function(dat,epv,iterations = 500){
  
  replicate_names <- str_c("EPV of ",as.character(c(epv)))
  replicates <- vector(mode = "list",length = length(epv))
  for (i in 1:length(epv)){
    replicates[[i]] <- generate_replicates(dat,epv[i],iterations)
  } 
  names(replicates) <- replicate_names
  return(replicates)
}


#Function to carry out the entire simulation 
epv_simulation <- function(epv, iterations = 500){

  #generating population data for each true_or
  pops <- vector(mode = "list", length = 4L)
  for(i in 1:length(true_or)){
  pops[[i]] <- generate_population(true_or[i], p0[i], p1[i])
  }
  
  #creating all 4 rows of the figure, one row at a time
  reps <- vector(mode = "list", length = 4L)
  reps_names <- str_c("True OR of ",as.character(c(true_or)))
  for(i in 1:length(pops)) {
   reps[[i]] <-  generate_replicates_across_epv(pops[[i]], epv, iterations = iterations)
  }
  names(reps) <- reps_names
  
  return(reps)
}

#********************************************************************************
# Running simulation ------------
#********************************************************************************

reps <- epv_simulation(epv, iter)

#********************************************************************************
# Preparing plot and calculating key quantities------------
#********************************************************************************

#converting both values into factors so table will work
temp <- reps

test <- NULL
for(i in 1:length(true_or)){
  for(j in 1:length(epv)){
    for(k in 1:iter){
     test <-  temp[[i]][[j]][[k]]
     
     test$V1 <- as.factor(test$V1)
     levels(test$V1) <- c("0","1")
     test$V2 <- as.factor(test$V2)
     levels(test$V2) <- c("X0","X1")
     
     temp[[i]][[j]][[k]] <- test
     test <- NULL
    }
  }
}

#calculating all of the necessary quantities
dummy1 <- vector(mode = "list", length = iter)
dummy2 <- vector(mode = "list", length = length(epv))
dummy3 <- vector(mode = "list", length = length(true_or))
names(dummy2) <- names(reps$`True OR of 1`)
names(dummy3) <- names(reps)

for(i in 1:length(dummy2)){dummy2[[i]] <- dummy1}
for(i in 1:length(dummy3)){dummy3[[i]] <- dummy2}

#sample size
n <- dummy3

for(i in 1:length(true_or)){
  for(j in 1:length(epv)){
n[[i]][[j]] <- lapply(temp[[i]][[j]], function(x) sum(unlist(table(x))))
  }
}

#gini
gini <- dummy3

for(i in 1:length(true_or)){
  for(j in 1:length(epv)){
    gini[[i]][[j]] <- lapply(temp[[i]][[j]], function(x) Gini(unlist(table(x))))
  }
}

#or
or <- dummy3

for(i in 1:length(true_or)){
  for(j in 1:length(epv)){
    for(k in 1:iter){
    or[[i]][[j]][[k]] <- or_tab(table(temp[[i]][[j]][[k]]))
   }
  }
}

#figure 1
#nonconverged reps (OR > 50 or < 1/50; or NaN or Inf)
bad_reps<- dummy3
rep <- NULL

for(i in 1:length(true_or)){
  for(j in 1:length(epv)){
    for(k in 1:iter){
      rep <- or[[i]][[j]][[k]]
      if(rep < 1/50 || rep > 50 || is.infinite(rep) || is.nan(rep)) {
        bad_reps[[i]][[j]][[k]] <- 1
      } else {bad_reps[[i]][[j]][[k]] <- 0 }
      rep <- NULL
    }
  }
}

#obtaning the necessary quantity
dummy <- as.data.frame(matrix(nrow = length(epv), ncol = length(true_or)))
rownames(dummy) <- as.character(epv)
colnames(dummy) <- as.character(true_or)

nonconverged <-  gini_tab <- n_tab <- dummy

for(i in 1:length(true_or)){
  for(j in 1:length(epv)){
    nonconverged[j, i]<- mean(unlist(bad_reps[[i]][[j]]))
    gini_tab[j, i]<- mean(unlist(gini[[i]][[j]]))
    n_tab[j, i]<- mean(unlist(n[[i]][[j]]))
  }
}

#converting each table into format acceptable for ggplot
nonconverged_df <- as.tibble(cbind(as.character(rep(epv, 4)), unlist(nonconverged)))
group <- c(rep("OR_1", 7), rep("OR_1.2", 7), rep("OR_1.5", 7), rep("OR_2.0", 7))
nonconverged_df <- cbind(group, nonconverged_df)
colnames(nonconverged_df) <- c("pop_or", "sample_epv", "prop")
nonconverged_df$sample_epv <- factor(nonconverged_df$sample_epv, levels = c("3", "5", "7", "10", "15", "20", "25"))
nonconverged_df$prop <- as.numeric(nonconverged_df$prop)

#creating analagous data containing courvoisier's results
cv_prop <- c(.07, .005, 0, 0, 0, 0, 0,
            .08, .019, .009, 0, 0, 0, 0,
            .11, .035, .011, .001, 0, 0, 0,
            .14, .055, .022, .005, .003, .001, 0)

comparison <- rbind(nonconverged_df, nonconverged_df)
comparison$prop[29:56] <- cv_prop
comparison$group <- c(rep("categ", 28), rep("cont", 28))
comparison$group2 <- str_c(comparison$pop_or, comparison$group, sep = "_")

#obtaining plot
ggplot(data = nonconverged_df, aes(x = sample_epv, y = prop, group = pop_or))+ 
  geom_point() + geom_line(aes(color = pop_or)) +
  labs(title="Percentage of nonconverged replications",x="epv", y = "nonconverged reps (%)") +
  scale_y_continuous(breaks=seq(0, .8, by=.05), labels=as.character(seq(0, .8, by=.05)))

ggplot(data = comparison, aes(x = sample_epv, y = prop, group = group2))+ 
  geom_point() + geom_line(aes(color = group2)) +
  labs(title="Percentage of nonconverged replications - Comparison",x="epv", y = "nonconverged reps (%)") +
  scale_y_continuous(breaks=seq(0, .8, by=.05), labels=as.character(seq(0, .8, by=.05)))





