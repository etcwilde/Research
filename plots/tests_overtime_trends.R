#!/usr/bin/Rscript

colorSchemeFill = c("#6ca1f7", "#f74747")
colorSchemeBorder= c("#3364b2", "#b23333")

library(RSQLite)
library(ggplot2)
library(ggpubr)
library(reshape)
library(scales)

linux_con <- dbConnect(drv=dbDriver('SQLite'), dbname="../linux.db")
llvm_con <- dbConnect(drv=dbDriver('SQLite'), dbname="../llvm.db")

query <- "
SELECT valYear, avg(test_percent) 'test_percent', avg(src_percent) 'src_percent'
FROM
(SELECT commits.cid, cast(strftime('%Y', commits.created_at) AS INTEGER) valYear, 100. * no_test.files_touched / commits.files_touched 'src_percent', 100. * with_test.files_touched / commits.files_touched test_percent
FROM commits
JOIN (SELECT cid, count(*) files_touched FROM files WHERE filename NOT LIKE '%test%' GROUP BY cid) AS no_test
ON commits.cid = no_test.cid
JOIN (SELECT cid, count(*) files_touched FROM files WHERE filename LIKE '%test%' GROUP BY cid) AS with_test
ON commits.cid = with_test.cid)
GROUP BY valYear;
"

# get the information for files between 2005 and the current year
# anything else is an error
linux_data <- dbGetQuery(linux_con, query)
linux_data = linux_data[linux_data$valYear >= 2005,]
linux_data = linux_data[linux_data$valYear < 2019,]

print(linux_data)

# # LLVM doesn't have visibly invalid commit dates -- no cleanup necessary
llvm_data <- dbGetQuery(llvm_con, query)

# Disconnect from the databases
dbDisconnect(linux_con)
dbDisconnect(llvm_con)

# Make the plot
svg("test_ratio_file_distribution_over_time.svg", width=16, height=10)

# Get the limits
xlim0 <- c(min(linux_data$valYear), max(linux_data$valYear))
xlim1 <- c(min(llvm_data$valYear), max(llvm_data$valYear))
xlim <- c(min(xlim0, xlim1), max(xlim0, xlim1))

## Plot the files touched

# Linux plot
linux_trimmed <- data.frame(linux_data$valYear, linux_data$test_percent, linux_data$src_percent)
colnames(linux_trimmed) <- c("valYear", "Test Percent", "Source Percent")
plot0 <- ggplot(data=melt(linux_trimmed, id.vars=c("valYear"))) +
         ggtitle("Linux") +
         geom_col(aes(x = valYear, y = value, fill=variable)) +
         geom_text(aes(x = valYear, y = value, label=paste0(round(value, 2), '%'), group=variable), position=position_stack(vjust=0.5)) +
         labs(x="Year", y="Percent") +
         scale_x_continuous(breaks=seq(xlim[1], xlim[2], by=1)) +
         scale_fill_discrete(name="Type") +
         coord_cartesian(xlim=xlim) +
         theme(panel.background=element_blank())

# LLVM plot
llvm_trimmed <- data.frame(llvm_data$valYear, llvm_data$test_percent, llvm_data$src_percent)
colnames(llvm_trimmed) <- c("valYear", "Test Percent", "Source Percent")
plot1 <- ggplot(data=melt(llvm_trimmed, id.vars=c("valYear"))) +
         ggtitle("LLVM") +
         geom_col(aes(x = valYear, y = value, fill=variable)) +
         geom_text(aes(x = valYear, y = value, label=paste0(round(value, 2), '%'), group=variable), position=position_stack(vjust=0.5)) +
         labs(x="Year", y="Percent") +
         scale_x_continuous(breaks=seq(xlim[1], xlim[2], by=1)) +
         scale_fill_discrete(name="Type") +
         coord_cartesian(xlim=xlim) +
         theme(panel.background=element_blank())

files_plot <- ggarrange(plot0, plot1, ncol=1, nrow=2)
files_plot <- annotate_figure(files_plot, top="Ratio of Test to Source Files Touched Per Commit Over Time")
plot(files_plot)
