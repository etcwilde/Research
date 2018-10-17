#!/usr/bin/Rscript

colorSchemeFill = c("#6ca1f7", "#f74747")
colorSchemeBorder= c("#3364b2", "#b23333")

library(RSQLite)
library(ggplot2)
library(ggpubr)

linux_con <- dbConnect(drv=dbDriver('SQLite'), dbname="../linux.db")
llvm_con <- dbConnect(drv=dbDriver('SQLite'), dbname="../llvm.db")

query <- "
SELECT strftime('%Y', created_at) valYear,
       files_touched,
       lines_added,
       lines_removed,
       lines_added + lines_removed churn
FROM commits
"

# get the information for files between 2005 and the current year
# anything else is an error
linux_data <- dbGetQuery(linux_con, query)
linux_data = linux_data[linux_data$valYear >= 2005,]
linux_data = linux_data[linux_data$valYear < 2019,]

# LLVM doesn't have visibly invalid commit dates -- no cleanup necessary
llvm_data <- dbGetQuery(llvm_con, query)

# Disconnect from the databases
dbDisconnect(linux_con)
dbDisconnect(llvm_con)

# Make the plot
svg("file_distribution_over_time.svg", width=16, height=10)

# Get the limits
linux_data$valYear <- as.numeric(linux_data$valYear)
llvm_data$valYear <- as.numeric(llvm_data$valYear)

xlim0 <- c(min(linux_data$valYear), max(linux_data$valYear))
xlim1 <- c(min(llvm_data$valYear), max(llvm_data$valYear))
xlim <- c(min(xlim0, xlim1), max(xlim0, xlim1))


ylim0 <- boxplot.stats(linux_data$files_touched)$stats[c(1,5)]
ylim1 <- boxplot.stats(llvm_data$files_touched)$stats[c(1,5)]
ylim <- c(min(ylim0, ylim1), max(ylim0, ylim1))
ylim <- ylim * 1.3


print(xlim)
print(ylim)

# Linux plot
plot0 <- ggplot(linux_data, aes(valYear, files_touched, group=valYear, label=T)) + geom_boxplot(outlier.shape=NA, fill=colorSchemeFill[1], color=colorSchemeBorder[1])
plot0 <- plot0 +
         coord_cartesian(ylim=ylim, xlim=xlim) +
         xlab("Year") +
         ylab("Files Touched") +
         ggtitle("Linux") +
         scale_y_continuous(breaks=seq(ylim[1], ylim[2], by=1)) +
         scale_x_continuous(breaks=seq(xlim[1], xlim[2], by=1)) +
         theme(panel.background=element_blank(),
               text=element_text(size=20))

# LLVM plot
plot1 <- ggplot(llvm_data, aes(valYear, files_touched, group=valYear, label=T)) + geom_boxplot(outlier.shape=NA, fill=colorSchemeFill[2], color=colorSchemeBorder[2])

plot1 <- plot1 +
         coord_cartesian(ylim=ylim, xlim=xlim) +
         xlab("Year") +
         ylab("Files Touched") +
         ggtitle("LLVM") +
         scale_y_continuous(breaks=seq(ylim[1], ylim[2], by=1)) +
         scale_x_continuous(breaks=seq(xlim[1], xlim[2], by=1)) +
         theme(panel.background=element_blank(),
               text=element_text(size=20))

files_plots <- ggarrange(plot0, plot1, ncol=1, nrow=2)
files_plots <- annotate_figure(files_plots, top="Files Touched per Commit Over Time", fig.lab.size=20)

plot(files_plots)

# Look at code churn
# Make the plot
svg("churn_over_time.svg", width=16, height=10)

ylim2 <- boxplot.stats(linux_data$churn)$stats[c(1,5)]
ylim3 <- boxplot.stats(llvm_data$churn)$stats[c(1,5)]
ylim <- c(min(ylim2, ylim3), max(ylim2, ylim3))
ylim <- ylim * 1.3

# Linux

plot2 <- ggplot(linux_data, aes(valYear, churn, group=valYear, label=T)) + geom_boxplot(outlier.shape=NA, fill=colorSchemeFill[1], color=colorSchemeBorder[1])
plot2 <- plot2 +
         coord_cartesian(ylim=ylim, xlim=xlim) +
         xlab("Year") +
         ylab("Lines Churned") +
         ggtitle("Linux") +
         scale_y_continuous(breaks=seq(ylim[1], ylim[2], by=10)) +
         scale_x_continuous(breaks=seq(xlim[1], xlim[2], by=1)) +
         theme(panel.background=element_blank(),
               text=element_text(size=20))

# LLVM plot
plot3 <- ggplot(llvm_data, aes(valYear, churn, group=valYear, label=T)) + geom_boxplot(outlier.shape=NA, fill=colorSchemeFill[2], color=colorSchemeBorder[2])

plot3 <- plot3 +
         coord_cartesian(ylim=ylim, xlim=xlim) +
         xlab("Year") +
         ylab("Lines Churned") +
         ggtitle("LLVM") +
         scale_y_continuous(breaks=seq(ylim[1], ylim[2], by=10)) +
         scale_x_continuous(breaks=seq(xlim[1], xlim[2], by=1)) +
         theme(panel.background=element_blank(),
               text=element_text(size=20))

churn_plots <- ggarrange(plot2, plot3, ncol=1, nrow=2)
churn_plots <- annotate_figure(churn_plots, top="Code Churn Over Time")

plot(churn_plots)
