
################################################################
# name:dummy-addresses
require(ProjectTemplate)
load.project()
plotMyMap("sydney", googlemaps=T, xl = c(150,152), yl= c(-35,-32))
axis(2);axis(1)
centre <- gGeoCode2("sydney")
xs <- rnorm(1000, as.numeric(as.character(centre$long)), .1)
ys <- rnorm(1000, as.numeric(as.character(centre$lat)), .1)
points(xs, ys)
#head(xs)
require(ggmap)
locations <- as.data.frame(matrix(nrow = 100, ncol = 1))
for(i in 1:100){
  #i <-  1
  print(i)
  locations <- revgeocode(c(xs[i], ys[i]))
  }
write.csv(locations, "data/locations.csv", row.names = F)

gGeoCode2(locations[1,])
c(xs[1], ys[1])

## Treat data frame as spatial points
epsg <- make_EPSG()
pts <- SpatialPointsDataFrame(cbind(xs[1:100],ys[1:100]),locations,
  proj4string=CRS(epsg$prj4[epsg$code %in% '4283']))
writeOGR(pts, 'data/locations.shp', 'locations', driver='ESRI Shapefile')
