setS3AuthenticationMMD <- function(){

  auth <- jsonlite::read_json("~/Codes/Analysis_RGCS/s3_auth_mmd.json")

  Sys.setenv(
    "AWS_ACCESS_KEY_ID" = auth$aws_access_key_id,
    "AWS_SECRET_ACCESS_KEY" = auth$aws_secret_access_key,
    "AWS_DEFAULT_REGION" = auth$aws_region
  )
}

getMMDBucketName <- function(){

  bucket = "ashley-poole-rgcs"

  return(bucket)
}

getAllRawPrometheusData <- function(){

  bucket <- getMMDBucketName()

  list_of_objects <-
    aws.s3::get_bucket(
      bucket,
      prefix = "gcsdataportal_prometheus/raw/"
    )

  list_of_data <-
    list_of_objects %>%
    purrr::map(
      .f = function(object_location){
        aws.s3::s3read_using(
          FUN = readr::read_csv,
          object = object_location,
          bucket = bucket
        )}
    )

  data_names <-
    list_of_objects %>%
    purrr::map(
      .f = function(object){
        object$Key
      }
    )

  names(list_of_data) <- data_names

  return(list_of_data)

}

getPrometheusDataset <- function(){

  aws.s3::s3read_using(
    readr::read_csv,
    object = "gcsdataportal_prometheus/clean/compiled.csv",
    bucket = getMMDBucketName()
  ) %>%
    dplyr::mutate(timestamp = lubridate::as_datetime(timestamp))

}

