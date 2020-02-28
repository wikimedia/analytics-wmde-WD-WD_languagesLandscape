### ---------------------------------------------------------------------------
### --- WD Languages Landscape
### --- Languages Structure Dashboard
### --- Script: server.R, v. Beta 0.1
### ---------------------------------------------------------------------------

### --------------------------------
### --- Setup
### --------------------------------
### --- general
library(shiny)
library(shinydashboard)
library(data.table)
library(stringr)
library(dplyr)
### --- visualize
library(DT)
library(visNetwork)
library(igraph)
library(ggplot2)
library(scales)
library(plotly)
library(ape)
### --- connect
library(httr)
library(curl)

### --------------------------------
### --- Server (Session) Scope
### --------------------------------


### --- Fetch data files

### --- Fetch ontology structure
ontologyStructure <- read.csv('data/WD_Languages_OntologyStructure.csv', 
                              header = T, 
                              row.names = 1, 
                              check.names = F,
                              stringsAsFactors = F)
### --- Fetch used languages
usedLanguages <- read.csv('data/WD_Languages_UsedLanguages.csv',
                          header = T,
                          row.names = 1,
                          check.names = F,
                          stringsAsFactors = F)
usedLanguages$label <- paste0(tolower(usedLanguages$description), " (", 
                              usedLanguages$languageURI, ")")
# - Fetch Jaccard Similarity
simData <- read.csv(paste0('data/',
                           'WD_Languages_Jaccard_Similarity.csv'),
                    header = T,
                    row.names = 1,
                    stringsAsFactors = F,
                    check.names = F)
simData$avg_reuse_per_item <- simData$reuse/simData$num_items_reused
simData$prop_items_used <- simData$num_items_reused/simData$item_count

# - create ontology nodes and edges
# - nodes
n1 <- paste0(ontologyStructure$itemLabel, " (", ontologyStructure$item, ")")
n2 <- paste0(ontologyStructure$superClassLabel, " (", ontologyStructure$superClass, ")")
ns <- unique(c(n1, n2))
nodes <- data.frame(id = 1:length(ns),
                    label = ns,
                    shadow = T,
                    stringsAsFactors = F)
nodes$color <- 'lightgrey'
nodes <- dplyr::left_join(nodes, 
                          dplyr::select(usedLanguages, 
                                        item_count, reuse, num_items_reused, 
                                        EthnologueLanguageStatus, UNESCOLanguageStatus, 
                                        numSitelinks, label),
                          by = "label")
nodes <- nodes[!duplicated(nodes), ]
wDuplicated <- nodes$id[which(duplicated(nodes$id))]
if (length(wDuplicated) > 0) {
  fixDuplicates <- lapply(wDuplicated, function(x) {
    d <- nodes[nodes$id %in% x, ]
    d <- apply(d, 2, function(y) {
      paste(unique(y), collapse = ", ")
    })
    d <- as.data.frame(t(d))
    d
  })
  fixDuplicates <- rbindlist(fixDuplicates, fill = T, use.names = T)
  eliminate <- which(nodes$id %in% wDuplicated)
  if (length(eliminate > 0)) {
    nodes <- nodes[-eliminate, ]
    nodes <- rbind(nodes, fixDuplicates)
  }
}
nodes$item_count <- as.numeric(levels(nodes$item_count))[nodes$item_count]
nodes$reuse <- as.numeric(levels(nodes$reuse))[nodes$reuse]
nodes$num_items_reused <- as.numeric(levels(nodes$num_items_reused))[nodes$num_items_reused]
nodes$numSitelinks <- as.numeric(levels(nodes$numSitelinks))[nodes$numSitelinks]
nodes$title <- paste0('<p style="font-family:helvetica;font-size:75%;"><b>', nodes$label, '</b><br>',
                      ifelse(!is.na(nodes$item_count), paste0('Num.labels: ', nodes$item_count, '<br>'), ""),
                      ifelse(!is.na(nodes$reuse), paste0('Reuse statistic: ', nodes$reuse, '<br>'), ""),
                      ifelse(!is.na(nodes$num_items_reused), paste0('% of items reused: ', 
                                                                    round(as.numeric(nodes$num_items_reused)/as.numeric(nodes$item_count)*100, 2), '<br>'), ""),
                      ifelse(!is.na(nodes$numSitelinks), paste0('Num.sitelinks: ', nodes$numSitelinks, '<br>'), ""),
                      ifelse(!is.na(nodes$UNESCOLanguageStatus), paste0('UNESCO status: ', nodes$UNESCOLanguageStatus, '<br>'), ""),
                      ifelse(!is.na(nodes$EthnologueLanguageStatus), paste0('Ethnologue status: ', nodes$EthnologueLanguageStatus, '.<br>'), ""),
                      '</p>')
nodes$id <- 1:length(nodes$id)
# - edges
conceptsStruct <- data.frame(
  from = sapply(paste0(ontologyStructure$itemLabel, " (", ontologyStructure$item, ")"), function(x) {
    nodes$id[which(nodes$label %in% x)]
  }),
  to = sapply(paste0(ontologyStructure$superClassLabel, " (", ontologyStructure$superClass, ")"), function(x) {
    nodes$id[which(nodes$label %in% x)]
  }),
  arrows = 'to',
  label = ontologyStructure$relation,
  dashes = ifelse(ontologyStructure$relation == 'P361', T, F),
  font.size = 10,
  stringsAsFactors = F)

### --- fetch language status files
status_UNESCO_Sitelinks <- read.csv('data/WD_Vis_UNESCO Language Status_Sitelinks.csv',
                                    header = T,
                                    row.names = 1,
                                    check.names = F,
                                    stringsAsFactors = F)
status_Ethnologue_Sitelinks <- read.csv('data/WD_Vis_EthnologueLanguageStatus_Sitelinks.csv',
                                    header = T,
                                    row.names = 1,
                                    check.names = F,
                                    stringsAsFactors = F)
status_UNESCO_numItems <- read.csv('data/WD_Vis_UNESCO Language Status_NumItems.csv',
                                    header = T,
                                    row.names = 1,
                                    check.names = F,
                                    stringsAsFactors = F)
status_Ethnologue_numItems <- read.csv('data/WD_Vis_EthnologueLanguageStatus_NumItems.csv',
                                        header = T,
                                        row.names = 1,
                                        check.names = F,
                                        stringsAsFactors = F)
status_UNESCO_reuse <- read.csv('data/WD_Vis_UNESCO Language Status_ItemReuse.csv',
                                   header = T,
                                   row.names = 1,
                                   check.names = F,
                                   stringsAsFactors = F)
status_Ethnologue_reuse <- read.csv('data/WD_Vis_EthnologueLanguageStatus_ItemReuse.csv',
                                       header = T,
                                       row.names = 1,
                                       check.names = F,
                                       stringsAsFactors = F)

# - fetch languagesCount as dataSet
dataSet <- read.csv(paste0('data/wd_languages_count.csv'), 
                    header = T,
                    row.names = 1,
                    stringsAsFactors = F,
                    check.names = F)
dataSet$avg_reuse_per_item <- dataSet$reuse/dataSet$num_items_reused
dataSet$prop_items_used <- dataSet$num_items_reused/dataSet$item_count

# - update string
updateString <- readLines(paste0('data/WDLanguagesUpdateString.txt'))

### --- shinyServer
shinyServer(function(input, output, session) {
  
  ### ------------------------------------------
  ### --- Update String
  ### ------------------------------------------
  
  ### --- GENERAL: Update String
  output$updateString <- renderText({
    paste0('<p style="font-size:80%;"align="right"><b>', updateString, '</b></p>')
  })
  
  ### ------------------------------------------
  ### --- TAB: tabPanel ontology
  ### ------------------------------------------
  
  output$ontologyGraph <- renderPlotly({
    
    withProgress(message = 'Generating Network.', detail = "Please be patient.", value = 0, {
      
      incProgress(1/7, detail = "Prepare data structures.")
      
      oS <- data.frame(Outgoing = paste0(ontologyStructure$itemLabel, " (", ontologyStructure$item, ")"),
                       Incoming = paste0(ontologyStructure$superClassLabel, " (", ontologyStructure$superClass, ")"),
                       stringsAsFactors = F)
      
      idNet <- data.frame(from = oS$Outgoing,
                          to = oS$Incoming,
                          stringsAsFactors = F)
      idNet <- graph.data.frame(idNet,
                                vertices = NULL,
                                directed = T)
      
      # - Layout
      incProgress(2/7, detail = "Rendering graph. Please be patient.")
      L <- layout_with_kk(idNet, dim = 2)
      L <- as.data.frame(L)
      
      # - Attributes
      vs <- V(idNet)
      L$name <- vs$name
      es <- as.data.frame(get.edgelist(idNet))
      Nv <- length(vs)
      Ne <- dim(es)[1]
      Xn <- L[,1]
      Yn <- L[,2]
      vsnames <- data.frame(id = vs$name, 
                            stringsAsFactors = F)
      vsnames_count <- c(paste0(ontologyStructure$itemLabel, " (", ontologyStructure$item, ")"),
                         paste0(ontologyStructure$superClassLabel, " (", ontologyStructure$superClass, ")"))
      vsnames_count <- as.data.frame(table(vsnames_count))
      vsnames <- dplyr::left_join(vsnames, vsnames_count, 
                                  by = c("id" = "vsnames_count"))
      ul <- dplyr::select(usedLanguages, 
                          label, 
                          item_count,
                          reuse,
                          num_items_reused, 
                          numSitelinks)
      ul <- ul[!duplicated(ul), ]
      vsnames <- dplyr::left_join(vsnames,
                                  ul, 
                                  by = c("id" = "label"))
      
      # - {plotly}
      incProgress(3/7, detail = "Rendering graph. Please be patient.")
      network <- plot_ly(x = ~Xn, 
                         y = ~Yn, 
                         mode = "markers", 
                         text = paste0(vsnames$id, "<br><b>Relations:</b> ", vsnames$Freq, "<br>", 
                                       ifelse(!is.na(vsnames$item_count), paste0('Num.labels: ', vsnames$item_count, '<br>'), ""),
                                       ifelse(!is.na(vsnames$reuse), paste0('Reuse statistic: ', vsnames$reuse, '<br>'), ""),
                                       ifelse(!is.na(vsnames$num_items_reused), paste0('% of items reused: ', 
                                                                                     round(as.numeric(vsnames$num_items_reused)/as.numeric(vsnames$item_count)*100, 2), '<br>'), ""),
                                       ifelse(!is.na(vsnames$numSitelinks), paste0('Num.sitelinks: ', vsnames$numSitelinks, '.'), "")
                                       ), 
                         size = log(vsnames$Freq),
                         sizes = c(10, 300),
                         hoverinfo = "text")
      edge_shapes <- list()
      incProgress(4/7, detail = "Rendering graph. Please be patient.")
      for (i in 1:Ne) {
        v0 <- es[i, ]$V1
        v1 <- es[i, ]$V2
        edge_shape = list(
          type = "line",
          line = list(color = "#030303", width = 0.3),
          x0 = Xn[which(L$name == v0)],
          y0 = Yn[which(L$name == v0)],
          x1 = Xn[which(L$name == v1)],
          y1 = Yn[which(L$name == v1)]
        )
        edge_shapes[[i]] <- edge_shape
      }
      axis <- list(title = "", 
                   showgrid = FALSE, 
                   showticklabels = FALSE, 
                   zeroline = FALSE)
      incProgress(5/7, detail = "Rendering graph. Please be patient.")
      p <- layout(
        network,
        shapes = edge_shapes,
        xaxis = axis,
        yaxis = axis
      )
      incProgress(6/7, detail = "Rendering graph. Please be patient.")
      ggplotly(p) %>%
        plotly::config(displayModeBar = TRUE,
                       displaylogo = FALSE,
                       collaborate = FALSE,
                       modeBarButtonsToRemove = list(
                         'lasso2d',
                         'select2d',
                         'toggleSpikelines',
                         'hoverClosestCartesian',
                         'hoverCompareCartesian',
                         'autoScale2d'
                       ))
    })
  })
  
  
  ### ------------------------------------------
  ### --- TAB: tabPanel languageclass
  ### ------------------------------------------
  
  ### --- SELECT: update select 'selectCategory'
  updateSelectizeInput(session,
                       'selectLanguage',
                       "Select Language/Class:",
                       choices = ns,
                       selected = ns[round(runif(1, 1, length(ns)))],
                       server = TRUE)
  
  ### --- visNetwork: languageClassGraph w. P31/P279/P361
  # - output$languageClassGraph
  output$languageClassGraph <- renderVisNetwork({
    # - what is selected?
    selectedNode <- nodes$id[which(nodes$label %in% input$selectLanguage)]
    # - edges
    graph_edges <- conceptsStruct %>% 
      dplyr::filter(from %in% selectedNode | to %in% selectedNode)
    # - nodes
    graph_nodes <- nodes %>% 
      dplyr::filter(id %in% unique(c(graph_edges$from, graph_edges$to)))
    # - repeat for links of selected:
    graph_edges2 <- conceptsStruct %>% 
      dplyr::filter(from %in% unique(graph_nodes$id))
    graph_nodes2 <- nodes %>% 
      dplyr::filter(id %in% unique(c(graph_edges2$from, graph_edges2$to)))
    # - bind
    graph_nodes <- rbind(graph_nodes, graph_nodes2)
    graph_nodes <- graph_nodes[!duplicated(graph_nodes), ]
    graph_edges <- rbind(graph_edges, graph_edges2)
    graph_edges <- graph_edges[!duplicated(graph_edges), ]
    # - color selected:
    graph_nodes$color[graph_nodes$id == selectedNode] <- 'blue'
    # - render network:
    visNetwork(nodes = graph_nodes,
               edges = graph_edges,
               width = "2000px",
               height = "1500px") %>%
      visPhysics(stabilization = FALSE) %>% 
      visNodes(scaling = list(min = 20, max = 65))
  }) %>% withProgress(message = 'Generating graph.',
                      min = 0,
                      max = 1,
                      value = 1, {incProgress(amount = 1)})
  
  
  ### ------------------------------------------
  ### --- TAB: tabPanel similarity
  ### ------------------------------------------
  
  output$similarityGraph <- renderPlotly({
    
    withProgress(message = 'Generating Network.', detail = "Please be patient.", value = 0, {
      
      incProgress(1/7, detail = "Prepare data structures.")
      
      # - similarity matrix
      simMatrix <- as.matrix(simData[, 1:(dim(simData)[1])])
      rownames(simMatrix) <- colnames(simMatrix)
      nns <- vector(mode = "list", length = dim(simMatrix)[1])
      for (i in 1:(dim(simMatrix)[1])) {
        lan <- simMatrix[i, ]
        from = names(lan)[i]
        ix <- setdiff(1:length(lan), i)
        lan <- lan[ix]
        w <- which.max(lan)
        nns[[i]] <- data.frame(outgoing = from, 
                               incoming = names(lan)[w], 
                               stringsAsFactors = F)
      }
      nns <- rbindlist(nns)
      
      oS <- data.frame(Outgoing = nns$outgoing,
                       Incoming = nns$incoming,
                       stringsAsFactors = F)
      
      idNet <- data.frame(from = oS$Outgoing,
                          to = oS$Incoming,
                          stringsAsFactors = F)
      idNet <- graph.data.frame(idNet,
                                vertices = NULL,
                                directed = T)
      
      # - colors
      cc <- cluster_edge_betweenness(as.undirected(idNet)) 
      cc <- cc$membership
      cc <- colors()[cc]
      
      
      # - Layout
      incProgress(2/7, detail = "Rendering graph. Please be patient.")
      L <- layout_with_kk(idNet, dim = 2)
      L <- as.data.frame(L)
      
      # - Attributes
      vs <- V(idNet)
      L$name <- vs$name
      es <- as.data.frame(get.edgelist(idNet))
      Nv <- length(vs)
      Ne <- dim(es)[1]
      Xn <- L[,1]
      Yn <- L[,2]
      vsnames <- data.frame(id = vs$name, 
                            stringsAsFactors = F)
      ul <- dplyr::select(usedLanguages,
                          language, item_count, reuse, num_items_reused,
                          numSitelinks, label)
      ul <- ul[!duplicated(ul), ]
      # - fix duplicates in ul
      wDuplicated <- ul$language[which(duplicated(ul$language))]
      if (length(wDuplicated) > 0) {
        fixDuplicates <- lapply(wDuplicated, function(x) {
          d <- ul[ul$language %in% x, ]
          d <- apply(d, 2, function(y) {
            paste(unique(y), collapse = ", ")
          })
          d <- as.data.frame(t(d))
          d
        })
      }
      fixDuplicates <- rbindlist(fixDuplicates, fill = T, use.names = T)
      eliminate <- which(ul$language %in% wDuplicated)
      if (length(eliminate > 0)) {
        ul <- ul[-eliminate, ]
        ul <- rbind(ul, fixDuplicates)
        }
      vsnames <- dplyr::left_join(vsnames,
                                  ul, 
                                  by = c("id" = "language"))
      vsnames$item_count <- as.numeric(levels(vsnames$item_count))[vsnames$item_count]
      vsnames$reuse <- as.numeric(levels(vsnames$reuse))[vsnames$reuse]
      vsnames$num_items_reused <- as.numeric(levels(vsnames$num_items_reused))[vsnames$num_items_reused]
      vsnames$numSitelinks <- as.numeric(levels(vsnames$numSitelinks))[vsnames$numSitelinks]
      # - {plotly}
      incProgress(3/7, detail = "Rendering graph. Please be patient.")
      network <- plot_ly(x = ~Xn, 
                         y = ~Yn, 
                         mode = "markers", 
                         text = paste0(vsnames$id, "<br>", 
                                       vsnames$label, "<br>",
                                       ifelse(!is.na(vsnames$item_count), paste0('Num.labels: ', vsnames$item_count, '<br>'), ""),
                                       ifelse(!is.na(vsnames$reuse), paste0('Reuse statistic: ', vsnames$reuse, '<br>'), ""),
                                       ifelse(!is.na(vsnames$num_items_reused), paste0('% of items reused: ', 
                                                                                       round(as.numeric(vsnames$num_items_reused)/as.numeric(vsnames$item_count)*100, 2), '<br>'), ""),
                                       ifelse(!is.na(vsnames$numSitelinks), paste0('Num.sitelinks: ', vsnames$numSitelinks, '.'), "")
                         ), 
                         size = ifelse(!is.na(vsnames$item_count), vsnames$item_count, 10),
                         sizes = c(10, 300),
                         color = cc,
                         hoverinfo = "text")
      edge_shapes <- list()
      incProgress(4/7, detail = "Rendering graph. Please be patient.")
      for (i in 1:Ne) {
        v0 <- es[i, ]$V1
        v1 <- es[i, ]$V2
        edge_shape = list(
          type = "line",
          line = list(color = "#030303", width = 0.3),
          x0 = Xn[which(L$name == v0)],
          y0 = Yn[which(L$name == v0)],
          x1 = Xn[which(L$name == v1)],
          y1 = Yn[which(L$name == v1)]
        )
        edge_shapes[[i]] <- edge_shape
      }
      axis <- list(title = "", 
                   showgrid = FALSE, 
                   showticklabels = FALSE, 
                   zeroline = FALSE)
      incProgress(5/7, detail = "Rendering graph. Please be patient.")
      p <- layout(
        network,
        shapes = edge_shapes,
        xaxis = axis,
        yaxis = axis
      )
      incProgress(6/7, detail = "Rendering graph. Please be patient.")
      ggplotly(p) %>%
        plotly::config(displayModeBar = TRUE,
                       displaylogo = FALSE,
                       collaborate = FALSE,
                       modeBarButtonsToRemove = list(
                         'lasso2d',
                         'select2d',
                         'toggleSpikelines',
                         'hoverClosestCartesian',
                         'hoverCompareCartesian',
                         'autoScale2d'
                       ))  %>%
        hide_legend()
    })
  })
  
  
  output$similarityGraph_Static <- renderPlot({
    
    withProgress(message = 'Generating Network.', detail = "Please be patient.", value = 0, {
      
      incProgress(1/3, detail = "Prepare data structures.")
      
      # - similarity matrix
      simMatrix <- as.matrix(simData[, 1:(dim(simData)[1])])
      rownames(simMatrix) <- colnames(simMatrix)
      nns <- vector(mode = "list", length = dim(simMatrix)[1])
      for (i in 1:(dim(simMatrix)[1])) {
        lan <- simMatrix[i, ]
        from = names(lan)[i]
        ix <- setdiff(1:length(lan), i)
        lan <- lan[ix]
        w <- which.max(lan)
        nns[[i]] <- data.frame(outgoing = from, 
                               incoming = names(lan)[w], 
                               stringsAsFactors = F)
      }
      nns <- rbindlist(nns)
      
      # - Visualize w. {igraph}
      connected <- graph.data.frame(nns[, c('outgoing', 'incoming')], directed = T)
      
      incProgress(2/3, detail = "Compute graph layout.")
      
      # - layout
      cc <- cluster_edge_betweenness(as.undirected(connected)) 

      # - plot w. {igraph}
      
      incProgress(3/3, detail = "Render graphics.")
      
      par(mai=c(rep(0,4)))
      plot(cc, connected,
           edge.width = .75,
           edge.color = "grey40",
           edge.arrow.size = 0.1,
           edge.curved = 0.5,
           vertex.color = NULL,
           vertex.label.color = "black",
           vertex.label.family = "sans",
           # vertex.label.font = "Helvetica",
           vertex.label.cex = 1,
           vertex.size = 0)
      
    })
  })
  
  ### ------------------------------------------
  ### --- TAB: tabPanel Status
  ### ------------------------------------------
  
  # - file: WD_Vis_UNESCO Language Status_Sitelinks.csv
  output$status_UNESCO_Sitelinks <- renderPlotly({
    pFrame <- status_UNESCO_Sitelinks
    g <- ggplot(data = pFrame,
                aes(x = `UNESCO Language Status`,
                    y = Sitelinks,
                    color = `UNESCO Language Status`,
                    label = Language,
                    size = Sitelinks,
                    alpha = Sitelinks)) +
      geom_jitter(width = .1, fill = "white") +
      ggtitle("UNESCO Language Status and Sitelinks") + 
      theme_classic() + 
      theme(axis.line.y = element_blank()) +
      theme(axis.line.x = element_blank()) +
      theme(plot.title = element_text(size = 12, hjust = .5)) +
      theme(axis.text.y = element_text(hjust = .95, size = 11)) +
      theme(axis.text.x = element_text(angle = 90, hjust = .95, size = 11)) + 
      theme(axis.title.y =  element_text(hjust = .5, size = 11)) +
      theme(axis.title.x =  element_text(hjust = .5, size = 11)) +
      theme(legend.title = element_blank())
    ggplotly(g, tooltip = c("label", "x", "size")) %>% 
      plotly::config(displayModeBar = TRUE,
                     displaylogo = FALSE,
                     collaborate = FALSE,
                     modeBarButtonsToRemove = list(
                       'lasso2d',
                       'select2d',
                       'toggleSpikelines',
                       'hoverClosestCartesian',
                       'hoverCompareCartesian',
                       'autoScale2d'
                     ))
  })
  
  # - file: WD_Vis_EthnologueLanguageStatus_Sitelinks.csv
  output$status_Ethnologue_Sitelinks <- renderPlotly({
    pFrame <- status_Ethnologue_Sitelinks
    g <- ggplot(data = pFrame,
                aes(x = `Ethnologue Language Status`,
                    y = Sitelinks,
                    color = `Ethnologue Language Status`,
                    label = Language,
                    size = Sitelinks,
                    alpha = Sitelinks)) +
      geom_jitter(width = .1, fill = "white") +
      ggtitle("Ethnologue Language Status and Sitelinks") + 
      theme_classic() + 
      theme(axis.line.y = element_blank()) +
      theme(axis.line.x = element_blank()) +
      theme(plot.title = element_text(size = 12, hjust = .5)) +
      theme(axis.text.y = element_text(hjust = .95, size = 11)) +
      theme(axis.text.x = element_text(angle = 90, hjust = .95, size = 11)) + 
      theme(axis.title.y =  element_text(hjust = .5, size = 11)) +
      theme(axis.title.x =  element_text(hjust = .5, size = 11)) +
      theme(legend.title = element_blank())
    ggplotly(g, tooltip = c("label", "x", "size")) %>% 
      plotly::config(displayModeBar = TRUE,
                     displaylogo = FALSE,
                     collaborate = FALSE,
                     modeBarButtonsToRemove = list(
                       'lasso2d',
                       'select2d',
                       'toggleSpikelines',
                       'hoverClosestCartesian',
                       'hoverCompareCartesian',
                       'autoScale2d'
                       ))
  })
  
  # - file: WD_Vis_UNESCO Language Status_NumItems.csv
  output$status_UNESCO_numItems <- renderPlotly({
    pFrame <- status_UNESCO_numItems
    g <- ggplot(data = pFrame,
                aes(x = `UNESCO Language Status`,
                    y = log(Labels),
                    color = `UNESCO Language Status`,
                    label = Language,
                    size = Labels,
                    alpha = log(Labels))) +
      geom_jitter(width = .1, fill = "white") +
      ggtitle("UNESCO Language Status and Labels") + 
      theme_classic() + 
      theme(axis.line.y = element_blank()) +
      theme(axis.line.x = element_blank()) +
      theme(plot.title = element_text(size = 12, hjust = .5)) +
      theme(axis.text.y = element_text(hjust = .95, size = 11)) +
      theme(axis.text.x = element_text(angle = 90, hjust = .95, size = 11)) + 
      theme(axis.title.y =  element_text(hjust = .5, size = 11)) +
      theme(axis.title.x =  element_text(hjust = .5, size = 11)) +
      theme(legend.title = element_blank())
    ggplotly(g, tooltip = c("label", "x", "size")) %>% 
      plotly::config(displayModeBar = TRUE,
                     displaylogo = FALSE,
                     collaborate = FALSE,
                     modeBarButtonsToRemove = list(
                       'lasso2d',
                       'select2d',
                       'toggleSpikelines',
                       'hoverClosestCartesian',
                       'hoverCompareCartesian',
                       'autoScale2d'
                     ))
  })
  
  # - file: WD_Vis_Ethnologue Language Status_NumItems.csv
  output$status_Ethnologue_numItems <- renderPlotly({
    pFrame <- status_Ethnologue_numItems
    g <- ggplot(data = pFrame,
                aes(x = `Ethnologue Language Status`,
                    y = log(Labels),
                    color = `Ethnologue Language Status`,
                    size = Labels,
                    label = Language,
                    alpha = log(Labels))) +
      geom_jitter(width = .1, fill = "white") +
      ggtitle("Ethnologue Language Status and Labels") + 
      theme_classic() + 
      theme(axis.line.y = element_blank()) +
      theme(axis.line.x = element_blank()) +
      theme(plot.title = element_text(size = 12, hjust = .5)) +
      theme(axis.text.y = element_text(hjust = .95, size = 11)) +
      theme(axis.text.x = element_text(angle = 90, hjust = .95, size = 11)) + 
      theme(axis.title.y =  element_text(hjust = .5, size = 11)) +
      theme(axis.title.x =  element_text(hjust = .5, size = 11)) +
      theme(legend.title = element_blank())
    ggplotly(g, tooltip = c("label", "x", "size")) %>% 
      plotly::config(displayModeBar = TRUE,
                     displaylogo = FALSE,
                     collaborate = FALSE,
                     modeBarButtonsToRemove = list(
                       'lasso2d',
                       'select2d',
                       'toggleSpikelines',
                       'hoverClosestCartesian',
                       'hoverCompareCartesian',
                       'autoScale2d'
                     ))
  })
  
  # - file: WD_Vis_UNESCO Language Status_ItemReuse.csv
  output$status_UNESCO_reuse <- renderPlotly({
    pFrame <- status_UNESCO_reuse
    g <- ggplot(data = pFrame,
                aes(x = `UNESCO Language Status`,
                    y = log(Reuse),
                    text = paste0("WDCM Reuse statistic: ", Reuse),
                    color = `UNESCO Language Status`,
                    size = log(`Items Reused`/Items),
                    label = Language,
                    alpha = log(`Items Reused`/Items))) +
      geom_jitter(width = .1, fill = "white") +
      ggtitle("UNESCO Language Status and Item Reuse") + 
      scale_size_area(max_size = 4) +
      theme_classic() + 
      theme(axis.line.y = element_blank()) +
      theme(axis.line.x = element_blank()) +
      theme(plot.title = element_text(size = 12, hjust = .5)) +
      theme(axis.text.y = element_text(hjust = .95, size = 11)) +
      theme(axis.text.x = element_text(angle = 90, hjust = .95, size = 11)) + 
      theme(axis.title.y =  element_text(hjust = .5, size = 11)) +
      theme(axis.title.x =  element_text(hjust = .5, size = 11)) +
      theme(legend.title = element_blank())
    ggplotly(g, tooltip = c("label", "x", "text")) %>% 
      plotly::config(displayModeBar = TRUE,
                     displaylogo = FALSE,
                     collaborate = FALSE,
                     modeBarButtonsToRemove = list(
                       'lasso2d',
                       'select2d',
                       'toggleSpikelines',
                       'hoverClosestCartesian',
                       'hoverCompareCartesian',
                       'autoScale2d'
                     ))
  })
  
  # - file: WD_Vis_Ethnologue Language Status_ItemReuse.csv
  output$status_Ethnologue_reuse <- renderPlotly({
    pFrame <- status_Ethnologue_reuse
    g <- ggplot(data = pFrame,
                aes(x = `Ethnologue Language Status`,
                    y = log(Reuse),
                    text = paste0("WDCM Reuse statistic: ", Reuse),
                    color = `Ethnologue Language Status`,
                    size = log(`Items Reused`/Items),
                    label = Language,
                    alpha = log(`Items Reused`/Items))) +
      geom_jitter(width = .1, fill = "white") +
      ggtitle("Ethnologue Language Status and Item Reuse") + 
      scale_size_area(max_size = 4) +
      theme_classic() + 
      theme(axis.line.y = element_blank()) +
      theme(axis.line.x = element_blank()) +
      theme(plot.title = element_text(size = 12, hjust = .5)) +
      theme(axis.text.y = element_text(hjust = .95, size = 11)) +
      theme(axis.text.x = element_text(angle = 90, hjust = .95, size = 11)) + 
      theme(axis.title.y =  element_text(hjust = .5, size = 11)) +
      theme(axis.title.x =  element_text(hjust = .5, size = 11)) +
      theme(legend.title = element_blank())
    ggplotly(g, tooltip = c("label", "x", "text")) %>% 
      plotly::config(displayModeBar = TRUE,
                     displaylogo = FALSE,
                     collaborate = FALSE,
                     modeBarButtonsToRemove = list(
                       'lasso2d',
                       'select2d',
                       'toggleSpikelines',
                       'hoverClosestCartesian',
                       'hoverCompareCartesian',
                       'autoScale2d'
                     ))
  })
  
  ### ------------------------------------------
  ### --- TAB: tabPanel Usage
  ### ------------------------------------------
  
  # - file: wd_languages_count.csv
  output$labels_Reuse <- renderPlotly({
    pFrame <- dataSet
    g <- ggplot(data = pFrame,
           aes(x = item_count,
               y = reuse,
               text = paste0("WDCM Reuse statistic: ", reuse),
               color = reuse,
               size = reuse,
               label = language,
               alpha = reuse)) + 
      geom_point() +
      scale_x_continuous(labels = comma) + 
      scale_y_continuous(labels = comma) + 
      scale_colour_gradient(low = "tomato", high = "firebrick", aesthetics = "colour") + 
      scale_size_area(max_size = 4) +
      xlab("Number of items per language") + 
      ylab("Total item reuse per language") +
      theme_minimal() + 
      theme(legend.position = "none") + 
      ggtitle("Item Count vs WDCM Reuse Statistics") + 
      theme_classic() + 
      theme(axis.line.y = element_blank()) +
      theme(axis.line.x = element_blank()) +
      theme(plot.title = element_text(size = 12, hjust = .5)) +
      theme(axis.text.y = element_text(hjust = .95, size = 11)) +
      theme(axis.text.x = element_text(angle = 90, hjust = .95, size = 11)) + 
      theme(axis.title.y =  element_text(hjust = .5, size = 11)) +
      theme(axis.title.x =  element_text(hjust = .5, size = 11)) +
      theme(legend.title = element_blank())
    ggplotly(g, tooltip = c("label", "x", "text")) %>% 
      plotly::config(displayModeBar = TRUE,
                     displaylogo = FALSE,
                     collaborate = FALSE,
                     modeBarButtonsToRemove = list(
                       'lasso2d',
                       'select2d',
                       'toggleSpikelines',
                       'hoverClosestCartesian',
                       'hoverCompareCartesian',
                       'autoScale2d'
                     ))
  })
  
  # - file: wd_languages_count.csv
  output$log_labels_Reuse <- renderPlotly({
    pFrame <- dataSet
    g <- ggplot(data = pFrame,
                aes(x = log(item_count),
                    y = log(reuse),
                    label = language,
                    text = paste0("WDCM Reuse statistic: ", reuse),
                    color = reuse,
                    size = reuse,
                    alpha = reuse)) + 
      geom_point() +
      scale_x_continuous(labels = comma) + 
      scale_y_continuous(labels = comma) + 
      scale_colour_gradient(low = "tomato", high = "firebrick", aesthetics = "colour") + 
      scale_size_area(max_size = 4) +
      xlab("Number of items per language (log)") + 
      ylab("Total item reuse per language (log)") +
      theme_minimal() + 
      theme(legend.position = "none") + 
      ggtitle("Item Count vs WDCM Reuse Statistics (log space)") + 
      theme_classic() + 
      theme(axis.line.y = element_blank()) +
      theme(axis.line.x = element_blank()) +
      theme(plot.title = element_text(size = 12, hjust = .5)) +
      theme(axis.text.y = element_text(hjust = .95, size = 11)) +
      theme(axis.text.x = element_text(angle = 90, hjust = .95, size = 11)) + 
      theme(axis.title.y =  element_text(hjust = .5, size = 11)) +
      theme(axis.title.x =  element_text(hjust = .5, size = 11)) +
      theme(legend.title = element_blank())
    ggplotly(g, tooltip = c("label", "x", "text")) %>% 
      plotly::config(displayModeBar = TRUE,
                     displaylogo = FALSE,
                     collaborate = FALSE,
                     modeBarButtonsToRemove = list(
                       'lasso2d',
                       'select2d',
                       'toggleSpikelines',
                       'hoverClosestCartesian',
                       'hoverCompareCartesian',
                       'autoScale2d'
                     ))
  })
  
  # - file: wd_languages_count.csv
  output$itemCount_avgReuse <- renderPlotly({
    pFrame <- dataSet
    g <- ggplot(data = pFrame,
           aes(x = log(item_count),
               y = log(avg_reuse_per_item),
               label = language,
               text = paste0("avg. WDCM Reuse statistic: ", round(avg_reuse_per_item, 2)),
               color = avg_reuse_per_item,
               size = avg_reuse_per_item,
               alpha = log(avg_reuse_per_item))) + 
      geom_point() +
      scale_x_continuous(labels = comma) + 
      scale_y_continuous(labels = comma) + 
      scale_colour_gradient(low = "lightblue", high = "cadetblue4", aesthetics = "colour") + 
      scale_size_area(max_size = 4) +
      xlab("Number of items per language (log)") + 
      ylab("Average item reuse per language (log)") +
      theme_minimal() + 
      theme(legend.position = "none") + 
      ggtitle("Item Count vs Average Reuse (log space)") + 
      theme_classic() + 
      theme(axis.line.y = element_blank()) +
      theme(axis.line.x = element_blank()) +
      theme(plot.title = element_text(size = 12, hjust = .5)) +
      theme(axis.text.y = element_text(hjust = .95, size = 11)) +
      theme(axis.text.x = element_text(angle = 90, hjust = .95, size = 11)) + 
      theme(axis.title.y =  element_text(hjust = .5, size = 11)) +
      theme(axis.title.x =  element_text(hjust = .5, size = 11)) +
      theme(legend.title = element_blank())
    ggplotly(g, tooltip = c("label", "x", "text")) %>% 
      plotly::config(displayModeBar = TRUE,
                     displaylogo = FALSE,
                     collaborate = FALSE,
                     modeBarButtonsToRemove = list(
                       'lasso2d',
                       'select2d',
                       'toggleSpikelines',
                       'hoverClosestCartesian',
                       'hoverCompareCartesian',
                       'autoScale2d'
                     ))
  })
  
  # - file: wd_languages_count.csv
  output$itemCount_propReused <- renderPlotly({
    pFrame <- dataSet
    g <- ggplot(data = dataSet,
           aes(x = log(item_count),
               y = prop_items_used*100,
               label = language,
               text = paste0("% of items reused: ", round(prop_items_used*100, 2)),
               color = prop_items_used,
               size = prop_items_used,
               alpha = prop_items_used)) + 
      geom_point() +
      scale_x_continuous(labels = comma) + 
      scale_y_continuous(labels = comma, limits=c(0, 100)) + 
      scale_colour_gradient(low = "yellow", high = "orange", aesthetics = "colour") + 
      scale_size_area(max_size = 4) +
      xlab("Number of items per language (log)") + 
      ylab("% of items reused per language") +
      theme_minimal() + 
      theme(legend.position = "none") + 
      ggtitle("Item Count vs % of Items Reused (log space)") + 
      theme_classic() + 
      theme(axis.line.y = element_blank()) +
      theme(axis.line.x = element_blank()) +
      theme(plot.title = element_text(size = 12, hjust = .5)) +
      theme(axis.text.y = element_text(hjust = .95, size = 11)) +
      theme(axis.text.x = element_text(angle = 90, hjust = .95, size = 11)) + 
      theme(axis.title.y =  element_text(hjust = .5, size = 11)) +
      theme(axis.title.x =  element_text(hjust = .5, size = 11)) +
      theme(legend.title = element_blank())
    ggplotly(g, tooltip = c("label", "x", "text")) %>% 
      plotly::config(displayModeBar = TRUE,
                     displaylogo = FALSE,
                     collaborate = FALSE,
                     modeBarButtonsToRemove = list(
                       'lasso2d',
                       'select2d',
                       'toggleSpikelines',
                       'hoverClosestCartesian',
                       'hoverCompareCartesian',
                       'autoScale2d'
                     ))
  })
  
}) ### --- END shinyServer
