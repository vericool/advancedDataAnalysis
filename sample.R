# Loading the libraries

library(lubridate)
library(data.table)
library(dplyr)
library(openxlsx)
library(tidyr)
library(fst)
library(stringi)
library(zoo)
library(ggplot2)
library(scales)
library(tibble)
library(RMySQL)
library(pbapply)

# Connecting to the database

connection = dbConnect(drv = MySQL(),
                       user = "fallenangel1",
                       password = 'nvoevodin',
                       host = 'nikitatest.ctxqlb5xlcju.us-east-2.rds.amazonaws.com',
                       port = 3306,
                       dbname = 'nikita99')



today <- '2018-01-02'

lastVins <- dbGetQuery(connection, paste("SELECT
`expiration date`,
`base type`,
`vehicle vin number` as vin,
first_seen as date
FROM book_table
where first_seen = '", today,"'",
                                         sep = ""))


lastVins$vin <- trimws(lastVins$vin)

vinVector <- lastVins$vin


# Writing a function to call the api

return_vins <-  function(my_vin){
  vinme <- paste0('https://vpic.nhtsa.dot.gov/api/vehicles/DecodeVinValues/',my_vin,'?format=json')
  vinme = httr::GET(vinme)
  result = jsonlite::fromJSON(httr::content(vinme, as = "text"))
  result = as.data.table(result)
}

# Calling the function and making sure that if there
# is an error ar an empty vin number, the code doesnt
# stop and moves to the next one instead.

# Files are written one by one into the data folder.

vin_results <- pblapply(vinVector,function(empty_vin){

  tricatch_result=
    tryCatch({
      return_vins(empty_vin)

    }, error=function(e){cat("ERROR :",conditionMessage(e), "\n")})


  tryCatch({
    fwrite(tricatch_result,paste0("data/vin",tricatch_result$`Results.VIN`,".csv"))
  }, error=function(e){cat("ERROR :",conditionMessage(e), "\n")})

  Sys.sleep(.001)
  tricatch_result
})

# Binding all the files from the data folder into a
# a data frame

NHTSAtable <- list.files('data/', pattern = '.csv') %>%
  pblapply(function(x){
    read.csv(paste0('data/',x),stringsAsFactors=FALSE)[,c('Results.VIN','Results.Make','Results.Model','Results.ModelYear','Results.FuelTypePrimary','Results.FuelTypeSecondary')]
  }) %>% rbindlist()

unlink("data/*")



colnames(NHTSAtable) <- c('vin','make','model','year','gas1','gas2')

lastVins <- left_join(lastVins,NHTSAtable)


old <- dbGetQuery(connection,"SELECT * FROM fin_book_table")

old <- old[,-1]

colnames(old) <- c('expiration date','vin','year','base type','date','make','model','gas1','gas2')

final <- rbind(old, lastVins)


fwrite(final, paste0('vehiclesComplete ',Sys.Date(),'.csv'))
