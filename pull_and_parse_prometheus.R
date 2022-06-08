library(magrittr)

# Get the latest data ####

url_prometheus <- "https://prometheus-exporter-reshaping-gcs.london.cloudapps.digital/metrics"

sysdatetime <- Sys.time() %>%
  format("%Y-%m-%d_%H-%M-%S_%Z")

t <- httr::GET(url_prometheus)

# Clean the content into a data frame ####

u <-
  httr::content(t, as = "text") %>%
  stringr::str_split(pattern = "\n") %>%
  tibble::as_tibble(.name_repair = janitor::make_clean_names) %>%
  dplyr::rowwise() %>%
  dplyr::mutate(
    row_type = dplyr::case_when(
      stringr::str_detect(x, pattern = "HELP") ~ "HELP",
      stringr::str_detect(x, pattern = "TYPE") ~ "TYPE",
      T ~ "CONTENT"
    )
  ) %>%
  dplyr::ungroup() %>%
  dplyr::mutate(row_num = dplyr::row_number()) %>%
  tidyr::pivot_wider(names_from = "row_type", values_from = "x") %>%
  tidyr::fill(HELP, .direction = "down") %>%
  dplyr::group_by(HELP) %>%
  tidyr::fill(TYPE, .direction = "updown") %>%
  dplyr::ungroup() %>%
  tidyr::drop_na(CONTENT) %>%
  dplyr::rowwise() %>%
  dplyr::mutate(
    app_name = stringr::str_extract(string = CONTENT, pattern = 'app=".*?"') %>%
      stringr::str_replace_all(pattern = '"', replacement = '') %>%
      stringr::str_replace_all(pattern = 'app=', replacement = ''),
    instance = stringr::str_extract(string = CONTENT, pattern = 'instance=".*?"') %>%
      stringr::str_replace_all(pattern = '"', replacement = '') %>%
      stringr::str_replace_all(pattern = 'instance=', replacement = '') %>%
      as.double(),
    measure = stringr::str_extract(HELP, pattern = "# HELP .*? ") %>%
      stringr::str_replace_all(pattern = '# HELP ', replacement = ''),
    measure_description = stringr::str_extract(HELP, pattern = paste0(measure, ".*")) %>%
      stringr::str_replace_all(pattern = measure, replacement = '') %>%
      stringr::str_trim(),
    value =  stringr::str_extract(CONTENT, pattern = "\\}.*") %>%
      stringr::str_replace_all(pattern = "\\}", replacement = '') %>%
      stringr::str_trim() %>%
      as.double()
  )

df_gcsdataportal <-
  u %>%
  dplyr::filter(app_name == "gcsdataportal") %>%
  dplyr::select(
    -c(
      row_num,
      HELP,
      TYPE,
      CONTENT,
      app_name,
      measure_description
    )
  )

# Write the new data to S3 ####

RGCS::setS3AuthenticationMMD()

bucket = "ashley-poole-rgcs"

latest_object <- paste0("gcsdataportal_prometheus/raw/", sysdatetime, ".csv")

aws.s3::s3write_using(
                     df_gcsdataportal,
                     readr::write_excel_csv,
                     object = latest_object,
                     bucket = bucket)

# Compile raw data into a dataset ####

new_entry <-
  df_gcsdataportal %>%
  dplyr::mutate(
    timestamp = as.character(lubridate::as_datetime(sysdatetime))
  )

df_compiled_new <-
  aws.s3::s3read_using(
    FUN = readr::read_csv,
    object = "gcsdataportal_prometheus/clean/compiled.csv",
    bucket = bucket
  ) %>%
  dplyr::bind_rows(new_entry)

aws.s3::s3write_using(
  df_compiled_new,
  FUN = readr::write_excel_csv,
  object = "gcsdataportal_prometheus/clean/compiled.csv",
  bucket = bucket
)
