url_prometheus <- "https://prometheus-exporter-reshaping-gcs.london.cloudapps.digital/metrics"

sysdatetime <- Sys.time() %>% 
  format("%Y-%m-%d_%H-%M-%S_%Z")

t <- httr::GET(url_prometheus)

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
    measure = stringr::str_extract(HELP, pattern = "# HELP .*? ") %>% 
      stringr::str_replace_all(pattern = '# HELP ', replacement = ''),
    measure_description = stringr::str_extract(HELP, pattern = paste0(measure, ".*")) %>% 
      stringr::str_replace_all(pattern = measure, replacement = '') %>% 
      stringr::str_trim(),
    value =  stringr::str_extract(CONTENT, pattern = "\\}.*") %>% 
      stringr::str_replace_all(pattern = "\\}", replacement = '') %>% 
      stringr::str_trim()
  )

df_gcsdataportal <- 
  u %>% 
  dplyr::filter(app_name == "gcsdataportal")


# Write to S3 ####

auth <- jsonlite::read_json("~/Codes/Analysis_RGCS/s3_auth_mmd.json")

Sys.setenv(
  "AWS_ACCESS_KEY_ID" = auth$aws_access_key_id,
  "AWS_SECRET_ACCESS_KEY" = auth$aws_secret_access_key,
  "AWS_DEFAULT_REGION" = auth$aws_region
)

bucket = "ashley-poole-rgcs"

aws.s3::s3write_using(
                     df_gcsdataportal,
                     readr::write_excel_csv,
                     object = paste0("gcsdataportal_prometheus/raw/", sysdatetime, ".csv"),
                     bucket = bucket)