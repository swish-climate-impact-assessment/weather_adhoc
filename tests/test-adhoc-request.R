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
pwd <- getPassword(remote = T)
# get scope
location <- 'mills and egglston roads  acton'
xy <- gGeoCode2(location)
xy
actsla01 <- readOGR2(hostip='115.146.84.135', user="gislibrary",db="zones", layer="abs_sla.actsla01", p=pwd)
nswsla06 <- readOGR2(hostip='115.146.84.135', user="gislibrary",db="zones", layer="abs_sla.nswsla06", p=pwd)
nswsla06 <- readOGR2(hostip='115.146.84.135', user="gislibrary",db="ewedb", layer="abs_sla.nswsla06", p=pwd)
# visualise some data
plot(nswsla06, xlim = c(150,152), ylim = c(-34.5,-33))
with(xy, points(as.numeric(as.character(long)), as.numeric(as.character(lat)), pch = 16, col = "blue"))
axis(1); axis(2)

r <- readGDAL(sprintf("PG:host=115.146.84.135 port=5432 dbname='ewedb' user='gislibrary' password='%s' schema='awap_grids' table=maxave_20130108", pwd))
writeGDAL(r, fname="test.tif", drivername="GTiff")
image(r, add = T, col=rainbow(n = 60))
plot(nswsla06, add= T)
with(xy, points(as.numeric(as.character(long)), as.numeric(as.character(lat)), pch = 16, col = "blue"))
axis(1); axis(2)
ch2<- connect2postgres2("zones")
nswsla06_points <- sql_subset(ch2, "abs_sla.nswsla06", select = "sla_code, st_x(st_centroid(geom)) as long, st_y(st_centroid(geom)) as lat, st_area(geom) as sla_area_dd", eval = T)
mean(nswsla06_points$sla_area_dd)
head(nswsla06_points)
tail(nswsla06_points)
with(nswsla06_points, points(long, lat, pch = 16, col = "red"))
map.scale(ratio=F)

#### load the data to ewedb
#dbSendQuery(ch, "drop table public.\"abs_sla.nswsla06_points\"")
dbWriteTable(ch, name="nswsla06_points", value=nswsla06_points, row.names = F)
dbSendQuery(ch, "alter table public.nswsla06_points set schema abs_sla")
# TODO review this step, might not be worth saving?
sql <- points2geom(schema="abs_sla",tablename="nswsla06_points",col_lat="lat",col_long="long")
cat(sql)
dbSendQuery(ch, sql)
########
# now work o nthe data
sql_subset(ch, "abs_sla.nswsla06_points", limit = 1, eval = T)
measures <- c("maxave","minave")
dates <- as.character(seq(as.Date('2013-01-01'), as.Date('2013-01-27'), 1))
#rm(dat)

##################################################################
# start fresh
dbSendQuery(ch, "drop table  weather_sla.weather_nswsla06")
dbSendQuery(ch, "drop table public.tempfoobar")
for(date_j in dates)
{
  #date_j <- dates[2]
  date_i <- gsub("-","",date_j)
  print(date_i)
  for(i in 1:length(measures))
  { # i = 1
    measure <- measures[i]
    print(measure)
    rastername <- paste("awap_grids.", measure, "_", date_i, sep ="")
    tableExists <- pgListTables(ch, schema="awap_grids", pattern=paste(measure, "_", date_i, sep =""))
    if(nrow(tableExists) > 0)
    {
    sql <- postgis_raster_extract(ch2, x=rastername, y="abs_sla.nswsla06_points", zone_label = "sla_code", value_label = "value")
    sql <- gsub("FROM", "INTO public.tempfoobar\nFROM", sql)
    #cat(sql)  
    
    dbSendQuery(ch, sql) 
    
    tblExists <- pgListTables(ch, "weather_sla", "weather_nswsla06")
    if(nrow(tblExists) == 0)
    {
    sql <- sql_subset_into(ch, x="public.tempfoobar", into_schema="weather_sla", into_table="weather_nswsla06",eval=F, drop=F)
    #cat(sql)
    dbSendQuery(ch, sql)      
    } else {
      sql <- sql_subset(ch, x="public.tempfoobar", eval=F)
      sql <- paste("INSERT INTO weather_sla.weather_nswsla06(
      sla_code, raster_layer, value)
      ",sql,sep ="")
      #cat(sql)
      dbSendQuery(ch, sql)
    }
    dbSendQuery(ch, "drop table public.tempfoobar")
#     if(!exists("dat"))
#     {
#       dat <- dbGetQuery(ch, sql)    
#     } else {
#       dat <- rbind(dat, dbGetQuery(ch, sql))
#     }
    }
  }
}

dat <- sql_subset(ch, "weather_sla.weather_nswsla06", eval = T)
dat$date <- matrix(unlist(strsplit(dat$raster_layer, "_")), ncol = 3, byrow=TRUE)[,3]
dat$date <- paste(substr(dat$date,1,4), substr(dat$date,5,6), substr(dat$date,7,8), sep = "-")
dat$measure <- matrix(unlist(strsplit(dat$raster_layer, "_")), ncol = 3, byrow=TRUE)[,2]
dat$measure <- gsub("grids.","",dat$measure)

dat <- arrange(dat,  date, measure)
dat <- as.data.frame(cast(dat, sla_code + date ~ measure, value = "value"))
dat$date <- as.Date(dat$date)
 str(dat)
head(dat)
qc <- subset(dat, sla_code == dat$sla_code[1])
with(qc, plot(date, maxave, "l", ylim = c(0,40)))
with(qc, lines(date, minave))