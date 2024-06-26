#' abiDashboard UI Function
#'
#' @description A shiny Module.
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @noRd
#'
#' @importFrom shiny NS tagList
mod_abiDashboard_ui <- function(id){
  ns <- NS(id)
  tagList(

    mainPanel(width = 12,
              tabsetPanel( id=ns("tabsMain"),
                           type = "tabs",
                           tabPanel(div(icon("arrow-right-to-bracket"), "Input"),
                                    tabsetPanel(
                                      tabPanel("Pick time stamps", icon = icon("magnifying-glass-chart"),
                                               br(),
                                               column(width=12,
                                                      column(width=5,  selectInput(ns("versionSelection"), "OCS analysis (to trace selection history)", choices = NULL, multiple = FALSE) ),
                                                      column(width=5,  selectInput(ns("versionHistory"), "RGG analysis (to link gain)", choices = NULL, multiple = FALSE) ),
                                                      column(width=2, tags$br(),
                                                             shinyWidgets::prettySwitch( inputId = ns('launch'), label = "Load example", status = "success"),
                                                      ),
                                                      style = "background-color:grey; color: #FFFFFF"),
                                               hr(style = "border-top: 3px solid #4c4c4c;"),
                                               h5(strong(span("The visualizations of the input-data located below will not affect your analysis but may help you pick the right input-parameter values to be specified in the grey boxes above.", style="color:green"))),
                                               hr(style = "border-top: 3px solid #4c4c4c;"),
                                               # shinydashboard::box(status="success",width = 12, style = "height:460px; overflow-y: scroll;overflow-x: scroll;", solidHeader = TRUE,
                                               #                     column(width=12,
                                               # p(span("Current analyses available.", style="color:black")),
                                               shiny::plotOutput(ns("plotTimeStamps")),
                                               # p(span("Data used as input.", style="color:black")),
                                               # DT::DTOutput(ns("phenoAbi")),
                                               #                     )
                                               # ),
                                      ),
                                      tabPanel("Build dashboard", icon = icon("play"),
                                               br(),
                                               actionButton(ns("runAbi"), "Build dashboard", icon = icon("play-circle")),
                                               uiOutput(ns("qaQcAbiInfo")),
                                               textOutput(ns("outAbi")),
                                      ),
                                    )
                           ),
                           tabPanel(div(icon("arrow-right-from-bracket"), "Output" ) , value = "outputTabs",
                                    tabsetPanel(
                                      tabPanel("Dashboard", icon = icon("file-image"),
                                               br(),
                                               downloadButton(ns("downloadReportAbi"), "Download dashboard"),
                                               br(),
                                               uiOutput(ns('reportAbi'))
                                      )
                                    )
                           )
              )) # end mainpanel

  )
}

#' abiDashboard Server Functions
#'
#' @noRd
mod_abiDashboard_server <- function(id, data){
  moduleServer( id, function(input, output, session){
    ns <- session$ns

    ############################################################################ clear the console
    hideAll <- reactiveValues(clearAll = TRUE)
    observeEvent(data(), {
      hideAll$clearAll <- TRUE
    })
    ############################################################################
    #################
    ## data example loading
    observeEvent(
      input$launch,
      if(length(input$launch) > 0){
        if (input$launch) {
          shinyWidgets::ask_confirmation(
            inputId = ns("myconfirmation"),
            text = "Are you sure you want to load the example data? This will delete any data currently in the environment.",
            title = "Data replacement warning"
          )
        }
      }
    )
    observeEvent(input$myconfirmation, {
      if (isTRUE(input$myconfirmation)) {
        shinybusy::show_modal_spinner('fading-circle', text = 'Loading example...')
        ## replace tables
        data(cgiarBase::create_getData_object())
        tmp <- data()
        utils::data(DT_example, package = "cgiarPipeline")
        if(!is.null(result$data)){tmp$data <- result$data}
        if(!is.null(result$metadata)){tmp$metadata <- result$metadata}
        if(!is.null(result$modifications)){tmp$modifications <- result$modifications}
        if(!is.null(result$predictions)){tmp$predictions <- result$predictions}
        if(!is.null(result$metrics)){tmp$metrics <- result$metrics}
        if(!is.null(result$modeling)){tmp$modeling <- result$modeling}
        if(!is.null(result$status)){tmp$status <- result$status}
        data(tmp) # update data with results
        shinybusy::remove_modal_spinner()
      }else{
        shinyWidgets::updatePrettySwitch(session, "launch", value = FALSE)
      }
    }, ignoreNULL = TRUE)

    ## versions to use
    observeEvent(c(data()), {
      req(data())
      dtAbi <- data()
      dtAbi <- dtAbi$status
      if(!is.null(dtAbi)){
        dtAbi <- dtAbi[which(dtAbi$module %in% c("ocs")),]
        traitsAbi <- unique(dtAbi$analysisId)
        if(length(traitsAbi) > 0){names(traitsAbi) <- as.POSIXct(traitsAbi, origin="1970-01-01", tz="GMT")}
        updateSelectInput(session, "versionSelection", choices = traitsAbi)
      }
    })
    observeEvent(c(data()), {
      req(data())
      dtAbi <- data()
      dtAbi <- dtAbi$status
      if(!is.null(dtAbi)){
        dtAbi <- dtAbi[which(dtAbi$module %in% c("rgg")),]
        traitsAbi <- unique(dtAbi$analysisId)
        if(length(traitsAbi) > 0){names(traitsAbi) <- as.POSIXct(traitsAbi, origin="1970-01-01", tz="GMT")}
        updateSelectInput(session, "versionHistory", choices = traitsAbi)
      }
    })

    ## render timestamps flow
    output$plotTimeStamps <- shiny::renderPlot({
      req(data()) # req(input$version2Sta)
      xx <- data()$status;  yy <- data()$modeling
      v <- which(yy$parameter == "analysisId")
      if(length(v) > 0){
        yy <- yy[v,c("analysisId","value")]
        zz <- merge(xx,yy, by="analysisId", all.x = TRUE)
      }else{ zz <- xx; zz$value <- NA}
      if(!is.null(xx)){
        colnames(zz) <- cgiarBase::replaceValues(colnames(zz), Search = c("analysisId","value"), Replace = c("outputId","inputId") )
        nLevelsCheck1 <- length(na.omit(unique(zz$outputId)))
        nLevelsCheck2 <- length(na.omit(unique(zz$inputId)))
        if(nLevelsCheck1 > 1 & nLevelsCheck2 > 1){
          X <- with(zz, sommer::overlay(outputId, inputId))
        }else{
          if(nLevelsCheck1 <= 1){
            X1 <- matrix(ifelse(is.na(zz$inputId),0,1),nrow=length(zz$inputId),1); colnames(X1) <- as.character(na.omit(unique(c(zz$outputId))))
          }else{X1 <- model.matrix(~as.factor(outputId)-1, data=zz); colnames(X1) <- levels(as.factor(zz$outputId))}
          if(nLevelsCheck2 <= 1){
            X2 <- matrix(ifelse(is.na(zz$inputId),0,1),nrow=length(zz$inputId),1); colnames(X2) <- as.character(na.omit(unique(c(zz$inputId))))
          }else{X2 <- model.matrix(~as.factor(inputId)-1, data=zz); colnames(X2) <- levels(as.factor(zz$inputId))}
          mynames <- unique(na.omit(c(zz$outputId,zz$inputId)))
          X <- matrix(0, nrow=nrow(zz), ncol=length(mynames)); colnames(X) <- as.character(mynames)
          if(!is.null(X1)){X[,colnames(X1)] <- X1}
          if(!is.null(X2)){X[,colnames(X2)] <- X2}
        };  rownames(X) <- as.character(zz$outputId)
        rownames(X) <-as.character(as.POSIXct(as.numeric(rownames(X)), origin="1970-01-01", tz="GMT"))
        colnames(X) <-as.character(as.POSIXct(as.numeric(colnames(X)), origin="1970-01-01", tz="GMT"))
        # make the network plot
        n <- network::network(X, directed = FALSE)
        network::set.vertex.attribute(n,"family",zz$module)
        network::set.vertex.attribute(n,"importance",1)
        e <- network::network.edgecount(n)
        network::set.edge.attribute(n, "type", sample(letters[26], e, replace = TRUE))
        network::set.edge.attribute(n, "day", sample(1, e, replace = TRUE))
        library(ggnetwork)
        ggplot2::ggplot(n, ggplot2::aes(x = x, y = y, xend = xend, yend = yend)) +
          ggnetwork::geom_edges(ggplot2::aes(color = family), arrow = ggplot2::arrow(length = ggnetwork::unit(6, "pt"), type = "closed") ) +
          ggnetwork::geom_nodes(ggplot2::aes(color = family), alpha = 0.5, size=5 ) +
          ggnetwork::geom_nodelabel_repel(ggplot2::aes(color = family, label = vertex.names ),
                                          fontface = "bold", box.padding = ggnetwork::unit(1, "lines")) +
          ggnetwork::theme_blank() + ggplot2::ggtitle("Network plot of current analyses available")
      }
    })

    #################################
    ### ANALYSIS

    ## render result of "run" button click
    outAbi <- eventReactive(input$runAbi, {
      req(data())
      # req(input$versionMetrics) # minimum requirements for the dashboard is the data and sta
      shinybusy::show_modal_spinner('fading-circle', text = 'Processing...')
      result <- data()
      idAbi <- as.numeric(Sys.time())
      abiModeling <- data.frame(module="abiDash", analysisId=idAbi, trait="inputObject", environment=NA,
                                parameter= c( "ocs", "rgg") , # "sta", "mta","indexD",
                                value=c(input$versionSelection, input$versionHistory ) # input$versionMetrics, input$versionTraits, input$versionIndex,
      )
      abiStatus <- data.frame(module="abiDash", analysisId=idAbi)
      result$modeling <- rbind(result$modeling, abiModeling)
      result$status <- rbind(result$status, abiStatus)

      shinybusy::remove_modal_spinner()
      if(!inherits(result,"try-error")) {
        data(result) # update data with results
        cat("Data ready for dashboard. Please go to the report tab.")
        updateTabsetPanel(session, "tabsMain", selected = "outputTabs")
      }else{
        cat(paste("Analysis failed with the following error message: \n\n",result[[1]]))
      }
      ##

      if(!inherits(result,"try-error")) {

        ## Report tab
        output$reportAbi <- renderUI({
          HTML(markdown::markdownToHTML(knitr::knit(system.file("rmd","reportAbi.Rmd",package="bioflow"), quiet = TRUE), fragment.only=TRUE))
        })

        output$downloadReportAbi <- downloadHandler(
          filename = function() {
            paste('my-report', sep = '.', switch(
              "HTML", PDF = 'pdf', HTML = 'html', Word = 'docx'
            ))
          },
          content = function(file) {
            src <- normalizePath(system.file("rmd","reportAbi.Rmd",package="bioflow"))
            src2 <- normalizePath('data/resultAbi.RData')
            # temporarily switch to the temp dir, in case you do not have write
            # permission to the current working directory
            owd <- setwd(tempdir())
            on.exit(setwd(owd))
            file.copy(src, 'report.Rmd', overwrite = TRUE)
            file.copy(src2, 'resultAbi.RData', overwrite = TRUE)
            out <- rmarkdown::render('report.Rmd',
                                     params = list(toDownload=TRUE ),
                                     switch(
                                       "HTML",
                                       HTML = rmdformats::robobook(toc_depth = 4)
                                       # HTML = rmarkdown::html_document()
                                     ))
            file.rename(out, file)
          }
        )

      } else {

      }

      hideAll$clearAll <- FALSE

    }) ## end eventReactive

    output$outAbi <- renderPrint({
      outAbi()
    })

  })
}

## To be copied in the UI
# mod_abiDashboard_ui("abiDashboard_1")

## To be copied in the server
# mod_abiDashboard_server("abiDashboard_1")
