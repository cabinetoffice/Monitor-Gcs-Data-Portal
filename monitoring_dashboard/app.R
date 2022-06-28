library(shiny)
library(magrittr)
source("~/Codes/Monitor-Gcs-Data-Portal/monitoring_dashboard/functions.R")

debug_mode <- F

RGCS::setS3AuthenticationMMD()

df_prometheus <- getPrometheusDataset()

df_submissions <- RGCS::makeSubmissionSummary2()

ui <- fluidPage(

    # Application title
    titlePanel("GCS Data Portal - Monitoring"),
    shiny::tabsetPanel(
      shiny::tabPanel(
        "Submissions",
        shiny::dataTableOutput("submission_table")
      ),
      shiny::tabPanel(
        "Web app",
        shiny::br(),
        shiny::fluidRow(
          shiny::column(
            width = 6,
            plotly::plotlyOutput("portal_requests")
          ),
          shiny::column(
            width = 6,
            plotly::plotlyOutput("portal_mem_util"),
          ),
          shiny::br(),
        ),
        shiny::fluidRow(
          shiny::column(
            width = 6,
            plotly::plotlyOutput("portal_disk_util")
          ),
          shiny::column(
            width = 6,
            plotly::plotlyOutput("portal_cpu_util")
          ),
          shiny::br()
        )
      )

    )
)

# Define server logic required to draw a histogram
server <- function(input, output) {

    output$portal_cpu_util <- plotly::renderPlotly({

      plot <-
        df_prometheus %>%
          dplyr::filter(measure == "cpu"
                        ) %>%
          plotly::plot_ly(
            x = ~timestamp,
            y = ~value,
            name = ~ instance,
            type = "scatter",
            mode = "lines"
          ) %>%
        plotly::layout(
          yaxis = list(title = "", ticksuffix = "%",  range = c(0, 100)),
          xaxis = list(title = ""),
          title = "CPU Utilisation")

    })

    output$portal_disk_util <- plotly::renderPlotly({

      plot <-
        df_prometheus %>%
        dplyr::filter(measure == "disk_utilization"
        ) %>%
        plotly::plot_ly(
          x = ~timestamp,
          y = ~value,
          name = ~ instance,
          type = "scatter",
          mode = "lines"
        )  %>%
        plotly::layout(
          yaxis = list(title = "", ticksuffix = "%",  range = c(0, 100)),
          xaxis = list(title = ""),
          title = "Disk Utilisation")
    })

    output$portal_mem_util <- plotly::renderPlotly({

      plot <-
        df_prometheus %>%
        dplyr::filter(measure == "memory_utilization"
        ) %>%
        plotly::plot_ly(
          x = ~timestamp,
          y = ~value,
          name = ~ instance,
          type = "scatter",
          mode = "lines"
        )  %>%
        plotly::layout(
          yaxis = list(title = "", ticksuffix = "%",  range = c(0, 100)),
          xaxis = list(title = ""),
          title = "Memory Utilisation")
    })

    output$portal_requests <- plotly::renderPlotly({

      plot <-
        df_prometheus %>%
        dplyr::filter(measure == "requests"
        ) %>%
        dplyr::group_by(instance, timestamp) %>%
        dplyr::summarise(value = sum(value)) %>%
        dplyr::ungroup() %>%
        plotly::plot_ly(
          x = ~timestamp,
          y = ~value,
          name = ~ instance,
          type = "scatter",
          mode = "lines"
        )  %>%
        plotly::layout(
          yaxis = list(title = "Total requests"),
          xaxis = list(title = ""),
          title = "Number of Requests")
    })

    output$submission_table <- shiny::renderDataTable({
      df_submissions
    })

}

# Run the application
shinyApp(ui = ui, server = server)
