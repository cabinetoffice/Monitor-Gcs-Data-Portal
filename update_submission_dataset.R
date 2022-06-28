are_new_submissions_available <- RGCS::checkForNewPassedSubmission()

if(are_new_submissions_available){
  RGCS::uploadLatestCleanSubmissions()
} else {
  ## If there are no new submissions, do nothing.
}
