#!/usr/bin/env Rscript

### ---------------------------------------------------------------------------
### --- WD_Datamodel_Terms.R
### --- Author: Goran S. Milovanovic, Data Scientist, WMDE
### --- Developed under the contract between Goran Milovanovic PR Data Kolektiv
### --- and WMDE.
### --- Contact: goran.milovanovic_ext@wikimedia.de
### --- April 2019.
### ---------------------------------------------------------------------------
### --- COMMENT:
### --- R ETL procedures for the WD JSON dumps in hdfs
### ---------------------------------------------------------------------------
### ---------------------------------------------------------------------------
### --- LICENSE:
### ---------------------------------------------------------------------------
### --- GPL v2
### --- This file is part of the Wikidata Languages Project (WLP)
### ---
### --- WLP is free software: you can redistribute it and/or modify
### --- it under the terms of the GNU General Public License as published by
### --- the Free Software Foundation, either version 2 of the License, or
### --- (at your option) any later version.
### ---
### --- WLP is distributed in the hope that it will be useful,
### --- but WITHOUT ANY WARRANTY; without even the implied warranty of
### --- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
### --- GNU General Public License for more details.
### ---
### --- You should have received a copy of the GNU General Public License
### --- along with WLP. If not, see <http://www.gnu.org/licenses/>.
### ---------------------------------------------------------------------------

# - setup
library(XML)
library(data.table)
library(tidyverse)

# - to runtime Log:
print(paste("--- WD_Datamodel_Terms.R RUN STARTED ON:", 
            Sys.time(), sep = " "))
# - GENERAL TIMING:
generalT1 <- Sys.time()

### --- Read WLP paramereters
# - fPath: where the scripts is run from?
fPath <- as.character(commandArgs(trailingOnly = FALSE)[4])
fPath <- gsub("--file=", "", fPath, fixed = T)
fPath <- unlist(strsplit(fPath, split = "/", fixed = T))
fPath <- paste(
  paste(fPath[1:length(fPath) - 1], collapse = "/"),
  "/",
  sep = "")
params <- xmlParse(paste0(fPath, "WD_LanguagesLandscape_Config.xml"))
params <- xmlToList(params)

### --- Directories
dataDir <- params$general$datamodel_terms_dataDir
publicDir <- params$general$datamodel_terms_publicDir
logDir <- params$general$logDir

### --- Spark: spark2-submit parameters
sparkMaster <- params$spark$master
sparkDeployMode <- params$spark$deploy_mode
sparkNumExecutors <- params$spark$num_executors
sparkDriverMemory <- params$spark$driver_memory
sparkExecutorMemory <- params$spark$executor_memory
sparkExecutorCores <- params$spark$executor_cores

### --- Check wmf.wikidata_entity snapshot
# - Kerberos init
system(command = 'sudo -u analytics-privatedata kerberos-run-command analytics-privatedata hdfs dfs -ls', 
       wait = T)
query <- 'SHOW PARTITIONS wmf.wikidata_entity;'
write(query, paste0(dataDir, 'snapshot_query.hql'))
system(command = paste0(
                  'sudo -u analytics-privatedata kerberos-run-command analytics-privatedata /usr/local/bin/beeline --incremental=true --silent -f "', 
                  paste0(dataDir, 'snapshot_query.hql'), '" > ',
                  paste0(dataDir, "wdsnaps.csv")),
       wait = T)
snaps <- read.csv(paste0(dataDir, 'wdsnaps.csv'), 
                  stringsAsFactors = F)
currentSnap <- tail(snaps$partition, 1)
currentSnap <- substr(currentSnap, 10, 19)
labs <- read.csv(paste0(dataDir, 'DM_Terms_Labels.csv'), 
                 stringsAsFactors = F)
stopSnap <- tail(labs$snapshot, 1)
rm(labs)

### --- If wmf.wikidata_entity is updated, update:
if (currentSnap != stopSnap) {
  
  # - wait: maybe the wmf.wikidata_entity table is not populated
  Sys.sleep(10*60*60)
  
  # - Spark ETL
  # - to runtime Log:
  print(paste("--- WD_Datamodel_Terms.py STARTED ON:", 
              Sys.time(), sep = " "))
  # - Kerberos init
  system(command = 'sudo -u analytics-privatedata kerberos-run-command analytics-privatedata hdfs dfs -ls', 
         wait = T)
  system(command = paste0('sudo -u analytics-privatedata spark2-submit ', 
                          sparkMaster, ' ',
                          sparkDeployMode, ' ', 
                          sparkNumExecutors, ' ',
                          sparkDriverMemory, ' ',
                          sparkExecutorMemory, ' ',
                          sparkExecutorCores, ' ',
                          paste0(fPath, 'WD_Datamodel_Terms.py')),
         wait = T)
  
  # - update statistics
  num_items <- read.csv(paste0(dataDir, "num_items.csv"))
  num_items <- num_items[1, 1]
  
  # - update Labels
  labels <- read.csv(paste0(dataDir, 'DM_Terms_Labels.csv'),
                     header = T,
                     row.names = 1,
                     stringsAsFactors = F,
                     check.names = F)
  update <- read.csv(paste0(dataDir, 'update_Labels.csv'),
                     header = T,
                     stringsAsFactors = F,
                     check.names = F)
  update$snapshot <- currentSnap
  labels <- rbind(labels, update)
  write.csv(labels, paste0(dataDir, 'DM_Terms_Labels.csv'))
  # - update statistics
  num_labels <- sum(update$count)
  
  # - update aliases
  aliases <- read.csv(paste0(dataDir, 'DM_Terms_Aliases.csv'),
                      header = T,
                      row.names = 1,
                      stringsAsFactors = F,
                      check.names = F)
  update <- read.csv(paste0(dataDir, 'update_Aliases.csv'),
                     header = T,
                     stringsAsFactors = F,
                     check.names = F)
  update$snapshot <- currentSnap
  colnames(update)[1] <- "language"
  aliases <- rbind(aliases, update)
  write.csv(aliases, paste0(dataDir, 'DM_Terms_Aliases.csv'))
  # - update statistics
  num_aliases <- sum(update$count)
  
  # - update descriptions
  descriptions <- read.csv(paste0(dataDir, 'DM_Terms_Descriptions.csv'),
                           header = T,
                           row.names = 1,
                           stringsAsFactors = F,
                           check.names = F)
  update <- read.csv(paste0(dataDir, 'update_Descriptions.csv'),
                     header = T,
                     stringsAsFactors = F,
                     check.names = F)
  update$snapshot <- currentSnap
  colnames(update)[1] <- "language"
  descriptions <- rbind(descriptions, update)
  write.csv(descriptions, paste0(dataDir, 'DM_Terms_Descriptions.csv'))
  # - update statistics
  num_descriptions <- sum(update$count)
  
  # - statistics file
  stats <- data.frame(num_items = num_items,
                      num_labels = num_labels, 
                      num_descriptions = num_descriptions,
                      num_aliases = num_aliases)
  write.csv(stats, paste0(dataDir, "datamodel_stats.csv"))
  
  # - copy to public directory:
  cFiles <- c('DM_Terms_Labels.csv',
              'DM_Terms_Aliases.csv',
              'DM_Terms_Descriptions.csv',
              'datamodel_stats.csv')
  for (i in 1:length(cFiles)) {
    print(paste0('Copying: ', cFiles[i], ' to publicDir.'))
    system(command = 
             paste0('cp ', dataDir, cFiles[i], ' ', publicDir),
           wait = T)
  }
  
} else {
  
  # - to runtime Log:
  print("Nothing to update.")

}

### --------------------------------------------------
### --- copy and clean up log files:
### --------------------------------------------------
# - copy the main log file to published for timestamp
# - toRuntime log:
print("Copy main log to archive; clean up log.")
system(command = 
         paste0('cp ', logDir, 'WD_Datamodel_Terms_LOG.log ' , logDir, 'archive'),
       wait = T)
# - clean up
file.remove(paste0(logDir, 'WD_Datamodel_Terms_LOG.log'))

# - to runtime Log:
print(paste("--- WD_Datamodel_Terms.R RUN ENDED ON:", 
            Sys.time(), sep = " "))
# - conclusion
print("DONE. Exiting.")



# ### ---- INIT
# 
# # DM_Terms_Aliases.csv
# 
# # - produce DM_Terms_Labels.csv
# lF <- list.files(dataDir)
# lF <- lF[grepl("DatamodelTerms_Labels", lF)]
# dataSet <- lapply(paste0(dataDir, lF), fread)
# dataSet <- rbindlist(dataSet)
# file.remove(paste0(dataDir, lF))
# write.csv(dataSet, 
#           paste0(dataDir, "DM_Terms_Labels.csv"))
# 
# 
# # - produce DM_Terms_Descriptions.csv
# lF <- list.files(dataDir)
# lF <- lF[grepl("DatamodelTerms_Descriptions", lF)]
# dataSet <- lapply(paste0(dataDir, lF), fread)
# dataSet <- rbindlist(dataSet)
# file.remove(paste0(dataDir, lF))
# colnames(dataSet) <- c('language', 'count', 'snapshot')
# write.csv(dataSet, 
#           paste0(dataDir, "DM_Terms_Descriptions.csv"))
# 
# # - produce DM_Terms_Aliases.csv
# lF <- list.files(dataDir)
# lF <- lF[grepl("DatamodelTerms_Aliases", lF)]
# dataSet <- lapply(paste0(dataDir, lF), fread)
# dataSet <- rbindlist(dataSet)
# file.remove(paste0(dataDir, lF))
# colnames(dataSet) <- c('language', 'count', 'snapshot')
# write.csv(dataSet, 
#           paste0(dataDir, "DM_Terms_Aliases.csv"))



