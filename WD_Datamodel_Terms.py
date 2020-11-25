
### ---------------------------------------------------------------------------
### --- wd_DatamodelTerms.py
### --- Author: Goran S. Milovanovic, Data Scientist, WMDE
### --- Developed under the contract between Goran Milovanovic PR Data Kolektiv
### --- and WMDE.
### --- Contact: goran.milovanovic_ext@wikimedia.de
### --- August 2020.
### ---------------------------------------------------------------------------
### --- COMMENT:
### --- Pyspark ETL procedures to process the WD JSON dumps in hdfs:
### --- extract Terms Model (labels, aliases, descriptions)
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

### --- Modules
import pyspark
from pyspark.sql import SparkSession, DataFrame
from pyspark.sql.functions import rank, col, explode, regexp_extract, lit
import csv
import xml.etree.ElementTree as ET
import pandas as pd

# - Spark Session
sc = SparkSession\
    .builder\
    .appName("wd_processDump_Spark")\
    .enableHiveSupport()\
    .getOrCreate()

# - Spark Session Log Level: INFO
sc.sparkContext.setLogLevel("INFO")

# - SQL Context
sqlContext = pyspark.SQLContext(sc)

### --- parse WDCM parameters
parsFile = "/home/goransm/Analytics/Wikidata/WD_languagesLandscape/WD_LanguagesLandscape_Config.xml"
# - parse wdcmConfig.xml
tree = ET.parse(parsFile)
root = tree.getroot()
k = [elem.tag for elem in root.iter()]
v = [x.text for x in root.iter()]
params = dict(zip(k, v))
# - local path
localPath = params['datamodel_terms_dataDir']

# - get wmf.wikidata_entity snapshot
snaps = sqlContext.sql('SHOW PARTITIONS wmf.wikidata_entity')
snaps = snaps.toPandas()
wikidataEntitySnapshot = snaps.tail(1)['partition'].to_string()
wikidataEntitySnapshot = wikidataEntitySnapshot[-10:]

### ---------------------------------------------------
### --- EVERYTHING
### ---------------------------------------------------

### --- Access WD dump: LABELS
WD_dump = sqlContext.sql('SELECT id, labels FROM wmf.wikidata_entity WHERE snapshot="' + wikidataEntitySnapshot + '"')
### --- Cache WD dump
WD_dump.cache()
# - count Wikidata items
num_items_general = WD_dump.count()
### --- Explode labels & select
WD_dump = WD_dump.select('id', explode('labels').alias("language", "label")).select('language')
WD_dump = WD_dump.groupBy('language').count().orderBy('count', ascending = False)
WD_dump = WD_dump.withColumn("snapshot", lit(wikidataEntitySnapshot))
WD_dump = WD_dump.withColumn("numitems", lit(num_items_general))
WD_dump.toPandas().to_csv(localPath + 'update_Labels.csv', header = True, index = False)

### --- Access WD dump: ALIASES
WD_dump = sqlContext.sql('SELECT id, aliases FROM wmf.wikidata_entity WHERE snapshot="' + wikidataEntitySnapshot + '"')
### --- Cache WD dump
WD_dump.cache()
### --- Explode aliases & select
WD_dump = WD_dump.select('id', explode('aliases').alias("alias", "value")).select('alias', explode("value")).select('alias')
WD_dump = WD_dump.groupBy('alias').count().orderBy('count', ascending = False)
WD_dump = WD_dump.withColumn("snapshot", lit(wikidataEntitySnapshot))
WD_dump = WD_dump.withColumn("numitems", lit(num_items_general))
WD_dump.toPandas().to_csv(localPath + 'update_Aliases.csv', header = True, index = False)

### --- Access WD dump: DESCRIPTIONS
WD_dump = sqlContext.sql('SELECT id, descriptions FROM wmf.wikidata_entity WHERE snapshot="' + wikidataEntitySnapshot + '"')
### --- Cache WD dump
WD_dump.cache()
### --- Explode descriptions & select
WD_dump = WD_dump.select('id', explode('descriptions').alias("description", "value")).select('description')
WD_dump = WD_dump.groupBy('description').count().orderBy('count', ascending = False)
WD_dump = WD_dump.withColumn("snapshot", lit(wikidataEntitySnapshot))
WD_dump = WD_dump.withColumn("numitems", lit(num_items_general))
WD_dump.toPandas().to_csv(localPath + 'update_Descriptions.csv', header = True, index = False)

### ---------------------------------------------------
### --- ASTRONOMICAL OBJECTS ONLY
### ---------------------------------------------------

# - read what is found in subclasses
itemFile = 'hdfs:///tmp/wmde/analytics/Wikidata/LanguagesLandscape/DataModelTermsCollectedItemsDir/collectedAstronomy.csv'
items = sqlContext.read.csv(itemFile, header=True)
items = items.select('id')
# - find what is an ASTRONOMICAL OBJECT by P31
# - initiate dump for items
WD_items = sqlContext.sql('SELECT id, claims FROM wmf.wikidata_entity WHERE snapshot="' + wikidataEntitySnapshot + '"')
# - Cache WD dump for items
WD_items.cache()
# - explode properties
WD_items = WD_items.select('id', explode('claims').alias('claims')).select('id', 'claims.mainSnak')
WD_items = WD_items.select('id', 'mainSnak.property', 'mainSnak.dataValue.value')
WD_items = WD_items.filter(WD_items.property == 'P31').select('id', regexp_extract(col('value'), '(Q\d+)', 1).alias('value'))
WD_items = WD_items.filter(WD_items.value == "Q6999").select('id')
# - bind with what is found in subclasses
WD_items = WD_items.unionByName(items)
# - count Wikidata items: ASTRONOMICAL OBJECT
num_items = WD_items.count()

# - LABELS
# - initiate dump for labels
WD_dump = sqlContext.sql('SELECT id, labels FROM wmf.wikidata_entity WHERE snapshot="' + wikidataEntitySnapshot + '"')
# - Cache WD dump for labels
WD_dump.cache()
WD_dump = WD_dump.select('id', explode('labels').alias("language", "label")).select('id', 'language')
# - left_join for astronomy:
WD_labels = WD_items.join(WD_dump, ["id"], how='left').select('language')
WD_labels = WD_labels.groupBy('language').count().orderBy('count', ascending = False)
WD_labels = WD_labels.withColumn("snapshot", lit(wikidataEntitySnapshot))
WD_labels = WD_labels.withColumn("numitems", lit(num_items))
# - store
WD_labels.toPandas().to_csv(localPath + 'update_Labels_ASTRONOMY.csv', header = True, index = False)

# - ALIASES
# - initiate dump for labels
WD_dump = sqlContext.sql('SELECT id, aliases FROM wmf.wikidata_entity WHERE snapshot="' + wikidataEntitySnapshot + '"')
# - Cache WD dump for labels
WD_dump.cache()
WD_dump = WD_dump.select('id', explode('aliases').alias("alias", "value")).select('id', 'alias', explode("value")).select('id', 'alias')
# - left_join for astronomy:
WD_aliases = WD_items.join(WD_dump, ["id"], how='left').select('alias')
WD_aliases = WD_aliases.groupBy('alias').count().orderBy('count', ascending = False)
WD_aliases = WD_aliases.withColumn("snapshot", lit(wikidataEntitySnapshot))
WD_aliases = WD_aliases.withColumn("numitems", lit(num_items))
# - store
WD_aliases.toPandas().to_csv(localPath + 'update_Aliases_ASTRONOMY.csv', header = True, index = False)

# - DESCRIPTIONS
# - initiate dump for labels
WD_dump = sqlContext.sql('SELECT id, descriptions FROM wmf.wikidata_entity WHERE snapshot="' + wikidataEntitySnapshot + '"')
# - Cache WD dump for labels
WD_dump.cache()
WD_dump = WD_dump.select('id', explode('descriptions').alias("description", "value")).select('id', 'description')
# - left_join for astronomy:
WD_descriptions = WD_items.join(WD_dump, ["id"], how='left').select('description')
WD_descriptions = WD_descriptions.groupBy('description').count().orderBy('count', ascending = False)
WD_descriptions = WD_descriptions.withColumn("snapshot", lit(wikidataEntitySnapshot))
WD_descriptions = WD_descriptions.withColumn("numitems", lit(num_items))
# - store
WD_descriptions.toPandas().to_csv(localPath + 'update_Descriptions_ASTRONOMY.csv', header = True, index = False)

### ---------------------------------------------------
### --- SCIENTIFIC PAPERS ONLY
### ---------------------------------------------------

# - read what is found in subclasses
itemFile = 'hdfs:///tmp/wmde/analytics/Wikidata/LanguagesLandscape/DataModelTermsCollectedItemsDir/collectedScientificPapers.csv'
items = sqlContext.read.csv(itemFile, header=True)
items = items.select('id')
# - find what is an SCIENTIFIC PAPER by P31
# - initiate dump for items
WD_items2 = sqlContext.sql('SELECT id, claims FROM wmf.wikidata_entity WHERE snapshot="' + wikidataEntitySnapshot + '"')
# - Cache WD dump for items
WD_items2.cache()
# - explode properties
WD_items2 = WD_items2.select('id', explode('claims').alias('claims')).select('id', 'claims.mainSnak')
WD_items2 = WD_items2.select('id', 'mainSnak.property', 'mainSnak.dataValue.value')
WD_items2 = WD_items2.filter(WD_items2.property == 'P31').select('id', regexp_extract(col('value'), '(Q\d+)', 1).alias('value'))
WD_items2 = WD_items2.filter(WD_items2.value == "Q13442814").select('id')
# - bind with what is found in subclasses
WD_items2 = WD_items2.unionByName(items)
# - count Wikidata items: SCIENTIFIC PAPER
num_items = WD_items2.count()

# - LABELS
# - initiate dump for labels
WD_dump = sqlContext.sql('SELECT id, labels FROM wmf.wikidata_entity WHERE snapshot="' + wikidataEntitySnapshot + '"')
# - Cache WD dump for labels
WD_dump.cache()
WD_dump = WD_dump.select('id', explode('labels').alias("language", "label")).select('id', 'language')
# - left_join for astronomy:
WD_labels = WD_items2.join(WD_dump, ["id"], how='left').select('language')
WD_labels = WD_labels.groupBy('language').count().orderBy('count', ascending = False)
WD_labels = WD_labels.withColumn("snapshot", lit(wikidataEntitySnapshot))
WD_labels = WD_labels.withColumn("numitems", lit(num_items))
# - store
WD_labels.toPandas().to_csv(localPath + 'update_Labels_SCIENTIFICPAPERS.csv', header = True, index = False)

# - ALIASES
# - initiate dump for labels
WD_dump = sqlContext.sql('SELECT id, aliases FROM wmf.wikidata_entity WHERE snapshot="' + wikidataEntitySnapshot + '"')
# - Cache WD dump for labels
WD_dump.cache()
WD_dump = WD_dump.select('id', explode('aliases').alias("alias", "value")).select('id', 'alias', explode("value")).select('id', 'alias')
# - left_join for astronomy:
WD_aliases = WD_items2.join(WD_dump, ["id"], how='left').select('alias')
WD_aliases = WD_aliases.groupBy('alias').count().orderBy('count', ascending = False)
WD_aliases = WD_aliases.withColumn("snapshot", lit(wikidataEntitySnapshot))
WD_aliases = WD_aliases.withColumn("numitems", lit(num_items))
# - store
WD_aliases.toPandas().to_csv(localPath + 'update_Aliases_SCIENTIFICPAPERS.csv', header = True, index = False)

# - DESCRIPTIONS
# - initiate dump for labels
WD_dump = sqlContext.sql('SELECT id, descriptions FROM wmf.wikidata_entity WHERE snapshot="' + wikidataEntitySnapshot + '"')
# - Cache WD dump for labels
WD_dump.cache()
WD_dump = WD_dump.select('id', explode('descriptions').alias("description", "value")).select('id', 'description')
# - left_join for astronomy:
WD_descriptions = WD_items2.join(WD_dump, ["id"], how='left').select('description')
WD_descriptions = WD_descriptions.groupBy('description').count().orderBy('count', ascending = False)
WD_descriptions = WD_descriptions.withColumn("snapshot", lit(wikidataEntitySnapshot))
WD_descriptions = WD_descriptions.withColumn("numitems", lit(num_items))
# - store
WD_descriptions.toPandas().to_csv(localPath + 'update_Descriptions_SCIENTIFICPAPERS.csv', header = True, index = False)

### -------------------------------------------------------------------
### --- EVERYTHING MINUS (SCIENTIFIC PAPERS + ASTRONOMICAL OBJECTS)
### -------------------------------------------------------------------

# - bind SCIENTIFIC PAPERS + ASTRONOMICAL OBJECTS
WD_items = WD_items.unionByName(WD_items2)
# - count Wikidata items: EVERYTHING MINUS (ASTRONOMICAL OBJECT + SCIENTIFIC PAPER)
num_items = WD_items.count()
num_items = num_items_general - num_items

# - LABELS
# - initiate dump for labels
WD_dump = sqlContext.sql('SELECT id, labels FROM wmf.wikidata_entity WHERE snapshot="' + wikidataEntitySnapshot + '"')
# - Cache WD dump for labels
WD_dump.cache()
WD_dump = WD_dump.select('id', explode('labels').alias("language", "label")).select('id', 'language')
# - left_anti_join:
WD_labels  = WD_dump.join(WD_items, on=['id'], how='left_anti').select('language')
WD_labels = WD_labels.groupBy('language').count().orderBy('count', ascending = False)
WD_labels = WD_labels.withColumn("snapshot", lit(wikidataEntitySnapshot))
WD_labels = WD_labels.withColumn("numitems", lit(num_items))
# - store
WD_labels.toPandas().to_csv(localPath + 'update_Labels_EVERYTHINGMINUS.csv', header = True, index = False)

# - ALIASES
# - initiate dump for labels
WD_dump = sqlContext.sql('SELECT id, aliases FROM wmf.wikidata_entity WHERE snapshot="' + wikidataEntitySnapshot + '"')
# - Cache WD dump for labels
WD_dump.cache()
WD_dump = WD_dump.select('id', explode('aliases').alias("alias", "value")).select('id', 'alias', explode("value")).select('id', 'alias')
# - left_anti_join:
WD_aliases  = WD_dump.join(WD_items, on=['id'], how='left_anti').select('alias')
WD_aliases = WD_aliases.groupBy('alias').count().orderBy('count', ascending = False)
WD_aliases = WD_aliases.withColumn("snapshot", lit(wikidataEntitySnapshot))
WD_aliases = WD_aliases.withColumn("numitems", lit(num_items))
# - store
WD_aliases.toPandas().to_csv(localPath + 'update_Aliases_EVERYTHINGMINUS.csv', header = True, index = False)

# - DESCRIPTIONS
# - initiate dump for labels
WD_dump = sqlContext.sql('SELECT id, descriptions FROM wmf.wikidata_entity WHERE snapshot="' + wikidataEntitySnapshot + '"')
# - Cache WD dump for labels
WD_dump.cache()
WD_dump = WD_dump.select('id', explode('descriptions').alias("description", "value")).select('id', 'description')
# - left_anti_join:
WD_descriptions = WD_dump.join(WD_items, ["id"], how='left_anti').select('description')
WD_descriptions = WD_descriptions.groupBy('description').count().orderBy('count', ascending = False)
WD_descriptions = WD_descriptions.withColumn("snapshot", lit(wikidataEntitySnapshot))
WD_descriptions = WD_descriptions.withColumn("numitems", lit(num_items))
# - store
WD_descriptions.toPandas().to_csv(localPath + 'update_Descriptions_EVERYTHINGMINUS.csv', header = True, index = False)
    

