Intermediate Example
================

### Step 1

First, we are going to load some libraries. You will not need all of
them, but it will save you some time to have all of them loaded anyway.
We are also going to connect to our database.

``` r
# Loading the libraries

  library(lubridate) 
```

    ## 
    ## Attaching package: 'lubridate'

    ## The following object is masked from 'package:base':
    ## 
    ##     date

``` r
  library(data.table) 
```

    ## 
    ## Attaching package: 'data.table'

    ## The following objects are masked from 'package:lubridate':
    ## 
    ##     hour, isoweek, mday, minute, month, quarter, second, wday,
    ##     week, yday, year

``` r
  library(dplyr) 
```

    ## 
    ## Attaching package: 'dplyr'

    ## The following objects are masked from 'package:data.table':
    ## 
    ##     between, first, last

    ## The following objects are masked from 'package:lubridate':
    ## 
    ##     intersect, setdiff, union

    ## The following objects are masked from 'package:stats':
    ## 
    ##     filter, lag

    ## The following objects are masked from 'package:base':
    ## 
    ##     intersect, setdiff, setequal, union

``` r
  library(openxlsx) 
  library(tidyr) 
  library(fst) 
  library(stringi)
  library(zoo) 
```

    ## 
    ## Attaching package: 'zoo'

    ## The following objects are masked from 'package:base':
    ## 
    ##     as.Date, as.Date.numeric

``` r
  library(ggplot2) 
  library(scales) 
  library(tibble) 
  library(RMySQL)
```

    ## Loading required package: DBI

``` r
  library(pbapply)

# Connecting to the database

connection = dbConnect(drv = MySQL(), 
                       user = "fallenangel1", 
                       password = 'nvoevodin', 
                       host = 'nikitatest.ctxqlb5xlcju.us-east-2.rds.amazonaws.com', 
                       port = 3306, 
                       dbname = 'nikita99')
```

### Step 2

Note: Obviously, the data in not updated live. We will be simulating
that part. Today is January 1st 2018. The second table in the database
holds complete vehicles’ records up to the last day of 2017.  

Lets see how many new vehicles we got today. We will assign today’s date
to a variable and then pull the vin numbers from the first table only
for that date.

``` r
today <- '2018-01-02'

lastVins <- dbGetQuery(connection, paste("SELECT 
`expiration date`, 
`base type`,
`vehicle vin number` as vin, 
first_seen as date 
FROM book_table 
where first_seen = '", today,"'
limit 5",
sep = ""))
```

### Step 3

We need to make sure that there are no white spaces around the vin
numbers. After that, we will store the vin numbers in a vector so we
could push it through an API.

``` r
lastVins$vin <- trimws(lastVins$vin)

vinVector <- lastVins$vin
```

### Step 4

Time to retreve the vehicles’ data that we want. For that, we will be
using an API provided by the National Highway Traffic Safety
Administration (NHTSA). The API needs a vector of VIN numbers and
returns a table with many many fields, from which we will only select
the ones that we want.

``` r
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
```

### Step 5

Finally, we are going to pull the second table from the database and
combine it with the data that we just got.

``` r
colnames(NHTSAtable) <- c('vin','make','model','year','gas1','gas2')

lastVins <- left_join(lastVins,NHTSAtable)


old <- dbGetQuery(connection,"SELECT * FROM fin_book_table")

old <- old[,-1]

colnames(old) <- c('expiration date','vin','year','base type','date','make','model','gas1','gas2')

final <- rbind(old, lastVins)
```

### Step 6

Lets write this out as a separate CSV file with today’s date.

``` r
  fwrite(final, paste0('vehiclesComplete ',Sys.Date(),'.csv'))
```

This is it for now\!
