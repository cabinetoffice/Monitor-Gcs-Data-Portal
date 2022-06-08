list_df <-
  aws.s3::get_bucket(
    bucket = bucket,
    prefix = "gcsdataportal_prometheus/raw/"
  )

df <-
  list_df %>%
  purrr::map(
    .f = function(x){
      aws.s3::s3read_using(
        FUN = readr::read_csv,
        object = x$Key,
        bucket = bucket
        )
    }
  )

data_names <-
  list_df %>%
  purrr::map(
    .f = function(object){
      object$Key
    }
  )

names(df) <- data_names

example <-
  t[1][[1]]

final <-
  example %>%
  dplyr::select(
    -c(
      row_num,
      HELP,
      TYPE,
      CONTENT,
      app_name
    )
  )

list_df %>%
  purrr::map2(
    .y = df,
    .f = function(x, y){

      df_trimmed <-
        y %>%
        dplyr::select(
          -c(
            measure_description
          )
        )

      aws.s3::s3write_using(
        df_trimmed,
        readr::write_excel_csv,
        object = x$Key,
        bucket = bucket
      )
    }
  )

measure_description_lookup <-
  final %>%
  dplyr::select(
    measure,
    measure_description) %>%
  dplyr::distinct()

aws.s3::s3write_using(
  measure_description_lookup,
  FUN = readr::write_excel_csv,
  object = "gcsdataportal_prometheus/clean/measure_description_lookup.csv",
  bucket = bucket
)

compile <-
  df %>%
  dplyr::bind_rows(.id = "file_key") %>%
  dplyr::rowwise() %>%
  dplyr::mutate(
    timestamp = stringr::str_split(file_key, pattern = "/") %>%
      unlist() %>%
      tail(1) %>%
      stringr::str_replace(".csv", "") %>%
      lubridate::as_datetime()
  ) %>%
  dplyr::select(-file_key)

compile <-
  compile %>%
  dplyr::select(-measure_description)

aws.s3::s3write_using(
  compile,
  FUN = readr::write_excel_csv,
  object = "gcsdataportal_prometheus/clean/compiled.csv",
  bucket = bucket
)


# t <- getAllRawPrometheusData()
#
# u <-
#   t %>%
#   dplyr::bind_rows(.id = "filename") %>%
#   dplyr::rowwise() %>%
#   dplyr::mutate(
#     timestamp = stringr::str_split(filename, pattern = "/") %>%
#     unlist() %>%
#     tail(1) %>%
#     stringr::str_replace(".csv", "") %>%
#     lubridate::as_datetime())
#
# v <-
#   u %>%
#   dplyr::select(-filename)
#
# aws.s3::s3write_using(
#   v,
#   FUN = readr::write_excel_csv,
#   object = "gcsdataportal_prometheus/clean/compiled.csv",
#   bucket = bucket
# )
# t <-
#   getPrometheusDataset()
#
#
# df <-
#   t %>%
#   dplyr::select(instance, measure, value, timestamp)
