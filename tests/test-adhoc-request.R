# script to analyse the canberra heatwave Jan 2013
# 5-8 january were hot

# get functions
require(plyr)
require(reshape)
#require(devtools)
#install_github("gisviz", username="ivanhanigan")
require(gisviz)
require(rgdal)
#download.file("http://swish-climate-impact-assessment.github.com/tools/swishdbtools/swishdbtools_1.1_R_x86_64-pc-linux-gnu.tar.gz",
#"~/swishdbtools_1.1_R_x86_64-pc-linux-gnu.tar.gz", mode = "wb")
#install.packages("~/swishdbtools_1.1_R_x86_64-pc-linux-gnu.tar.gz", repos = NULL, type = "source")
require(swishdbtools)
ch <- connect2postgres2("ewedb")

# get scope
location <- read.csv("")
head(location)
location <- location$column_name
  #c('12 main street, mossman, qld', "mills and eggleston road, acton, canberra")
for(locn in location)
{
  xy <- gGeoCode2(locn)
print(xy)
  

# 
# r <- readGDAL(sprintf("PG:host=115.146.84.135 port=5432 dbname='ewedb' user='gislibrary' password='%s' schema='awap_grids' table=maxave_20130108", pwd))
# image(r)
# with(xy, points(as.numeric(as.character(long)), as.numeric(as.character(lat))))

measures <- c("maxave","minave", "totals", "vprph09", "vprph15")
dates <- as.character(seq(as.Date('2013-01-01'), as.Date('2013-01-27'), 1))
#rm(dat)
for(date_j in dates)
{
  date_i <- gsub("-","",date_j)
  for(i in 1:length(measures))
  { # i = 1
    measure <- measures[i]
    rastername <- paste("awap_grids.", measure, "_", date_i, sep ="")
    sql <- postgis_raster_extract(ch2, x=rastername, y=xy, zone_label = "location", value_label = "value")
    #cat(sql)  
    if(!exists("dat"))
    {
      dat <- dbGetQuery(ch, sql)    
    } else {
      dat <- rbind(dat, dbGetQuery(ch, sql))
    }
  
  }
}


dat$date <- matrix(unlist(strsplit(dat$raster_layer, "_")), ncol = 3, byrow=TRUE)[,3]
dat$date <- paste(substr(dat$date,1,4), substr(dat$date,5,6), substr(dat$date,7,8), sep = "-")
dat$measure <- matrix(unlist(strsplit(dat$raster_layer, "_")), ncol = 3, byrow=TRUE)[,2]
dat$measure <- gsub("grids.","",dat$measure)

dat <- arrange(dat,  date, measure)
dat <- as.data.frame(cast(dat, location + date ~ measure, value = "value"))
dat$date <- as.Date(dat$date)
# str(dat)
# with(dat, plot(date, maxave, "l"))
  write.csv(dat, paste(locn, ".csv", sep =""))
}