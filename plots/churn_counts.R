#!/usr/bin/Rscript

library(RSQLite)
library(ggplot2)
library(ggpubr)
library(reshape)

linux_con <- dbConnect(drv=dbDriver('SQLite'), dbname="../linux.db")
llvm_con <- dbConnect(drv=dbDriver('SQLite'), dbname="../llvm.db")

query <- "
SELECT churn, count(*) commits
FROM
( SELECT cid,
         sum(added) + sum(removed) churn
   FROM (SELECT * FROM files WHERE filename NOT LIKE '%test%')
   GROUP BY cid)
GROUP BY churn;
"

# get the information for files between 2005 and the current year
# anything else is an error
linux_data <- dbGetQuery(linux_con, query)

# LLVM doesn't have visibly invalid commit dates -- no cleanup necessary
llvm_data <- dbGetQuery(llvm_con, query)

# Disconnect from the databases
dbDisconnect(linux_con)
dbDisconnect(llvm_con)

# Data
data <- merge(x = linux_data, y = llvm_data, by = 'churn')
colnames(data) <- c("churn", "linux_count", "llvm_count")

data$linux_count <- data$linux_count / sum(data$linux_count)
data$llvm_count <- data$llvm_count / sum(data$llvm_count)
data <- melt(data, id.vars=c("churn"))

# Limits
xlim = c(min(data$churn), max(data$churn))
ylim = c(min(data$value), max(data$value))
print(xlim)
print(ylim)


data$variable <- as.character(data$variable)
data$variable[data$variable == "linux_count"] <- "Linux Percent"
data$variable[data$variable == "llvm_count"] <- "LLVM Percent"
data$variable <- as.factor(data$variable)

# Make the plot
svg("churn_commit_counts.svg", width=16, height=10)

plot <- ggplot(data=data, aes(x=churn, y=value, color=variable, fill=variable)) +
        geom_histogram(alpha=0.5, stat='identity', position='identity') +
        ggtitle("Number of Commits Churning a Varying number of lines") +
        labs(x="Lines Churned", y="Percent", fill="Repository", color="Repository") +
        scale_color_hue(h=c(250, 10)) +
        scale_fill_hue(h=c(250, 10)) +
        coord_cartesian(xlim=c(0, 25), ylim=c(0, 1)) +
        theme(panel.background=element_blank(),
              text = element_text(size=20)
              )

plot(plot)
