# xkcdgeohashing.nim
Nim implementation for the geohashing algorithm described in xkcd #426. 

The algorithm is also described on the Geohashing wiki.

# Compiling
As a task:
```
nimble build
```

With nim compiler:
```
nim c src/xkcdgeohash.nim
```

Compiling and running:
```
nim c -r src/xkcdgeohash.nim
```

Compiling release mode:
```
nim c -d:release src/xkcdgeohash.nim
```

# Testing
As a task:
```
nimble test
```

Includes tests for the based 30W timezone rule found on the Geohashing wiki:: https://geohashing.site/geohashing/30W_Time_Zone_Rule

# Docs
- You can compile the HTML docs by applying `nim doc` on `src/xkcdgeohash.nim`

Implementation of the geohashing algorithm from https://xkcd.com/426/

The library provides an object-oriented, functional, and commandline API for calculating
geohash coordinates according to the xkcd geohashing algorithem spesification.

Algorithm spec can be seen at: https://geohashing.site/geohashing/The_Algorithm

Copyright (c) 2025 Sebastian H. Lorenzen
Licensed under MIT License

## Quick Start

```nim
import xkcdgeohash
import std/times

# Simple functional API
let result: GeohashResult = xkcdgeohash(68.0, -30.0, now())
echo "Coordinates: ", result.latitude, ", ", result.longitude

# Object-oriented API for repeated calculations
let geohasher: Geohasher = newGeohasher(68, -30)
let coords: GeohashResult = geohasher.hash(now())

# Global geohash calculation
let globalCoords: GeohashResult = xkcdglobalgeohash(now())
echo "Global coordinates: ", globalCoords.latitude, ", ", globalCoords.longitude
```

Per Default the Library tries to fetch data from the following sources via a http-client:
- http://carabiner.peeron.com/xkcd/map/data/
- http://geo.crox.net/djia/
- http://www1.geo.crox.net/djia/
- http://www2.geo.crox.net/djia/


## **Object Oriented API**:

Ideal when preforming multiple geohash calculations at the same graticule (integer coordinate area).
Allows you to reuse setup.
It automatically handles Dow Jones data fetching and applies the 30W timezone rule.
Dow Jones Provider can be changed, per default `HttpDowProvider` is used.

```nim
# Create a geohasher for the Minneapolis area
let geohasher: Geohasher = newGeohasher(45, -93)

# Calculate coordinates for different dates
let today: GeohashResult = geohasher.hash(now())
let yesterday: GeohashResult = geohasher.hash(now() - 1.days)

# Use custom Dow Jones data source
let customProvider: HttpDowProvider = getDefaultDowProvider()
let customGeohasher: Geohasher = newGeohasher(45, -93, customProvider)

let yeasteryeasterday: GeohashResult = geohasher.hash(now() - 2.days)

# Global geohash with OO API
let globalGeohasher: GlobalGeohasher = newGlobalGeohasher()
let globalResult: GeohashResult = globalGeohasher.hash(now())
```


## **Functional API**:

Simple, stateless way to calculate geohashes for one-off calculations.
It automatically handles Dow Jones data fetching and applies the 30W timezone rule.
Dow Jones Provider can be changed, per default `HttpDowProvider` is used.

```nim
# Calculate geohash for specific coordinates and date
let result = xkcdgeohash(45.0, -93.0, dateTime(2008, mMay, 21))

echo "Latitude: ", result.latitude
echo "Longitude: ", result.longitude
echo "Used Dow date: ", result.usedDowDate.format("yyyy-MM-dd")

# Calculate global geohash for a specific date
let globalResult = xkcdglobalgeohash(dateTime(2008, mMay, 21))
echo "Global coordinates: ", globalResult.latitude, ", ", globalResult.longitude
```


## **Commandline Use**:
```
XKCD Geohash Calculator
 
Usage:
    xkcdgeohash --lat=<latitude> --lon=<longitude> [options]
    xkcdgeohash --global [options]
    xkcdgeohash --version
    xkcdgeohash --help
 
Options:
    --lat=<latitude>         Target latitude
    --lon=<longitude>        Target longitude
    -d, --date=DATE          Target date (YYYY-MM-DD, default: today)
    -g, --global             Calculate global geohash
    -v, --verbose            Show additional information
    -j, --json               Output as JSON
    -f, --format=FORMAT      Output format [default: decimal]
                            (decimal, dms, coordinates)
    --from=DATE              Start date for range
    --to=DATE                End date for range  
    --days=N                 Last N days from today
    --source=URL             Dow Jones data source URL
    --data-file=FILE         Local Dow Jones data file
    --url=SERVICE            Generate map URL for service
                            (google, bing, osm, waymarked)
    --zoom=LEVEL             Zoom level for map URLs [default: 15]
    --marker                 Add marker to map URL
    -h, --help               Show this help message
    --version                Show version
    --test                   Toggle use of mockdata when testing
 
Output Formats:
    decimal                  68.857713, -30.544544 (default)
    dms                      68°51'27.8"N, 30°32'40.4"W
    coordinates              68.857713,-30.544544
 
URL Services:
    google                   Google Maps
    bing                     Bing Maps  
    osm                      OpenStreetMap
    waymarked                Waymarked Trails (hiking/cycling routes)
 
Examples:
    xkcdgeohash --lat=68.0 --lon=-30.0
    xkcdgeohash --global --date=2008-05-26
    xkcdgeohash --lat=68.0 --lon=-30.0 --url=google --marker
    xkcdgeohash --lat=45.0 --lon=-93.0 --days=7 --url=google --json
    xkcdgeohash --lat=68.0 --lon=-30.0 --verbose --url=osm --zoom=12
```


## 30W Timezone Rule

The algorithm implements the 30W timezone rule:
- **West of 30W longitude** (Americas): Uses Dow Jones price from same day
- **East of 30W longitude** (Europe, Africa, Asia): Uses Dow Jones price from previous day
- **Before 2008-05-27**: All coordinates use same day (rule wasn't active yet)
- **Global Hashes**: Uses Dow Jones price from previous day, no matter what

See also: https://geohashing.site/geohashing/30W_Time_Zone_Rule#30W_compliance_confusion_matrix


## **Global Geohashing**

Global geohashes provide a single worldwide coordinate for each date, covering the entire globe.
Unlike regular geohashes which are constrained to 1x1 degree graticules, global geohashes
can land anywhere on Earth.

```nim
# Functional API (recommended for most use cases)
let globalCoords = xkcdglobalgeohash(now())
echo "Today's global meetup: ", globalCoords.latitude, ", ", globalCoords.longitude

# Object-oriented API for repeated calculations
let globalGeohasher = newGlobalGeohasher()
let coords1 = globalGeohasher.hash(now())
let coords2 = globalGeohasher.hash(now() - 1.days)
```
## **Error Handling**

The library defines spesific exceptions types for different error conditions:
- `GeohashError`: Base exception type for the library
- `DowDataError`: Thrown when Dow Jones data cannot be retrieved. Inherits from `GeohashError`


## **Custom Dow Jones Provider (djia)**

You can implement you own Dow Jones data source provider by inheriting from the `DowJonesProvider`
strategy interface:

```nim
type MyCustomProvider = ref object of DowJonesProvider
```

Then implement `getDowPrice` for your custom provider:

```nim
method getDowPrice(provider: MyCustomProvider, date: DateTime): float =
    # Custom implementation here
    return 12345.67
```

A constructor might also be good to have depending on how data found :)

Then use it!

```nim
let customProvider: MyCustomProvider = newCustomProvider()
let customGeohasher: Geohasher = newGeohasher(45, -93, customProvider)
let customGlobalGeohasher: GlobalGeohasher = newGlobalGeohasher(customProvider)
```

See the librarys testing for an implementation of a mock dow jones data provider.
