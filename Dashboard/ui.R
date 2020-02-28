### ---------------------------------------------------------------------------
### --- WD Languages Landscape
### --- Languages Structure Dashboard
### --- Script: ui.R, v. Beta 0.1
### ---------------------------------------------------------------------------

### --- general
library(shiny)
library(shinydashboard)
library(shinycssloaders)
### --- outputs
library(DT)
library(visNetwork)
library(plotly)

# - options
options(warn = -1)

shinyUI(
  
  ### --- dashboardPage
  ### --------------------------------
  
  dashboardPage(skin = "black",
                
                ### --- dashboarHeader
                ### --------------------------------
                
                dashboardHeader(
                  # - Title
                  title = "WD Languages Landscape",
                  titleWidth = 300
                ), 
                ### ---- END dashboardHeader
                
                ### --- dashboardSidebar
                ### --------------------------------
                
                dashboardSidebar(
                  sidebarMenu(
                    id = "tabsWDCM",
                    menuItem(text = "Ontology", 
                             tabName = "ontology", 
                             icon = icon("barcode"),
                             selected = TRUE
                             
                    ),
                    menuItem(text = "Language/Class", 
                             tabName = "languageclass", 
                             icon = icon("barcode"),
                             selected = FALSE
                             
                    ),
                    menuItem(text = "Label Sharing", 
                             tabName = "similarity", 
                             icon = icon("barcode"),
                             selected = FALSE
                    ),
                    menuItem(text = "Language Status", 
                             tabName = "status", 
                             icon = icon("barcode"),
                             selected = FALSE
                    ),
                    menuItem(text = "Language Usage", 
                             tabName = "usage", 
                             icon = icon("barcode"),
                             selected = FALSE
                    ),
                    menuItem(text = "Description", 
                             tabName = "description", 
                             icon = icon("barcode"),
                             selected = FALSE
                    )
                  )
                ),
                ### --- END dashboardSidebar
                
                ### --- dashboardBody
                ### --------------------------------
                
                dashboardBody(
                  
                  # - style
                  tags$head(tags$style(HTML('.content-wrapper, .right-side {
                                            background-color: #ffffff;
                                            }'))),
                  tags$style(type="text/css",
                             ".shiny-output-error { visibility: hidden; }",
                             ".shiny-output-error:before { visibility: hidden; }"
                  ),
                  
                  tabItems(
                    
                    ### --- TAB: Ontology
                    ### --------------------------------
                    
                    tabItem(tabName = "ontology",
                            fluidRow(
                              column(width = 9,
                                     fluidRow(
                                       column(width = 12,
                                              br(),
                                              HTML('<p style="font-size:80%;"align="left"><b>ONTOLOGY.</b>
                                                   All nodes in this graph represent either a particular Wikidata language item or a Wikidata class that encompasses 
                                                   different languages in the ontology. The relations between languages and language classes in Wikidata are organized 
                                                   through different properties: <b><a href="https://www.wikidata.org/wiki/Property:P31" target="blank">P31 (instance of)</a></b>, 
                                                   <b><a href="https://www.wikidata.org/wiki/Property:P279" target="blank">P279 (subclass of)</a></b>, and 
                                                   <b><a href="https://www.wikidata.org/wiki/Property:P361" target="blank">P361 (part of)</a></b>. The relational structure of 
                                                   languages in the ontology is not always systematic (e.g. sometimes a language is both a <b>P279 (subclass of)</b> and a 
                                                   <b>P361 (part of)</b> of a language class or another language). The <b><i>Language/Class</i></b> tab in this Dashboard can help you 
                                                   inspect these relationships closer and decide if a change in the ontology needs to be introduced.<br>
                                                   Use the toolbox in the top-right corner of the graph to zoom or pan the graph. Hovering over a particular node will 
                                                   reveal the details: the respective Wikidata item alongside the number of relations (<b>P31</b>/<b>P27</b>/<b>P361</b>) 
                                                   that it enters in the graph. If a node represents a particular language additional information will be displayed: the number of 
                                                   labels for that language in Wikidata, the percent of the items that have a label in that language and are also reused across the Wikies, 
                                                   the WDCM (<a href = "http://wmdeanalytics.wmflabs.org/" target="_blank">Wikidata Concepts Monitor</a>) reuse statistic, and the number of 
                                                   sitelinks for the respective language\'s item. For the definition of the WDCM reuse statistic see the <b>Description</b> tab.<br>
                                                   The <i>Fruchterman-Reingold algorithm</i> in <a href = "https://igraph.org/r/" target ="_blank">{igraph}</a> is used to visualize the network.<br>
                                                   <b>Note.</b> This Dashboard <i>focuses on the language items that have any items in Wikidata and whose items are reused</i> in our Wikies. All properties 
                                                   used across this Dashboard are obtained by searching the Wikidata starting from a set of language items thus defined. This implies that the depiction of the 
                                                   language ontology presented here is not necessarily complete.
                                                   </p>'),
                                              hr()
                                              )
                                       )
                                       ),
                              column(width = 3,
                                     HTML('<p style="font-size:80%;"align="right">
                                          <a href = "https://meta.wikimedia.org/wiki/Wikidata_Languages_Landscape" target="_blank">Documentation</a><br>
                                          <a href = "https://analytics.wikimedia.org/datasets/wmde-analytics-engineering/Wikidata/WD_Languages_Landscape/" target = "_blank">Public datasets</a><br>
                                          <a href = "https://github.com/wikimedia/analytics-wmde-WDCM-Overview-Dashboard" target = "_blank">GitHub</a></p>'),
                                     htmlOutput('updateString')
                                     )
                              ),
                            fluidRow(
                              column(width = 12,
                                     withSpinner(plotlyOutput("ontologyGraph",
                                                              width = "100%",
                                                              height = "900px"))                                     
                              )
                            ),
                            fluidRow(
                              hr(),
                              column(width = 2,
                                     br(),
                                     img(src = 'Wikidata-logo-en.png',
                                         align = "left")
                              ),
                              column(width = 10,
                                     hr(),
                                     HTML('<p style="font-size:80%;"><b>WD Languages Landscape :: Wikidata, WMDE 2019</b><br></p>'),
                                     HTML('<p style="font-size:80%;"><b>Contact:</b> Goran S. Milovanovic, Data Scientist, WMDE<br>
                                          <b>e-mail:</b> goran.milovanovic_ext@wikimedia.de<br><b>IRC:</b> goransm</p>'),
                                     br(), br()
                              )
                            )
                              ), # - end tab: Ontology
                    
                    
                    ### --- TAB: languageclass
                    ### --------------------------------
                    
                    tabItem(tabName = "languageclass",
                            fluidRow(
                              column(width = 9,
                                     fluidRow(
                                       column(width = 12,
                                              br(),
                                              HTML('<p style="font-size:80%;"align="left"><b>LANGUAGE/CLASS. </b>
                                                   This tab introduces a visual browser for Wikidata languages and related language classes. Upon selecting a particular 
                                                   entity (language or language class) from the drop-down menu on the left, the Dashboard will generate a graph of its immediate 
                                                   relational context taking into account any of the <b>P31 instance of</b>/<b>P279 subclass of</b>/<b>P361 part of</b> properties. 
                                                   While most of the organization of languages in Wikidata makes use of <b>P31 instance of</b> and <b>P279 subclass of</b> properties, 
                                                   for some languages also <b>P361 part of</b> is used, and not always in a consistent way. By inspecting the Wikidata languages of your 
                                                   interest in this visual browser you can decide if their properties are consistenly structure and maybe introduce a change in the 
                                                   Wikidata ontology later on if you find it necessary or desireable.
                                                   Hovering over a particular node will 
                                                   reveal the details: (a) the respective Wikidata item, (b) the number of 
                                                   labels for that language in Wikidata, (c) the percent of the items that have a label in that language and are also reused across the Wikies, 
                                                   the WDCM (<a href = "http://wmdeanalytics.wmflabs.org/" target="_blank">Wikidata Concepts Monitor</a>) reuse statistic, (d) the number of 
                                                   sitelinks for the respective language\'s item, and (d) the UNESCO/Ethnologue language status for the respective language (if the respective data 
                                                   are present in Wikidata). For the definition of the WDCM reuse statistic see the <b>Description</b> tab.<br>
                                                   <b>Note.</b> This Dashboard <i>focuses on the language items that have any items in Wikidata and whose items are reused</i> in our Wikies. All properties 
                                                   used across this Dashboard are obtained by searching the Wikidata starting from a set of language items thus defined. This implies that the depiction of the 
                                                   language ontology presented here is not necessarily complete.
                                                   </p>'),
                                              hr()
                                       )
                                     ),
                                     fluidRow(
                                       column(width = 3,
                                              selectizeInput("selectLanguage",
                                                             "Select Language/Class:",
                                                             multiple = F,
                                                             choices = NULL,
                                                             selected = NULL
                                                             )
                                              ),
                                       column(width = 9,
                                              br(),
                                              HTML('<p style="font-size:80%;"align="left">Select a <b>language</b>, a <b>language class</b>, or a <b>linguistic category</b>. 
                                                    <br>The dashboard will generate an interactive graph of the selected entity with its immediate relational context.
                                                   <br><b>Note.</b> The P361 <i>Part of</i> relations are represented by <b>dashed</b> links, while <b>solid</b> links represent 
                                                   P31 <i>Instance of</i> or P279 <i>Subclass of</i> relations.</p>'),
                                              hr()
                                              )
                                       )
                              ),
                            column(width = 3,
                                     HTML('<p style="font-size:80%;"align="right">
                                          <a href = "https://meta.wikimedia.org/wiki/Wikidata_Languages_Landscape" target="_blank">Documentation</a><br>
                                          <a href = "https://analytics.wikimedia.org/datasets/wmde-analytics-engineering/Wikidata/WD_Languages_Landscape/" target = "_blank">Public datasets</a><br>
                                          <a href = "https://github.com/wikimedia/analytics-wmde-WDCM-Overview-Dashboard" target = "_blank">GitHub</a></p>')
                                     # htmlOutput('updateInfo')
                                   )
                              ),
                            fluidRow(
                              column(width = 12,
                                     withSpinner(visNetwork::visNetworkOutput('languageClassGraph', height = 700))
                                      
                              )
                            ),
                            fluidRow(
                              hr(),
                              column(width = 2,
                                     br(),
                                     img(src = 'Wikidata-logo-en.png',
                                         align = "left")
                              ),
                              column(width = 10,
                                     hr(),
                                     HTML('<p style="font-size:80%;"><b>WD Languages Landscape :: Wikidata, WMDE 2019</b><br></p>'),
                                     HTML('<p style="font-size:80%;"><b>Contact:</b> Goran S. Milovanovic, Data Scientist, WMDE<br>
                                          <b>e-mail:</b> goran.milovanovic_ext@wikimedia.de<br><b>IRC:</b> goransm</p>'),
                                     br(), br()
                                     )
                              )
                            ), # - end tab: languageclass
                    
                    ### --- TAB: Similarity
                    ### --------------------------------
                    
                    tabItem(tabName = "similarity",
                            fluidRow(
                              column(width = 9,
                                     fluidRow(
                                       column(width = 10,
                                              br(),
                                              HTML('<p style="font-size:80%;"align="left"><b>LABEL SHARING. </b>
                                                   Each bubble in the graph represents a Wikidata language. We first look at each of <b>~70M</b> Wikidata items 
                                                   to see what languages label them. Than we look at the languages, pairwise, and determine the similarity of 
                                                   the way they are used in Wikidata by assessing the items that both languages in a pair refer to (the language overlap) 
                                                   the items which one of them refers to but the other does not (the mismatch). From these data we compute a 
                                                   <a href = "https://en.wikipedia.org/wiki/Jaccard_index" target = "_blank">similarity index</a> between any two Wikidata languages.<br>
                                                   Two visualizations of the similarity data are provided in this tab. The <b>Static/Clusters</b> graph represents each Wikidata 
                                                   language by its Wikimedia code, and each language points towards the language to which it is most similar in the above 
                                                   described sense. A clustering algoritm in <a href = "https://igraph.org/r/" target ="_blank">{igraph}</a> is used to group the 
                                                   languages according to their overall similarity, and the cluster boundaries are overlayed across the graph.<br>
                                                   The second visualization, <b>Interactive/Clusters</b> presents exactly the same data in a different way: 
                                                   the languages are represented by bubbles whose size corresponds to the number of labels in Wikidata for the respective 
                                                   language. Hovering over any language in the graph will reveal more detailed info. Again, each language is connected to the 
                                                   one to which it is most similar in terms of its usage across the Wikidata entities.</b>
                                                   While the previous two Dashboard tabs (<b>Ontology</b> and <b>Language/Classes</b>) focused on the representation of the way 
                                                   the Wikidata language items are connected in Wikidata itself, this tab represents the <i>empirical</i> similarity relations between languages, 
                                                   based on the way they are used to refer to any Wikidata entities. By comparing the structure of languages in the ontology with the 
                                                   usage similarity patterns here we can study if the languages with similar properties also tend to refer to the same sets of entities or 
                                                   they are used in a way which is irrespective of their properties.
                                                   </p>'),
                                              hr()
                                       )
                                     )
                              ),
                              column(width = 3,
                                     HTML('<p style="font-size:80%;"align="right">
                                          <a href = "https://meta.wikimedia.org/wiki/Wikidata_Languages_Landscape" target="_blank">Documentation</a><br>
                                          <a href = "https://analytics.wikimedia.org/datasets/wmde-analytics-engineering/Wikidata/WD_Languages_Landscape/" target = "_blank">Public datasets</a><br>
                                          <a href = "https://github.com/wikimedia/analytics-wmde-WDCM-Overview-Dashboard" target = "_blank">GitHub</a></p>')
                                     )
                              ),
                            fluidRow(
                              column(width = 12,
                                     tabBox(id = 'tabset1', 
                                            selected = 'Static/Clusters', 
                                            width = 12,
                                            height = NULL, 
                                            side = "left",
                                            tabPanel("Static/Clusters",
                                                     fluidRow(
                                                       column(width = 6,
                                                              withSpinner(plotOutput('similarityGraph_Static', 
                                                                                     width = "100%",
                                                                                     height = "900px"))
                                                       )
                                                     )
                                            ),
                                            tabPanel("Interactive/Clusters",
                                                     fluidRow(
                                                       column(width = 7,
                                                              withSpinner(plotlyOutput("similarityGraph",
                                                                                       width = "100%",
                                                                                       height = "900px"))                                                       )
                                                     )
                                            )
                                     )
                              )
                            ),
                            fluidRow(
                              column(width = 2,
                                     br(),
                                     img(src = 'Wikidata-logo-en.png',
                                         align = "left")
                              ),
                              column(width = 10,
                                     hr(),
                                     HTML('<p style="font-size:80%;"><b>WD Languages Landscape :: Wikidata, WMDE 2019</b><br></p>'),
                                     HTML('<p style="font-size:80%;"><b>Contact:</b> Goran S. Milovanovic, Data Scientist, WMDE<br>
                                          <b>e-mail:</b> goran.milovanovic_ext@wikimedia.de<br><b>IRC:</b> goransm</p>'),
                                     br(), br()
                              )
                            )
                              ), # - end tab: similarity          
                    
                    ### --- TAB: Status
                    ### --------------------------------
                    
                    tabItem(tabName = "status",
                            fluidRow(
                              column(width = 9,
                                     fluidRow(
                                       column(width = 12,
                                              br(),
                                              HTML('<p style="font-size:80%;"align="left"><b>LANGUAGE STATUS. </b>
                                                   We use the <a href="https://en.wikipedia.org/wiki/Endangered_language#UNESCO_definitions" target="_blank">UNESCO language endangerment categories</a> 
                                                   and the <a href="https://www.ethnologue.com/about/language-status" target ="_blank">Ethnologue language status</a> as (and when) reported 
                                                   in Wikidata to study several indicators of how does a particular language stand in Wikidata and across the WMF\'s projects in general.
                                                   Each chart in this tab receives a closer description immediately beneath it.<br>
                                                   The horizontal axes in the following interactive charts always represent the language status category. Each bubble represents a Wikidata language, but 
                                                   different variables are mapped onto the size of the bubble and the charts\' vertical axis in each panel. We focus on the following language usage related 
                                                   indicators here: (a) the number of <b>sitelinks</b> for the respective Wikidata language, (b) the number of <b>labels</b> that it has (i.e. the 
                                                   the number of entities to which it refers in Wikidata), and (c) the <b>WDCM reuse statistic</b> for all the items referred to from a particular language 
                                                   (For the definition of the WDCM reuse statistic see the <b>Description</b> tab).<br>    
                                                   By following the usage indicators (sitelinks, number of labels, and reuse across the WMF projects) for Wikidata languages of less 
                                                   favorable status we can recognize what languages we need to focus on in order to represent them in Wikidata and across the Wikimedia universe 
                                                   and thus help their preservation. When combined with structural and empirical similarity data provided on the previous tabs in this Dashboard 
                                                   these data can help formulate strategies to improve the digital representation of underrepresented languages in general.
                                                   </p>'),
                                              hr()
                                       )
                                     )
                              ),
                              column(width = 3,
                                     HTML('<p style="font-size:80%;"align="right">
                                          <a href = "https://meta.wikimedia.org/wiki/Wikidata_Languages_Landscape" target="_blank">Documentation</a><br>
                                          <a href = "https://analytics.wikimedia.org/datasets/wmde-analytics-engineering/Wikidata/WD_Languages_Landscape/" target = "_blank">Public datasets</a><br>
                                          <a href = "https://github.com/wikimedia/analytics-wmde-WDCM-Overview-Dashboard" target = "_blank">GitHub</a></p>')
                                     # htmlOutput('updateInfo')
                                     )
                              ),
                            fluidRow(
                              column(width = 12,
                                     fluidRow(
                                       column(width = 6,
                                              withSpinner(plotlyOutput('status_UNESCO_Sitelinks',
                                                                       width = "100%",
                                                                       height = "650px")),
                                              br(), 
                                              HTML('<p style="font-size:80%;"align="left"><b>UNESCO status and sitelinks.</b> 
                                                               The vertical axis and the size of the bubble represent the number of sitelinks for each particular 
                                                               language with the UNESCO language status data found in Wikidata.</p>'),
                                              hr()),
                                       column(width = 6,
                                              withSpinner(plotlyOutput('status_Ethnologue_Sitelinks',
                                                                       width = "100%",
                                                                       height = "650px")),
                                              br(),
                                              HTML('<p style="font-size:80%;"align="left"><b>Ethnologue status and sitelinks.</b> 
                                                               The vertical axis and the size of the bubble represent the number of sitelinks for each particular 
                                                               language with the Ethnologue language status data found in Wikidata.</p>'),
                                              hr())
                                     )
                              )
                            ),
                            fluidRow(
                              column(width = 12,
                                     fluidRow(
                                       column(width = 6,
                                              withSpinner(plotlyOutput('status_UNESCO_numItems',
                                                                       width = "100%",
                                                                       height = "650px")),
                                              br(), 
                                              HTML('<p style="font-size:80%;"align="left"><b>UNESCO status and number of labels.</b> 
                                                               The vertical axis and the size of the bubble represent the number of labels (<i>log scale</i>) present 
                                                               in Wikidata for each particular language with the UNESCO language status data found in Wikidata.</p>'),
                                              hr()),
                                       column(width = 6,
                                              withSpinner(plotlyOutput('status_Ethnologue_numItems',
                                                                       width = "100%",
                                                                       height = "650px")),
                                              br(), 
                                              HTML('<p style="font-size:80%;"align="left"><b>Ethnologue status and number of labels.</b> 
                                                               The vertical axis and the size of the bubble represent the number of labels (<i>log scale</i>) present 
                                                               in Wikidata for each particular language with the Ethnologue language status data found in Wikidata.</p>'),
                                              hr())
                                     )
                              )
                            ),
                            fluidRow(
                              column(width = 12,
                                     fluidRow(
                                       column(width = 6,
                                              withSpinner(plotlyOutput('status_UNESCO_reuse',
                                                                       width = "100%",
                                                                       height = "650px")),
                                              br(), 
                                              HTML('<p style="font-size:80%;"align="left"><b>UNESCO status and the WDCM reuse statistic.</b> 
                                                               The vertical axis and the size of the bubble represent the total WDCM reuse statistic (<i>log scale</i>) 
                                                               for all items referred to from each particular language with the UNESCO language status data found in Wikidata.</p>'),
                                              hr()),
                                       column(width = 6,
                                              withSpinner(plotlyOutput('status_Ethnologue_reuse',
                                                                       width = "100%",
                                                                       height = "650px")),
                                              br(), 
                                              HTML('<p style="font-size:80%;"align="left"><b>Ethnologue status and the WDCM reuse statistic.</b> 
                                                               The vertical axis and the size of the bubble represent the total WDCM reuse statistic (<i>log scale</i>) 
                                                               for all items referred to from each particular language with the Ethnologue language status data found in Wikidata.</p>'),
                                              hr())
                                     )
                              )
                            ),
                            fluidRow(
                              column(width = 2,
                                     br(),
                                     img(src = 'Wikidata-logo-en.png',
                                         align = "left")
                              ),
                              column(width = 10,
                                     hr(),
                                     HTML('<p style="font-size:80%;"><b>WD Languages Landscape :: Wikidata, WMDE 2019</b><br></p>'),
                                     HTML('<p style="font-size:80%;"><b>Contact:</b> Goran S. Milovanovic, Data Scientist, WMDE<br>
                                          <b>e-mail:</b> goran.milovanovic_ext@wikimedia.de<br><b>IRC:</b> goransm</p>'),
                                     br(), br()
                              )
                            )
                              ), # - end tab: status      
                    
                    ### --- TAB: Usage
                    ### --------------------------------
                    
                    tabItem(tabName = "usage",
                            fluidRow(
                              column(width = 9,
                                     fluidRow(
                                       column(width = 12,
                                              br(),
                                              HTML('<p style="font-size:80%;"align="left"><b>LANGUAGE USAGE. </b>
                                                   The charts in this Dashboard tab represent various indicators of language usage in Wikidata and 
                                                   across the Wikimedia projects and are meant for a more general assessment of the Wikidata languages in comparison 
                                                   to the detailed analytics provided in the previous tabs.
                                                   Each chart in this tab receives a closer description immediately beneath it.<br>
                                                   For the definition of the WDCM reuse statistic see the <b>Description</b> tab
                                                   </p>'),                                              
                                              hr()
                                       )
                                     )
                              ),
                              column(width = 3,
                                     HTML('<p style="font-size:80%;"align="right">
                                          <a href = "https://meta.wikimedia.org/wiki/Wikidata_Languages_Landscape" target="_blank">Documentation</a><br>
                                          <a href = "https://analytics.wikimedia.org/datasets/wmde-analytics-engineering/Wikidata/WD_Languages_Landscape/" target = "_blank">Public datasets</a><br>
                                          <a href = "https://github.com/wikimedia/analytics-wmde-WDCM-Overview-Dashboard" target = "_blank">GitHub</a></p>')
                                     # htmlOutput('updateInfo')
                                     )
                              ),
                            fluidRow(
                              column(width = 12,
                                     fluidRow(
                                       column(width = 6,
                                              withSpinner(plotlyOutput('labels_Reuse',
                                                                       width = "100%",
                                                                       height = "650px")),
                                              br(), 
                                              HTML('<p style="font-size:80%;"align="left"><b>Number of labels and the total WDCM reuse statistic.</b> 
                                                               The horizontal axis in this chart represents the number of items (i.e. labels) for each particular Wikidata language 
                                                               that is ever used across the Wikimedia projects. The vertical axis and the size of the bubble represent the total WDCM reuse statistic 
                                                               for all items referred to from each particular language.</p>'),
                                              hr()),
                                       column(width = 6,
                                              withSpinner(plotlyOutput('log_labels_Reuse',
                                                                       width = "100%",
                                                                       height = "650px")),
                                              br(), 
                                              HTML('<p style="font-size:80%;"align="left"><b>Number of labels and the total WDCM reuse statistic.</b> 
                                                               The horizontal axis in this chart represents the number of items (i.e. labels, <i>log scale</i>) for each particular Wikidata language 
                                                               that is ever used across the Wikimedia projects. The vertical axis and the size of the bubble represent the total WDCM reuse statistic <i>log scale</i> 
                                                               for all items referred to from each particular language.</p>'),
                                              hr())
                                     )
                              )
                            ),
                            fluidRow(
                              column(width = 12,
                                     fluidRow(
                                       column(width = 6,
                                              withSpinner(plotlyOutput('itemCount_avgReuse',
                                                                       width = "100%",
                                                                       height = "650px")),
                                              br(), 
                                              HTML('<p style="font-size:80%;"align="left"><b>Number of labels and the average WDCM reuse statistic.</b> 
                                                               The horizontal axis in this chart represents the number of items (i.e. labels, <i>log scale</i>) for each particular Wikidata language 
                                                               that is ever used across the Wikimedia projects. The vertical axis and the size of the bubble represent the <b>average</b> WDCM reuse statistic (<i>log scale</i>) 
                                                               computed across all items referred to from each particular language.</p>'),
                                              hr()),
                                       column(width = 6,
                                              withSpinner(plotlyOutput('itemCount_propReused',
                                                                       width = "100%",
                                                                       height = "650px")),
                                              br(), 
                                              HTML('<p style="font-size:80%;"align="left"><b>Number of labels and the average WDCM reuse statistic.</b> 
                                                               The horizontal axis in this chart represents the number of items (i.e. labels, <i>log scale</i>) for each particular Wikidata language 
                                                               that is ever used across the Wikimedia projects. The vertical axis and the size of the bubble represent the <b>percent</b> of items 
                                                               referred to from each particular language that are ever reused across the Wikimedia projects.</p>'),
                                              hr())
                                     )
                              )
                            ),
                            fluidRow(
                              column(width = 2,
                                     br(),
                                     img(src = 'Wikidata-logo-en.png',
                                         align = "left")
                              ),
                              column(width = 10,
                                     hr(),
                                     HTML('<p style="font-size:80%;"><b>WD Languages Landscape :: Wikidata, WMDE 2019</b><br></p>'),
                                     HTML('<p style="font-size:80%;"><b>Contact:</b> Goran S. Milovanovic, Data Scientist, WMDE<br>
                                          <b>e-mail:</b> goran.milovanovic_ext@wikimedia.de<br><b>IRC:</b> goransm</p>'),
                                     br(), br()
                              )
                            )
                              ), # - end tab: usage      
                    
                    tabItem(tabName = "description",
                            fluidRow(
                              column(width = 8,
                                     HTML('<h2>Wikidata Languages Landscape Dashboard</h2>
                                          <h4>Dashboard description<h4>
                                          <hr>
                                          <h4>Introduction<h4>
                                          <br>
                                          <p><font size = 2>This dashboard is developed by <a href="https://wikimedia.de/" target="_blank">WMDE</a> in response to the 
                                          <a href = "https://phabricator.wikimedia.org/T221965" target="_blank">Wikidata Languages Landscape Phabricator task</a> and in the 
                                          scope of preparations for the <b><a href="https://www.wikidata.org/wiki/Wikidata:WikidataCon_2019/Program" target="_blank">WikidataCon 2019</a></b> 
                                          (the main topic of the conference: <b><i>languages and Wikidata</i></b>. The WD Languages Landscape dashboard relies on different data sources to 
                                          provide a comprehensive picture of how different languages are used in Wikidata and - via the entities that they refer to - how they are mapped across the 
                                          universe of Wikimedia projects:
                                          <ul>
                                          <li>the copy of the <a href="https://www.wikidata.org/wiki/Wikidata:Database_download#JSON_dumps_(recommended)" target="_blank">Wikidata JSON dump</a> in <a href="https://phabricator.wikimedia.org/T209655" target="_blank">hdfs</a>,</li>
                                          <li>various datasets obtained directly from the <a href="https://www.mediawiki.org/wiki/Wikidata_Query_Service" target="_blank">WDQS</a> via <a href="https://en.wikipedia.org/wiki/SPARQL" target="_blank">SPARQL</a> queries, and</li>
                                          <li>datasets on Wikidata entity reuse statistics obtained from the <a href="https://www.wikidata.org/wiki/Wikidata:Wikidata_Concepts_Monitor" target="_blank">Wikidata Concepts Monitor</a>.</li>
                                          </ul>
                                          In addition, <a href="https://www.wikidata.org/wiki/Help:Wikimedia_language_codes/lists/all" target="_blank">The List of All Wikimedia Language Codes</a> - 
                                          as maintained at Wikidata and periodically updated by a bot - is used to verify the language codes obtained from these data sources.
                                          The goal of this dashboard is to provide insights into the various aspects of language use in Wikidata. We study the Wikidata language items, and 
                                          then the entities that any of the Wikidata languages is referring to, to infer the total reuse of a language across the Wikimedia projects. We derive similarity metrics 
                                          from <i>language</i> x <i>language</i> matrices of overlap in their labels across almost 60 millions of Wikidata items. We study the way Wikidata 
                                          languages are represented in its ontology and compare this representation to the similarity across languages inferred from empirical data on their 
                                          overlap in signification across the Wikidata entities. We also look at the <b>UNESCO</b> and <b>Ethnologue</b> language status categories and compare the status of 
                                          language against various indicators of its use and reuse in Wikidata and Wikimedia projects.<br>

                                          Several means of data visualization are employed in this dashboard, relying on 
                                          <a href="https://plot.ly/r/" target="_blank">{plotly}</a>, <a href="https://ggplot2.tidyverse.org/" target="_blank">{ggplot2}</a>, 
                                          <a href="https://igraph.org/r/" target="_blank">{igraph}</a>, and <a href="https://datastorm-open.github.io/visNetwork/" target="_blank">{visNetwork}</a> 
                                          in <a href="https://www.r-project.org/" target="_blank">R</a> to visualize the complex relationship discovered in our study of the Wikidata languages.
                                          <a href="https://spark.apache.org/" target="_blank">Apache Spark</a> and <a href="https://spark.apache.org/docs/latest/api/python/index.html" target="_blank">Pyspark</a> are used for ETL purposes. 
                                          All computation is, of course, done in <a href="https://www.r-project.org/" target="_blank">R</a>; the dashboard itself is developed in <a href="https://shiny.rstudio.com/" target="_blank">{shiny}</a> 
                                          and deployed on an open-source <a href="https://rstudio.com/products/shiny/shiny-server/" target="_blank">RStudio Shiny Server</a> instance 
                                          in <a href="https://wikitech.wikimedia.org/wiki/Portal:Cloud_VPS" target="_blank">CloudVPS</a>.

                                          <br><b>N.B.</b> All presented results are relative to the latest version of the WD Dump processed and copied to the WMD Data Lake 
                                          (see: <a href="https://phabricator.wikimedia.org/T209655" target="_blank">Phabricator</a>).</font></p>
                                          
                                          <hr>
                                          <h4>Definitions</h4>
                                          <br>
                                          <p><font size = 2><b>N.B.</b> The current <b>Wikidata item usage statistic</b> (or WDCM reuse statistic) definition is <i>the count of the number of pages in a particular client project
                                          where the respective Wikidata item is used</i>. Thus, the current definition ignores the usage aspects completely. This definition is motivated by the currently 
                                          present constraints in Wikidata usage tracking across the client projects 
                                          (see <a href = "https://www.mediawiki.org/wiki/Wikibase/Schema/wbc_entity_usage" target = "_blank">Wikibase/Schema/wbc entity usage</a>). 
                                          With more mature Wikidata usage tracking systems, the definition will become a subject 
                                          of change.<br>
                                          In this dashboard we use the WDCM reuse statistic to represent the extent upon which a particular language is dominant in the Wikimedia projects. 
                                          It is done in the following way: we look at all the Wikidata entities that have a label in a particular language, and we take the total (the sum) of their 
                                          respective WDCM reuse statistics to represent the reuse statistic of a language. Also, some of the charts use the average WDCM reuse statistic: that 
                                          is the mean of the WDCM reuse statistics taken from all Wikidata entities that have a label in a particular language.
                                          The motivation for this measure is fundamental: it assigns a higher rank to languages that can refer to highly popular Wikidata entities. Of course, 
                                          it is all relative to the Wikidata/Wikimedia universe: a language might be able to refer to some particular referent (i.e. have a word for something), but the respective 
                                          sign (word) might not be yet present in Wikidata as a label. 
                                          </font></p>
                                          ')
                                     )
                              ),
                            fluidRow(
                              hr(),
                              column(width = 2,
                                     br(),
                                     img(src = 'Wikidata-logo-en.png',
                                         align = "left")
                              ),
                              column(width = 10,
                                     hr(),
                                     HTML('<p style="font-size:80%;"><b>WD Languages Landscape :: Wikidata, WMDE 2019</b><br></p>'),
                                     HTML('<p style="font-size:80%;"><b>Contact:</b> Goran S. Milovanovic, Data Scientist, WMDE<br>
                                          <b>e-mail:</b> goran.milovanovic_ext@wikimedia.de<br><b>IRC:</b> goransm</p>'),
                                     br(), br()
                                     )
                              )
                            ) # - end tab Item Description
                    
                    ) # - end Tab Items
                  
                  ) ### --- END dashboardBody
                
                ) ### --- END dashboardPage
  
  ) # END shinyUI

