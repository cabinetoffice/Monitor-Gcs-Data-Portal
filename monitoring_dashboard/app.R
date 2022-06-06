library(shiny)
library(magrittr)
source("~/Codes/Monitor-Gcs-Data-Portal/monitoring_dashboard/functions.R")

debug_mode <- F

setS3AuthenticationMMD()

if(debug_mode){
  df_prometheus <- df_prometheus
} else {
  df_prometheus <- getPrometheusDataset()
}

ui <- fluidPage(

    # Application title
    titlePanel("GCS Data Portal 2022 - Monitoring"),
    plotly::plotlyOutput("portal_availability")
)

# Define server logic required to draw a histogram
server <- function(input, output) {

    output$portal_availability <- plotly::renderPlotly({

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
        plotly::layout(yaxis = list(tickformat = ".0%",  range = c(0, 1)))
    })
}

# Run the application
shinyApp(ui = ui, server = server)
