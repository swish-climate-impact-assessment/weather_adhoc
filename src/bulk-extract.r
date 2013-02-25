if(!require(plyr)) install.packages("plyr"); require(plyr)
# connect
download.file("http://swish-climate-impact-assessment.github.com/tools/swishdbtools/swishdbtools_1.1.zip", "~/swishdbtools_1.1.zip", mode = "wb")
install.packages("~/swishdbtools_1.1.zip", repos = NULL)
require(swishdbtools)
download.file("http://ivanhanigan.github.com/gisviz/gisviz_1.0.zip", "~/gisviz_1.0.zip", mode = "wb")
install.packages("~/gisviz_1.0.zip", repos = NULL)

ewedb <- connect2postgres2('ewedb')

# newnode variable names
# urls can be like
# rain                http://www.bom.gov.au/web03/ncc/www/awap/   rainfall/totals/daily/    grid/0.05/history/nat/2010120120101201.grid.Z
# tmax                http://www.bom.gov.au/web03/ncc/www/awap/   temperature/maxave/daily/ grid/0.05/history/nat/2012020620120206.grid.Z
# tmin                http://www.bom.gov.au/web03/ncc/www/awap/   temperature/minave/daily/ grid/0.05/history/nat/2012020620120206.grid.Z
# vapour pressure 9am http://www.bom.gov.au/web03/ncc/www/awap/   vprp/vprph09/daily/       grid/0.05/history/nat/2012020620120206.grid.Z
# vapour pressure 3pm http://www.bom.gov.au/web03/ncc/www/awap/   vprp/vprph15/daily/       grid/0.05/history/nat/2012020620120206.grid.Z
# solar               http://www.bom.gov.au/web03/ncc/www/awap/   solar/solarave/daily/     grid/0.05/history/nat/2012020720120207.grid.Z
# NDVI                http://reg.bom.gov.au/web03/ncc/www/awap/   ndvi/ndviave/month/       grid/history/nat/2012010120120131.grid.Z
vars<-"variable,measure,timestep
rainfall,totals,daily
temperature,maxave,daily
temperature,minave,daily
vprp,vprph09,daily
vprp,vprph15,daily
solar,solarave,daily
ndvi,ndviave,month
"
vars<-read.csv(textConnection(vars))

# enter your locations
cd_hilda <- read.table("cd_code_Hilda.txt", header = TRUE)
str(cd_hilda)
dbWriteTable(ewedb, "cd_hilda", cd_hilda, row.names = FALSE)

cat(
  sql_join(conn=ewedb, x='auscd01cl_master_points', y='cd_hilda', by='cd_code', eval=FALSE)
)

dbSendQuery(ewedb,
            "select t1.cd_code, t1.long, t1.lat
            into public.cd_hilda2
            from public.auscd01cl_master_points t1
            join
            public.cd_hilda t2
            on t1.cd_code = t2.cd_code
            ")
qc <- sql_subset(ewedb, "cd_hilda2", eval = T)
nrow(qc)
head(qc)
nrow(cd_hilda)

# make spatial
sql <- points2geom(schema='public', tablename='cd_hilda2', col_lat='lat', col_long='long')
cat(sql)
dbSendQuery(ewedb, sql)

# extract the values for missing days
#*** scope
#the ccd in HILDA is 2001 version.
missing <- "missing_days,date
28oct2001,2001-10-28
27oct2002,2002-10-27
26oct2003,2003-10-26
31oct2004,2004-10-31
30oct2005,2005-10-30
29oct2006,2006-10-29
28oct2007,2007-10-28
05oct2008,2008-10-05
04oct2009,2009-10-04
03oct2010,2010-10-03
02oct2011,2011-10-02
07oct2012,2012-10-07"
missing <- read.csv(textConnection(missing), sep = ',', stringsAsFactors = F)
missing


# start fresh
dbSendQuery(ewedb, "drop table public.cd_hilda2_extract_value")

for(date_j in missing[-c(1,2),2])
{
  #date_j <- missing[2,2]
  date_i <- gsub("-", "", date_j)
  #paste("cast('",date_i,"' as date) as date", sep = "")
  for(measure_label in vars[1:6,'measure'])
  {
    #measure_label <- vars[1,'measure']
    
    sql <- postgis_raster_extract(
      conn = ewedb, x = paste("awap_grids.",measure_label,"_",date_i,sep=""), y = 'cd_hilda2', 
      fun = NA, eval = FALSE, zone_label = 'cd_code', value_label = 'value', into = TRUE)
    
    #sql <- gsub("SELECT ", paste("SELECT cast('", date_j, "' as date) as date, ", sep = ""), sql)
    
    #cat(sql)
    
    dbSendQuery(ewedb, sql)
  }
}

dat <- sql_subset(ewedb, "public.cd_hilda2_extract_value", subset = "cd_code = 8024409",eval=T)
dat$date <- matrix(unlist(strsplit(dat$raster_layer, "_")), ncol = 3, byrow=TRUE)[,3]
dat$measure <- matrix(unlist(strsplit(dat$raster_layer, "_")), ncol = 3, byrow=TRUE)[,2]

dat <- arrange(dat,  date, measure)

dat