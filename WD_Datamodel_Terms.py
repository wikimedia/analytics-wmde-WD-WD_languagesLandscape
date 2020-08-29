
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
from pyspark.sql.functions import rank, col, explode, regexp_extract
import csv
import xml.etree.ElementTree as ET
import pandas as pd

# - Spark Session
sc = SparkSession\
    .builder\
    .appName("wd_processDump_Spark")\
    .enableHiveSupport()\
    .getOrCreate()
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

### --- Access WD dump: LABELS
WD_dump = sqlContext.sql('SELECT id, labels FROM wmf.wikidata_entity WHERE snapshot="' + wikidataEntitySnapshot + '"')
### --- Cache WD dump
WD_dump.cache()
# - count Wikidata items
num_items = WD_dump.count()
n_items = pd.DataFrame([num_items], dtype=int) 
n_items.to_csv(localPath + 'num_items.csv', header = True, index = False)
### --- Explode labels & select
WD_dump = WD_dump.select('id', explode('labels').alias("language", "label")).select('language')
WD_dump = WD_dump.groupBy('language').count().orderBy('count', ascending = False)
WD_dump.toPandas().to_csv(localPath + 'update_Labels.csv', header = True, index = False)

### --- Access WD dump: ALIASES
WD_dump = sqlContext.sql('SELECT id, aliases FROM wmf.wikidata_entity WHERE snapshot="' + wikidataEntitySnapshot + '"')
### --- Cache WD dump
WD_dump.cache()
### --- Explode aliases & select
WD_dump = WD_dump.select('id', explode('aliases').alias("alias", "value")).select('alias', explode("value")).select('alias')
WD_dump = WD_dump.groupBy('alias').count().orderBy('count', ascending = False)
WD_dump.toPandas().to_csv(localPath + 'update_Aliases.csv', header = True, index = False)

### --- Access WD dump: DESCRIPTIONS
WD_dump = sqlContext.sql('SELECT id, descriptions FROM wmf.wikidata_entity WHERE snapshot="' + wikidataEntitySnapshot + '"')
### --- Cache WD dump
WD_dump.cache()
### --- Explode descriptions & select
WD_dump = WD_dump.select('id', explode('descriptions').alias("description", "value")).select('description')
WD_dump = WD_dump.groupBy('description').count().orderBy('count', ascending = False)
WD_dump.toPandas().to_csv(localPath + 'update_Descriptions.csv', header = True, index = False)



