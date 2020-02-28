
### ---------------------------------------------------------------------------
### --- wd_LanguagesLandscape.py
### --- Author: Goran S. Milovanovic, Data Scientist, WMDE
### --- Developed under the contract between Goran Milovanovic PR Data Kolektiv
### --- and WMDE.
### --- Contact: goran.milovanovic_ext@wikimedia.de
### --- February 2020.
### ---------------------------------------------------------------------------
### --- COMMENT:
### --- Pyspark ETL procedures to process the WD JSON dumps in hdfs
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
### --- Script: WD_LanguagesLandscape.py
### ---------------------------------------------------------------------------
### --- DESCRIPTION:
### --- WD_LanguagesLandscape.py performs ETL procedures
### --- over the Wikidata JSON dumps in hdfs.
### ---------------------------------------------------------------------------


### --- Modules
import pyspark
from pyspark.sql import SparkSession, DataFrame
from pyspark.sql.functions import rank, col, explode, regexp_extract
import csv

### --- Init Spark

# - Spark Session
sc = SparkSession\
    .builder\
    .appName("wd_processDump_Spark")\
    .enableHiveSupport()\
    .getOrCreate()
# - dump file: /user/joal/wmf/data/wmf/mediawiki/wikidata_parquet/20191202
# - hdfs path
hdfsPath = "hdfs:///tmp/wmde/analytics/Wikidata/LanguagesLandscape/"

# - SQL Context
sqlContext = pyspark.SQLContext(sc)

### ------------------------------------------------------------------------
### --- Extract all entities w. labels
### ------------------------------------------------------------------------

### --- Access WD dump
WD_dump = sqlContext.read.parquet('/user/joal/wmf/data/wmf/mediawiki/wikidata_parquet/20191202')

### --- Cache WD dump
WD_dump.cache()

### --- Explode labels & select
WD_dump = WD_dump.select('id', 'labels')
WD_dump = WD_dump.select('id', explode('labels').alias("language", "label"))
WD_dump = WD_dump.select('id', 'language')

# - repartition
WD_dump = WD_dump.orderBy(["id"])
WD_dump = WD_dump.repartition(30)

# - save to csv:
WD_dump.write.format('csv').mode("overwrite").save(hdfsPath + 'wd_dump_item_language')

### ------------------------------------------------------------------------
### --- Extract per entity re-use data
### ------------------------------------------------------------------------

# - from wdcm_clients_wb_entity_usage
WD_reuse = sqlContext.sql('SELECT eu_entity_id, COUNT(*) AS eu_count FROM \
                            (SELECT DISTINCT eu_entity_id, eu_page_id, wiki_db \
                                FROM goransm.wdcm_clients_wb_entity_usage) \
                                AS t GROUP BY eu_entity_id')

# - cache WD_reuse
WD_reuse.cache()
# - repartition
WD_reuse = WD_reuse.orderBy(["eu_entity_id"])
WD_reuse = WD_reuse.repartition(10)

# - save to csv:
WD_reuse.write.format('csv').mode("overwrite").save(hdfsPath + 'wd_entity_reuse')

# - clear
sc.catalog.clearCache()





