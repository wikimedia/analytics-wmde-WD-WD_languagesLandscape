
### ---------------------------------------------------------------------------
### --- WD_LanguagesLandscape.R
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
### ---------------------------------------------------------------------------
### --- Script: WD_LanguagesLandscape.R
### ---------------------------------------------------------------------------
### --- DESCRIPTION:
### --- WD_LanguagesLandscape.py performs ETL procedures
### --- over the Wikidata JSON dumps in hdfs.
### ---------------------------------------------------------------------------

# - setup
library(XML)
library(data.table)
library(stringr)
library(jsonlite)
library(dplyr)
library(tidyr)
library(httr)
library(htmltab)

# - to runtime Log:
print(paste("--- WD_LanguagesLandscape.R RUN STARTED ON:", 
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
dataDir <- params$general$dataDir
logDir <- params$general$logDir
outDir <- params$general$outDir
publicDir <- params$general$pubDataDir
hdfsPath <- params$general$hdfsPath
### --- spark2-submit parameters:
sparkMaster <- params$spark$master
sparkDeployMode <- params$spark$deploy_mode
sparkNumExecutors <- params$spark$num_executors
sparkDriverMemory <- params$spark$driver_memory
sparkExecutorMemory <- params$spark$executor_memory
sparkExecutorCores <- params$spark$executor_cores

### ---------------------------------------------------
### --- 1 The Fundamental Datasets
### ---------------------------------------------------

# - clean dataDir
file.remove(paste0(dataDir, list.files(dataDir)))

### --- Spark ETL: WD Dump processing
# - to runtime Log:
print(paste("--- wd_processDump_Spark.py Pyspark ETL Procedures STARTED ON:", 
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
                        paste0(fPath, 'WD_LanguagesLandscape.py')),
       wait = T)

### --- Map-Reduce ETL: WD re-use dataset
### --- ETL from goransm.wdcm_clients_wb_entity_usage
### --- w. HiveQL from Beeline
filename <- paste0(dataDir, "wd_entities_reuse.tsv")
queryFile <- paste0(fPath, "wd_reuse_HiveQL_Query.hql")
kerberosPrefix <- 'sudo -u analytics-privatedata kerberos-run-command analytics-privatedata '
hiveQLquery <- 'SET hive.mapred.mode=unstrict; SELECT eu_entity_id, COUNT(*) AS eu_count FROM 
                  (SELECT DISTINCT eu_entity_id, eu_page_id, wiki_db FROM goransm.wdcm_clients_wb_entity_usage) 
                AS t GROUP BY eu_entity_id;'
# - write hql
write(hiveQLquery, queryFile)
# - to Report
print("Fetching reuse data from goransm.wdcm_clients_wb_entity_usage.")
# - Kerberos init
system(command = paste0(kerberosPrefix, ' hdfs dfs -ls'), 
       wait = T)
# - Run query
query <- system(command = paste(kerberosPrefix, 
                                '/usr/local/bin/beeline --incremental=true --silent -f "',
                                paste0(queryFile),
                                '" > ', filename,
                                sep = ""),
                wait = TRUE)
# - to Report
print("DONE w. ETL from Hadoop: WD re-use dataset.")
print("DONE w. fundamental dataset production.")

### --- Compose labels dataset from hdfs
# - to runtime Log:
print(paste("--- Collect Final Labels Dataset STARTED ON:", 
            Sys.time(), sep = " "))
# - copy splits from hdfs to local dataDir
# - from statements:
system(paste0('sudo -u analytics-privatedata kerberos-run-command analytics-privatedata hdfs dfs -ls ', 
              hdfsPath, 'wd_dump_item_language > ', 
              dataDir, 'files.txt'), 
       wait = T)
files <- read.table(paste0(dataDir, 'files.txt'), skip = 1)
files <- as.character(files$V8)[2:length(as.character(files$V8))]
file.remove(paste0(dataDir, 'files.txt'))
for (i in 1:length(files)) {
  system(paste0('sudo -u analytics-privatedata kerberos-run-command analytics-privatedata hdfs dfs -text ', 
                files[i], ' > ',  
                paste0(dataDir, "wd_dump_item_language", i, ".csv")), wait = T)
}
# - read splits: dataSet
# - load
lF <- list.files(dataDir)
lF <- lF[grepl("wd_dump_item_language", lF)]
dataSet <- lapply(paste0(dataDir, lF), 
                  function(x) {fread(x, header = F)})
# - collect
dataSet <- rbindlist(dataSet)
# - schema
colnames(dataSet) <- c('entity', 'language')

# - collect stats
stats <- list()
stats$totalN_Labels <- dim(dataSet)[1]

### --- collect unique language codes
uniqueLanguageCodes <- sort(unique(dataSet$language))
# - collect stats
stats$uniqueN_Labels <- length(uniqueLanguageCodes)

# - store
saveRDS(dataSet,
        paste0(outDir, "wd_entities_languages.Rds"))

### ---------------------------------------------------
### --- 2. Per item and per language re-use statistics
### ---------------------------------------------------

### --- how many languages, per item:
setkey(dataSet, entity)
itemCount <- dataSet[, .N ,by = entity]

# - remove DataSet: save memory on stat100*
rm(dataSet); gc()
colnames(itemCount) <- c('entity', 'language_count')

### --- WDCM Usage dataset
wdcmReuse <- fread(paste0(
  dataDir, 'wd_entities_reuse.tsv'), 
  sep = "\t")

# - schema
colnames(wdcmReuse) <- c('entity', 'reuse')
setkey(wdcmReuse, entity)
setorder(wdcmReuse, -reuse)

# - collect stats
stats$totalN_entities_reused <- dim(wdcmReuse)[1]

# - store
saveRDS(wdcmReuse,
        paste0(outDir, "wd_entities_reuse.Rds"))

# - left join: wdcmReuse on itemCount
itemCount <- merge(itemCount, 
                   wdcmReuse, 
                   by = "entity", 
                   all.x = TRUE)
itemCount <- itemCount[!is.na(reuse)]

# - store
saveRDS(itemCount,
        paste0(outDir, "wd_entities_count.Rds"))
rm(itemCount); gc()

# - load fundamental data set
dataSet <- readRDS(paste0(outDir, "wd_entities_languages.Rds"))

# - left join: wdcmReuse on dataSet
setkey(dataSet, entity)
dataSet <- merge(dataSet,
                 wdcmReuse,
                 by = "entity",
                 all.x = TRUE)
# - clear
rm(wdcmReuse); gc()

# - compute re-use per language
countUsedItems <- dataSet[!is.na(reuse), .N, by = "language"]
colnames(countUsedItems)[2] <- 'num_items_reused'
dataSet[is.na(reuse), reuse := 0]
dataSet <- dplyr::select(dataSet, -entity)
dataSet <- dataSet[, .(reuse = sum(reuse), item_count = .N), by = "language"]
dataSet <- merge(dataSet,
                 countUsedItems,
                 by = "language",
                 all.x = TRUE)

# - store
write.csv(dataSet,
          paste0(outDir, "wd_languages_count.csv"))
rm(dataSet); gc()


### ---------------------------------------------------
### --- 3. The Co-Occurence and Similarity Matrices
### --- from the Fundamental Dataset
### ---------------------------------------------------
rm(list = setdiff(ls(), c('params', 'fPath')))

library(XML)
library(data.table)
library(stringr)
library(spam)
library(spam64)
library(text2vec)
library(WikidataR)
library(httr)
library(jsonlite)
library(dplyr)
library(htmltab)
library(tidyr)
library(Rtsne)
library(ggplot2)
library(ggrepel)
library(scales)
library(igraph)

### --- Directories
dataDir <- params$general$dataDir
logDir <- params$general$logDir
outDir <- params$general$outDir
publicDir <- params$general$publicDir
hdfsPath <- params$general$hdfsPath
### --- spark2-submit parameters:
sparkMaster <- params$spark$master
sparkDeployMode <- params$spark$deploy_mode
sparkNumExecutors <- params$spark$num_executors
sparkDriverMemory <- params$spark$driver_memory
sparkExecutorMemory <- params$spark$executor_memory
sparkExecutorCores <- params$spark$executor_cores
# - ML parameters
tsne_theta <- as.numeric(params$general$tSNE_Theta)
# - Set proxy
Sys.setenv(
  http_proxy = params$general$http_proxy,
  https_proxy = params$general$http_proxy)

### --- Functions
source(paste0(fPath, 'WD_LanguagesLandscape_Functions.R'))

# - load fundamental data set
dataSet <- readRDS(paste0(outDir, "wd_entities_languages.Rds"))
# - load wd_languages_count.csv
langCount <- fread(paste0(outDir, "wd_languages_count.csv"), 
                   header = T)
langCount$V1 <- NULL

### --- Compute co-occurences: labels across items
t1 <- Sys.time()
# - unique languages, unique entities
l <- unique(dataSet$language)
it <- unique(dataSet$entity)
# - language x language matrix
lang <- matrix(0, 
               nrow = length(l),
               ncol = length(l))
rownames(lang) <- l
colnames(lang) <- l
# - entity batches
it <- data.frame(item = it,
                 stringsAsFactors = F)
it$rand <- runif(dim(it)[1], 0, 1)
it <- dplyr::arrange(it, rand)
it <- it$item
nBatches <- 10
batchSize <- round(length(it)/nBatches)
startIx <- numeric(nBatches)
stopIx <- numeric(nBatches)
for (i in 1:nBatches) {
  startIx[i] <- i * batchSize - batchSize + 1
  stopIx[i] <- i * batchSize
  if (stopIx[i] > length(it)) {
    stopIx[i] <- length(it)
  }
}
# - batch processing
for (i in 1:length(startIx)) {
  tb1 <- Sys.time()
  print(paste0("Processing now contingency batch: ", i, " out of: ", nBatches, "."))
  print(paste0("Slice now contingency batch: ", i, " out of: ", nBatches, "."))
  batchData <- dataSet[dataSet$entity %in% it[startIx[i]:stopIx[i]], ]
  print(paste0("xtabs now for contingency batch: ", i, " out of: ", nBatches, "."))
  cT <- xtabs(~ language + entity,
              data = batchData, 
              sparse = T)
  rm(batchData)
  print(paste0("co-occurences now for contingency batch: ", i, " out of: ", nBatches, "."))
  co_occur <- crossprod.spam(t(cT), y = NULL)
  rm(cT)
  co_occur <- as.matrix(co_occur)
  diag(co_occur) <- 0
  print(paste0("enter now contingency batch: ", i, " out of: ", nBatches, "."))
  w1 <- which(rownames(lang) %in% rownames(co_occur))
  w2 <- which(colnames(lang) %in% colnames(co_occur))
  lang[w1, w2] <- lang[w1, w2] + co_occur
  rm(co_occur)
  print(paste0("Contingency table batch ", i, ". done in: ", 
               difftime(Sys.time(), tb1, units = "mins")))
}
# - report
print(paste0("Co-occurence matrix DONE in: ", 
             difftime(Sys.time(), t1, units = "mins")))
# - join langCount to co-occurences
lang <- as.data.frame(lang)
lang$language <- rownames(lang)
lang <- dplyr::left_join(lang, 
                         langCount,
                         by = "language")
# - store language co-occurences
write.csv(lang, 
          paste0(outDir, "WD_Languages_Co-Occurrence.csv"))

### --- compute similarity and distance matrix from co-occurrences
langMat <- as.matrix(lang[, 1:(dim(lang)[1])])
rownames(langMat) <- colnames(langMat)
# - cosine similarity:
cosineSimMatrix = sim2(langMat, method = "cosine", norm = "l2")
cosineSimMatrix_Frame <- as.data.frame(cosineSimMatrix)
cosineSimMatrix_Frame$language <- rownames(cosineSimMatrix_Frame)
cosineSimMatrix_Frame <- dplyr::left_join(cosineSimMatrix_Frame,
                                          langCount,
                                          by = "language")
# - store language cosine similarity matrix
write.csv(cosineSimMatrix_Frame, 
          paste0(outDir, "WD_Languages_CosineSimilarity.csv"))
# - cosine distance:
cosineDistMatrix <- 1 - cosineSimMatrix
diag(cosineDistMatrix) <- 0
cosineDistMatrix_Frame <- as.data.frame(cosineDistMatrix)
cosineDistMatrix_Frame$language <- rownames(cosineDistMatrix_Frame)
cosineDistMatrix_Frame <- dplyr::left_join(cosineDistMatrix_Frame,
                                           langCount,
                                           by = "language")
# - store language cosine distance matrix
write.csv(cosineDistMatrix_Frame, 
          paste0(outDir, "WD_Languages_CosineDistance.csv"))

# - tSNE 2D map from cosineDistMatrix_Frame
cosineDistMatrix_Frame <- 
  as.matrix(cosineDistMatrix_Frame[, 1:(dim(cosineDistMatrix_Frame)[1])])
tsne2DMap <- Rtsne(cosineDistMatrix_Frame,
                   theta = 0,
                   is_distance = T,
                   tsne_perplexity = 10)
tsne2DMap <- as.data.frame(tsne2DMap$Y)
colnames(tsne2DMap) <- paste("D", seq(1:dim(tsne2DMap)[2]), sep = "")
tsne2DMap$language <- colnames(cosineDistMatrix_Frame)
tsne2DMap <- dplyr::left_join(tsne2DMap, 
                              langCount, 
                              by = 'language')
# - store tsne2DMap from Jaccard distance matrix
write.csv(tsne2DMap, 
          paste0(outDir, "WD_tsne2DMap_from_cosineDistMatrix.csv"))

# - clean-up:
rm(cosineSimMatrix); rm(cosineDistMatrix); 
rm(cosineSimMatrix_Frame); rm(cosineDistMatrix_Frame); 
rm(lang); rm(langMat); gc()

### --- compute binary co-occurrences for the Jaccard Similarity Matrix: 
### --- languages x items
t1 <- Sys.time()
w1 <- match(dataSet$language, l)
w2 <- match(dataSet$entity, it)
cT <- Matrix::sparseMatrix(i = w1, j = w2, x = 1,
                           dims = c(length(l), length(it)),
                           dimnames = list(l, it)
                           )
print(paste0("Binary contingency in: ", 
             difftime(Sys.time(), t1, units = "mins"))
)
# - clean-up dataSet
rm(dataSet); gc()
# - compute Jaccard Similarity Matrix
distMatrix <- sim2(x = cT, y = NULL, 
                   method = "jaccard", 
                   norm = "none")
print(paste0("Jaccard Similarity Matrix in: ", 
             difftime(Sys.time(), t1, units = "mins"))
)
# - clear
rm(cT); gc()
# - store language Jaccard similarity matrix
distMatrix <- as.matrix(distMatrix)
distMatrix <- as.data.frame(distMatrix)
distMatrix$language <- rownames(distMatrix)
distMatrix <- dplyr::left_join(distMatrix,
                               langCount,
                               by = "language")
write.csv(distMatrix, 
          paste0(outDir, "WD_Languages_Jaccard_Similarity.csv"))
# - Jaccard similarity index to Jaccard distance
distMatrix <- as.matrix(1 - distMatrix[, 1:(dim(distMatrix)[1])])
distMatrix <- as.data.frame(distMatrix)
distMatrix$language <- rownames(distMatrix)
distMatrix <- dplyr::left_join(distMatrix,
                               langCount,
                               by = "language")
# - store language Jaccard distance matrix
write.csv(distMatrix, 
          paste0(outDir, "WD_Languages_Jaccard_Distance.csv"))
# - report
print(paste0("Jaccard matrices DONE in: ", 
             difftime(Sys.time(), t1, units = "mins")))

### --- tSNE 2d: distMatrix from Jaccard distances
distMatrix <- as.matrix(distMatrix[, 1:(dim(distMatrix)[1])])
tsne2DMap <- Rtsne(distMatrix,
                   theta = 0,
                   is_distance = T,
                   tsne_perplexity = 10)
tsne2DMap <- as.data.frame(tsne2DMap$Y)
colnames(tsne2DMap) <- paste("D", seq(1:dim(tsne2DMap)[2]), sep = "")
tsne2DMap$language <- colnames(distMatrix)
tsne2DMap <- dplyr::left_join(tsne2DMap, 
                              langCount, 
                              by = 'language')
# - store tsne2DMap from Jaccard distance matrix
write.csv(tsne2DMap, 
          paste0(outDir, "WD_tsne2DMap_from_Jaccard_Distance.csv"))

### --------------------------------------------------------------
### --- 4. Wikidata Language Data Model: WDQS
### --------------------------------------------------------------

usedLanguages <- read.csv(paste0(outDir, "wd_languages_count.csv"),
                          header = T, 
                          check.names = F,
                          row.names = 1,
                          stringsAsFactors = F)

### --- define data model for languages: essential properties
dmodelProperties <- c('P31', 'P279', 'P361', 'P17', 
                      'P4132', 'P2989', 'P3161', 'P5109', 
                      'P5110', 'P282', 'P1018', 'P1098', 
                      'P1999', 'P3823', 'P424', 'P2341', 
                      'P527', 'P218', 'P219', 'P220', 
                      'P1627', 'P3916', 'P1394', 'P2581')
dmodelPropertiesLabs <- c('imnstanceOf', 'subclassOf', 'partOf', 'country', 
                          'linguisticTypology', 'hasGrammaticalCase', 'hasGrammaticalMood', 'hasGrammaticalGender', 
                          'hasGrammaticalPerson', 'writingSystem', 'languageRegulatoryBody', 'numberOfSpeakers', 
                          'UNESCOLanguageStatus', 'EthnologueLanguageStatus', 'WikimediaLanguageCode', 'indigenousTo', 
                          'hasPart', 'ISO639_1code', 'ISO639_2code', 'ISO639_3code', 
                          'EthnologueLanguageCode', 'UNESCOThesaurusID', 'GlottologCode', 'BabelNetID')
dmodelProps <- data.frame(dmodelProperties = dmodelProperties, 
                          propertyLabel = dmodelPropertiesLabs, 
                          stringsAsFactors = F)

### --- WDQS endpoint
endPointURL <- params$general$wdqs_endpoint

### --- Collect Language dataModel basics: languages + labels + WikimediaLanguage Code 
# - Construct Query: languages from Q1288568 Modern Languages class
query <- 'SELECT ?language ?languageLabel ?WikimediaLanguageCode ?desc
            WHERE {
              ?language wdt:P31/wdt:P279* wd:Q17376908 .
              OPTIONAL {?language wdt:P424 ?WikimediaLanguageCode} .
              OPTIONAL {?language rdfs:label ?desc filter (lang(?desc) = "en")} .
              SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
            }'

# - Run Query:
repeat {
  res <- tryCatch({
    GET(url = paste0(endPointURL, URLencode(query)))
  },
  error = function(condition) {
    print("Something's wrong on WDQS: wait 10 secs, try again.")
    Sys.sleep(10)
    GET(url = paste0(endPointURL, URLencode(query)))
  },
  warning = function(condition) {
    print("Something's wrong on WDQS: wait 10 secs, try again.")
    Sys.sleep(10)
    GET(url = paste0(endPointURL, URLencode(query)))
  }
  )  
  if (res$status_code == 200) {
    print("Success.")
    break
  } else {
    print("Failed; retry.")
    Sys.sleep(10)
  }
}
# - Extract result:
if (res$status_code == 200) {
  # - tryCatch rawToChar
  # - NOTE: might fail for very long vectors
  rc <- tryCatch(
    {
      rawToChar(res$content)
    },
    error = function(condition) {
      return(FALSE)
    }
  )
} else {
  # - report
  print("The response status code for the SPARQL query was not 200.")
  print("Exiting.")
}
# - Parse JSON:
if (class(rc) == "logical") {
    print("rawToChar() conversion for the SPARQL query failed. Exiting.")
} else  {
   rc <- fromJSON(rc, simplifyDataFrame = T)
}
dataModel <- data.frame(language = rc[[2]]$bindings$language$value,
                        languageLabel = rc[[2]]$bindings$languageLabel$value,
                        wikimediaCode = rc[[2]]$bindings$WikimediaLanguageCode$value,
                        description = rc[[2]]$bindings$desc$value,
                        stringsAsFactors = F)
dataModel$language <- gsub("http://www.wikidata.org/entity/", "", dataModel$language)
dataModel <- dataModel[!duplicated(dataModel), ]

# - enter dataModel$wikimediaCode to usedLanguages
usedLanguages <- dplyr::left_join(usedLanguages, 
                                  dplyr::select(dataModel, 
                                                language, wikimediaCode, description),
                                  by = c("language" = "wikimediaCode"))
colnames(usedLanguages)[5] <- 'languageURI'

### --- Find duplicated languages (i.e. more than one Wikimedia language code)
# - compare the Wikimedia language codes in dataModel with the unique codes found in
# - languageUsage data.frame:
dataModel$checkWMcode <- sapply(dataModel$wikimediaCode, function(x) {
  if(!is.na(x)) {
    if (x %in% unique(usedLanguages$language)) {
      return(TRUE)
    } else {
      return(FALSE)
    }
  } else {
    return(NA)
  }
})
# - now mark duplicated languages
dataModel$duplicated <- sapply(dataModel$language, function(x) {
  if (sum(dataModel$language %in% x) > 1) {
    return(TRUE)
  } else {
    return(FALSE)
  }
})

# - remove language duplicates: where their Wikimedia language code is
# - not used:
dataModel <- dplyr::filter(dataModel,
                           !((duplicated == T) & (checkWMcode == F)))
dataModel$checkWMcode <- NULL
dataModel$duplicated <- NULL
# - check that all dataModel$language are items:
wnI <- which(!grepl("^Q", dataModel$language))
if (length(wnI) > 0) {
  dataModel <- dataModel[-wnI, ]
}

### --- dataModel labels: ID + label
dataModel$languageLabel <- paste0(dataModel$languageLabel, " (", dataModel$language, ")")

### --- Collect Language Properties w. {WikidataR}
lprops <- vector(mode = "list", length = length(dataModel$language))
startTime <- Sys.time()
for (i in 1:length(lprops)) {
  # - report
  print(paste0("Assessing: ", i, ". - ", dataModel$languageLabel[i]))
  if (i %% 100 == 0) {
    print("---------------------------------------------------------------------")
    print(paste0(
      "Processing ", i, ". out of ", length(lprops), " in: ",
      round(difftime(Sys.time(), startTime, units = "min"), 2),
      " minutes. That would be: ", round(i/length(lprops)*100, 2), "%."))
    print("---------------------------------------------------------------------")
  }
  x <- dataModel$language[i]
  gprops <- F
  repeat {
    gprops <- tryCatch({
      WikidataR::get_item(x)
      },
      error = function(condition) {
        FALSE
        },
      warning = function(condition){
        FALSE
    })
    if (class(gprops) != "logical") {
      break
    } else {
        print("--- Repeat query!")
        Sys.sleep(1)
      }
    }
  # - number of sitelinks
  numSitelinks <- length(gprops[[1]]$sitelinks)
  # - parse claims
  gprops <- gprops[[1]]$claims
  # - extract properties
  gprops <- gprops[which(names(gprops) %in% dmodelProps$dmodelProperties)]
  if (length(gprops) > 0) {
    gprops <- lapply(gprops, function(x) {x$mainsnak})
    gprops <- lapply(gprops, function(x) {flatten(x, recursive = TRUE)})
    gprops <- rbindlist(gprops, fill = T, use.names = T)
    gprops$language <- x
    gprops$languageLabel <- dataModel$languageLabel[which(dataModel$language %in% x)][1]
    if ('property' %in% colnames(gprops)) {
      gprops <- dplyr::left_join(gprops, 
                                 dmodelProps,
                                 by = c("property" = "dmodelProperties"))
       gprops$numSitelinks <- numSitelinks
       # - output data
       lprops[[i]] <- gprops
       print(paste0("Processed: ", i, ". - ", dataModel$languageLabel[i]))
    } else {
      # - output NA
      lprops[[i]] <- NA
      print(paste0("Skipped: ", dataModel$languageLabel[i]))
    }
  } else {
    print("--- Nothing to process here, skipping.")
    next
  }
}
# - complete lprops
w <- which(is.na(lprops))
if (length(w) > 0) {
  lprops[w] <- NULL 
}
lprops <- rbindlist(lprops, fill = T, use.names = T)
# - filter out P1098 (number of speakers)
w <- which(lprops$propertyLabel %in% 'numberOfSpeakers')
if (length(w) > 0) {
  lprops <- lprops[-w, ] 
}
# - write
write.csv(lprops, 
          paste0(outDir, "dataModel_Long.csv"))

# - select only essential fields
lprops <- dplyr::select(lprops, 
                        language, languageLabel, 
                        numSitelinks, snaktype, 
                        property, propertyLabel, 
                        datavalue.value, datavalue.type, 
                        `datavalue.value.entity-type`, 
                        datavalue.value.id)

# - wrangle dataModel
lprops$value <- ifelse(lprops$`datavalue.type` == "string", 
                       lprops$`datavalue.value`, 
                       lprops$`datavalue.value.id`)
lprops <- dplyr::select(lprops, 
                        language, languageLabel, 
                        numSitelinks, property, 
                        propertyLabel, value)

# - store dataModel
write.csv(lprops, 
          paste0(outDir, "dataModel_Long.csv"))

# - English labels for item values
items <- unique(lprops$value[grepl("^Q[[:digit:]]+", lprops$value)])
# - wdqs: fetch English labels
# - fetch occupation labels w. {WikidataR}
labels <- sapply(items,
                 function(x) {
                   repeat {
                     i <- tryCatch({
                       get_item(x)
                     },
                     error = function(condition) {
                       Sys.sleep(2)
                       FALSE
                     })
                     if (class(i) == "wikidata") {
                       break
                     }
                   }
                   i[[1]]$labels$en$value
                 })
labNames <- names(labels) 
labels <- as.character(labels)

# - add labels for item values to lprops
lprops$value <- sapply(lprops$value, function(x) {
  if (grepl("^Q[[:digit:]]+", x)) {
    w <- which(labNames == x)
    return(paste0(labels[w], " (", labNames[w], ")"))
  } else {
    return(x)
  }
})
  
# - add Wikimedia Language codes to lprops
lprops <- dplyr::left_join(lprops, 
                           dplyr::select(dataModel, languageLabel, wikimediaCode), 
                           by = 'languageLabel')

# - re-structure dataModel
dataModel_basic <- dplyr::select(lprops, 
                                 language, 
                                 languageLabel, 
                                 wikimediaCode,
                                 numSitelinks)
dataModel_basic <- dataModel_basic[!duplicated(dataModel_basic), ]
dataModel_properties <- dplyr::select(lprops, 
                                 language, 
                                 languageLabel, 
                                 wikimediaCode,
                                 property, propertyLabel, value)
dataModel_properties$property <- paste0(
  dataModel_properties$propertyLabel, 
  " (", 
  dataModel_properties$property, 
  ")"
)
dataModel_properties$propertyLabel <- NULL

write.csv(dataModel_basic, 
          paste0(outDir, 'dataModel_basic.csv'))
write.csv(dataModel_properties, 
          paste0(outDir, 'dataModel_properties.csv'))
write.csv(usedLanguages, 
          paste0(outDir, 'WD_Languages_UsedLanguages.csv'))

### --- add to usedLanguages:  
# - GlottologCode (P1394), EthnologueLanguageStatus (P3823)
# - EthnologueLanguageCode (P1627), ISO639_3code (P220), ISO639_2code (P219), 
# - UNESCOThesaurusID (P3916), UNESCOLanguageStatus (P1999)
# - add: EthnologueLanguageCode (P1627)
EthnologueLanguageCode <- dplyr::filter(dataModel_properties,
                                        property == 'EthnologueLanguageCode (P1627)') %>%
  dplyr::select(wikimediaCode, property, value) %>% 
  dplyr::filter(!is.na(wikimediaCode) & !is.na(value))
usedLanguages <- dplyr::left_join(usedLanguages, 
                                  dplyr::select(EthnologueLanguageCode, 
                                                wikimediaCode, value),
                                  by = c("language" = "wikimediaCode"))
colnames(usedLanguages)[7] <- 'EthnologueLanguageCode'

# - add: EthnologueLanguageStatus (P3823)
EthnologueLanguageStatus <- dplyr::filter(dataModel_properties,
                                          property == 'EthnologueLanguageStatus (P3823)') %>%
  dplyr::select(wikimediaCode, property, value) %>% 
  dplyr::filter(!is.na(wikimediaCode) & !is.na(value))
usedLanguages <- dplyr::left_join(usedLanguages, 
                                  dplyr::select(EthnologueLanguageStatus, 
                                                wikimediaCode, value),
                                  by = c("language" = "wikimediaCode"))
colnames(usedLanguages)[8] <- 'EthnologueLanguageStatus'

# - add: UNESCOLanguageStatus (P1999)
UNESCOLanguageStatus <- dplyr::filter(dataModel_properties,
                                      property == 'UNESCOLanguageStatus (P1999)') %>%
  dplyr::select(wikimediaCode, property, value) %>% 
  dplyr::filter(!is.na(wikimediaCode) & !is.na(value))
usedLanguages <- dplyr::left_join(usedLanguages, 
                                  dplyr::select(UNESCOLanguageStatus, 
                                                wikimediaCode, value),
                                  by = c("language" = "wikimediaCode"))
colnames(usedLanguages)[9] <- 'UNESCOLanguageStatus'

# - add: numSitelinks from dataModel_basic:
usedLanguages <- dplyr::left_join(usedLanguages, 
                                  dplyr::select(dataModel_basic, 
                                                language, numSitelinks),
                                  by = c("languageURI" = "language"))
write.csv(usedLanguages, 
          paste0(outDir, 'WD_Languages_UsedLanguages.csv'))

### --------------------------------------------------------------
### --- 6. Production Visualisation Data Sets
### --------------------------------------------------------------

# - visualize: UNESCOLanguageStatus (P3823) vs. numSitelinks
pFrame <- usedLanguages %>%
  dplyr::select(language, description, UNESCOLanguageStatus, numSitelinks)
pFrame <- pFrame[complete.cases(pFrame), ]
pFrame$UNESCOLanguageStatus <- gsub("\\(Q.+$", "", pFrame$UNESCOLanguageStatus)
colnames(pFrame) <- c('Language Code', 
                      'Language', 
                      'UNESCO Language Status', 
                      'Sitelinks')
write.csv(pFrame, 
          paste0(outDir, "WD_Vis_UNESCO Language Status_Sitelinks.csv"))

# - visualize: UNESCOLanguageStatus (P3823) vs. number of items (labels)
pFrame <- usedLanguages %>%
  dplyr::select(language, description, UNESCOLanguageStatus, item_count)
pFrame <- pFrame[complete.cases(pFrame), ]
pFrame$UNESCOLanguageStatus <- gsub("\\(Q.+$", "", pFrame$UNESCOLanguageStatus)
colnames(pFrame) <- c('Language Code', 
                      'Language', 
                      'UNESCO Language Status', 
                      'Labels')
write.csv(pFrame, 
          paste0(outDir, "WD_Vis_UNESCO Language Status_NumItems.csv"))

# - visualize: UNESCOLanguageStatus (P3823) vs. item reuse
pFrame <- usedLanguages %>%
  dplyr::select(language, description, UNESCOLanguageStatus, 
                reuse, num_items_reused, item_count)
pFrame <- pFrame[complete.cases(pFrame), ]
pFrame$UNESCOLanguageStatus <- gsub("\\(Q.+$", "", pFrame$UNESCOLanguageStatus)
colnames(pFrame) <- c('Language Code', 
                      'Language', 
                      'UNESCO Language Status', 
                      'Reuse', 
                      'Items Reused', 
                      'Items')
write.csv(pFrame, 
          paste0(outDir, "WD_Vis_UNESCO Language Status_ItemReuse.csv"))

# - visualize: EthnologueLanguageStatus (P3823) vs. numSitelinks
pFrame <- usedLanguages %>%
  dplyr::select(language, description, EthnologueLanguageStatus, numSitelinks)
pFrame <- pFrame[complete.cases(pFrame), ]
pFrame$EthnologueLanguageStatus <- gsub("\\(Q.+$", "", pFrame$EthnologueLanguageStatus)
colnames(pFrame) <- c('Language Code', 
                      'Language', 
                      'Ethnologue Language Status', 
                      'Sitelinks')
write.csv(pFrame, 
          paste0(outDir, "WD_Vis_EthnologueLanguageStatus_Sitelinks.csv"))

# - visualize: EthnologueLanguageStatus (P3823) vs. number of items (labels)
pFrame <- usedLanguages %>%
  dplyr::select(language, description, EthnologueLanguageStatus, item_count)
pFrame <- pFrame[complete.cases(pFrame), ]
pFrame$EthnologueLanguageStatus <- gsub("\\(Q.+$", "", pFrame$EthnologueLanguageStatus)
colnames(pFrame) <- c('Language Code', 
                      'Language', 
                      'Ethnologue Language Status', 
                      'Labels')
write.csv(pFrame, 
          paste0(outDir, "WD_Vis_EthnologueLanguageStatus_NumItems.csv"))

# - visualize: EthnologueLanguageStatus (P3823) vs. item reuse
pFrame <- usedLanguages %>%
  dplyr::select(language, description, EthnologueLanguageStatus, 
                reuse, num_items_reused, item_count)
pFrame <- pFrame[complete.cases(pFrame), ]
pFrame$EthnologueLanguageStatus <- gsub("\\(Q.+$", "", pFrame$EthnologueLanguageStatus)
colnames(pFrame) <- c('Language Code', 
                      'Language', 
                      'Ethnologue Language Status', 
                      'Reuse', 
                      'Items Reused', 
                      'Items')
write.csv(pFrame, 
          paste0(outDir, "WD_Vis_EthnologueLanguageStatus_ItemReuse.csv"))

### --- wd_Superclasses_Recurrently() for Ontology Structure
entity <- unique(usedLanguages$languageURI)
myWD <- wd_Superclasses_Recurrently(entity = entity, 
                                    language = 'en', 
                                    cleanup = T,
                                    fetchSubClasses = F,
                                    fetchCounts = F,
                                    SPARQL_Endpoint = 'https://query.wikidata.org/bigdata/namespace/wdq/sparql?query=')
saveRDS(myWD, 
        paste0(outDir, 'myWD.Rds'))
# - prepate dataSet for dashboard visualization
dC <- myWD$structure
dC <- dplyr::filter(dC,
                    ((item %in% entity) | (grepl("lang|ling", dC$itemLabel))) & 
                      ((superClass %in% entity) | (grepl("lang|ling", dC$superClassLabel))))
write.csv(dC, 
          paste0(outDir, 'WD_Languages_OntologyStructure.csv'))


### --------------------------------------------------------------
### --- 7. Copy data to publicDir
### --------------------------------------------------------------
publicDir <- params$general$pubDataDir

write(paste0("Last updated on: ", Sys.time()), 
      paste0(outDir, "WDLanguagesUpdateString.txt"))

cFiles <- c('WD_Languages_OntologyStructure.csv',
            'WD_Languages_UsedLanguages.csv',
            'WD_Languages_Jaccard_Similarity.csv',
            'WD_Vis_UNESCO\\ Language\\ Status_Sitelinks.csv',
            'WD_Vis_EthnologueLanguageStatus_Sitelinks.csv',
            'WD_Vis_UNESCO\\ Language\\ Status_NumItems.csv',
            'WD_Vis_EthnologueLanguageStatus_NumItems.csv',
            'WD_Vis_UNESCO\\ Language\\ Status_ItemReuse.csv',
            'WD_Vis_EthnologueLanguageStatus_ItemReuse.csv',
            'wd_languages_count.csv', 
            'WDLanguagesUpdateString.txt')
for (i in 1:length(cFiles)) {
  print(paste0('Copying: ', cFiles[i], ' to publicDir.'))
  system(command = 
           paste0('cp ', outDir, cFiles[i], ' ', publicDir),
         wait = T)
}



