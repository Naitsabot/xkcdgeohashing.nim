## Geohashing library for Nim
##
## Implementation of the geohashing algorithm from https://xkcd.com/426/
## 
## The library provides an object-oriented, functional, and commandline API for calculating
## geohash coordinates according to the xkcd geohashing algorithem spesification.
## 
## Algorithm spec can be seen at: https://geohashing.site/geohashing/The_Algorithm
## 
## Copyright (c) 2025 Sebastian H. Lorenzen
## Licensed under MIT License

## ## Quick Start
##
## ```nim
## import xkcdgeohash
## import std/times
##
## # Simple functional API
## let result: GeohashResult = xkcdgeohash(68.0, -30.0, now())
## echo "Coordinates: ", result.latitude, ", ", result.longitude
##
## # Object-oriented API for repeated calculations
## let geohasher: Geohasher = newGeohasher(68, -30)
## let coords: GeohashResult = geohasher.hash(now())
##
## # Global geohash calculation
## let globalCoords: GeohashResult = xkcdglobalgeohash(now())
## echo "Global coordinates: ", globalCoords.latitude, ", ", globalCoords.longitude
## ```
##
## Per Default the Library tries to fetch data from the following sources via a http-client:
## - http://carabiner.peeron.com/xkcd/map/data/
## - http://geo.crox.net/djia/
## - http://www1.geo.crox.net/djia/
## - http://www2.geo.crox.net/djia/


## ## **Object Oriented API**:
##
## Ideal when preforming multiple geohash calculations at the same graticule (integer coordinate area).
## Allows you to reuse setup.
## It automatically handles Dow Jones data fetching and applies the 30W timezone rule.
## Dow Jones Provider can be changed, per default `HttpDowProvider` is used.
##
## ```nim
## # Create a geohasher for the Minneapolis area
## let geohasher: Geohasher = newGeohasher(45, -93)
##
## # Calculate coordinates for different dates
## let today: GeohashResult = geohasher.hash(now())
## let yesterday: GeohashResult = geohasher.hash(now() - 1.days)
##
## # Use custom Dow Jones data source
## let customProvider: HttpDowProvider = getDefaultDowProvider()
## let customGeohasher: Geohasher = newGeohasher(45, -93, customProvider)
##
## let yeasteryeasterday: GeohashResult = geohasher.hash(now() - 2.days)
##
## # Global geohash with OO API
## let globalGeohasher: GlobalGeohasher = newGlobalGeohasher()
## let globalResult: GeohashResult = globalGeohasher.hash(now())
## ```


## ## **Functional API**:
##
## Simple, stateless way to calculate geohashes for one-off calculations.
## It automatically handles Dow Jones data fetching and applies the 30W timezone rule.
## Dow Jones Provider can be changed, per default `HttpDowProvider` is used.
##
## ```nim
## # Calculate geohash for specific coordinates and date
## let result = xkcdgeohash(45.0, -93.0, dateTime(2008, mMay, 21))
##
## echo "Latitude: ", result.latitude
## echo "Longitude: ", result.longitude
## echo "Used Dow date: ", result.usedDowDate.format("yyyy-MM-dd")
##
## # Calculate global geohash for a specific date
## let globalResult = xkcdglobalgeohash(dateTime(2008, mMay, 21))
## echo "Global coordinates: ", globalResult.latitude, ", ", globalResult.longitude
## ```


## ## **Commandline Use**:
## 
## **TODO**: *Yet to be implemented*


## ## 30W Timezone Rule
##
## The algorithm implements the 30W timezone rule:
## - **West of 30W longitude** (Americas): Uses Dow Jones price from same day
## - **East of 30W longitude** (Europe, Africa, Asia): Uses Dow Jones price from previous day
## - **Before 2008-05-27**: All coordinates use same day (rule wasn't active yet)
## - **Global Hashes**: Uses Dow Jones price from previous day, no matter what
## 
## See also: https://geohashing.site/geohashing/30W_Time_Zone_Rule#30W_compliance_confusion_matrix


## ## **Global Geohashing**
##
## Global geohashes provide a single worldwide coordinate for each date, covering the entire globe.
## Unlike regular geohashes which are constrained to 1x1 degree graticules, global geohashes
## can land anywhere on Earth.
##
## ```nim
## # Functional API (recommended for most use cases)
## let globalCoords = xkcdglobalgeohash(now())
## echo "Today's global meetup: ", globalCoords.latitude, ", ", globalCoords.longitude
##
## # Object-oriented API for repeated calculations
## let globalGeohasher = newGlobalGeohasher()
## let coords1 = globalGeohasher.hash(now())
## let coords2 = globalGeohasher.hash(now() - 1.days)
## ```


## ## **Error Handling**
## 
## The library defines spesific exceptions types for different error conditions:
## - `GeohashError`: Base exception type for the library
## - `DowDataError`: Thrown when Dow Jones data cannot be retrieved. Inherits from `GeohashError`


## ## **Custom Dow Jones Provider (djia)**
##
## You can implement you own Dow Jones data source provider by inheriting from the `DowJonesProvider`
## strategy interface:
##
## ```nim
## type MyCustomProvider = ref object of DowJonesProvider
## ```
##
## Then implement `getDowPrice` for your custom provider:
##
## ```nim
## method getDowPrice(provider: MyCustomProvider, date: DateTime): float =
##     # Custom implementation here
##     return 12345.67
## ```
##
## A constructor might also be good to have depending on how data found :)
##
## Then use it!
##
## ```nim
## let customProvider: MyCustomProvider = newCustomProvider()
## let customGeohasher: Geohasher = newGeohasher(45, -93, customProvider)
## let customGlobalGeohasher: GlobalGeohasher = newGlobalGeohasher(customProvider)
## ```
##
## See the librarys testing for an implementation of a mock dow jones data provider.


import std/[httpclient, parseutils, strutils, times]
import checksums/md5


# =============================================================================
# TYPES
# =============================================================================


type
    Graticule* = object
        ## Represents a graticule (integer coordinate area) for geohashing.
        ## 
        ## **Note:** The ambiguous -0/+0 distinction is excluded for simplicity.
        ## 
        ## **Example:**
        ## ```nim
        ## let skanderborg: Graticule = Graticule(lat: 56, lon: 9)
        ## let minneapolis: Graticule = Graticule(lat: 45, lon: -93)
        ## let berlin: Graticule = Graticule(lat: 52, lon: 13)
        ## ```
        lat*: int ## Latitude: -90 to +90 (-0/+0 excluded) (minute or decimal coordinate)
        lon*: int ## Longitude: -179 to +179 (-0/+0 excluded) (minute or decimal coordinate)
    
    GeohashResult* = object
        ## Result of a geohash calculation containing the final coordinates
        ## and metadata about the calculation.
        ## 
        ## **Example:**
        ## ```nim
        ## let result = xkcdgeohash(50.19, 6.83, now())
        ## echo "Coords: ", result.latitude, ", ", result.longitude
        ## echo "Used Dow date: ", result.usedDowDate.format("yyyy-MM-dd")
        ## echo "Target date: ", result.usedDate.format("yyyy-MM-dd")
        ## ```
        latitude*: float ## Final calculated latitude (Decimal coordinate)
        longitude*: float ## Final calculated longitude (Decimal coordinate)
        usedDowDate*: DateTime ## Dow Jones date that was actually used
        usedDate*: DateTime ## Original target date for the calculation
    
    Geohasher* = object
        ## Container for geohashing operations with configured data source.
        ## 
        ## Stores a graticule and Dow Jones provider for efficient repeated
        ## calculations within the same coordinate area.
        ##  
        ## **Example:**
        ## ```nim
        ## let geohasher = newGeohasher(45, -93)
        ## let coords1 = geohasher.hash(now())
        ## let coords2 = geohasher.hash(now() - 1.days)
        ## ```
        graticule*: Graticule ## Target graticule for calculations
        dowProvider*: DowJonesProvider  # Data source for Dow Jones prices (strategy pattern)

    GlobalGeohasher* = object
        ## Container for global geohashing operations with configured data source.
        dowProvider*: DowJonesProvider  # Data source for Dow Jones prices (strategy pattern)
        
    
    DowJonesProvider* = ref object of RootObj
        ## Strategy Interface: Abstract base type for Dow Jones data providers.
        ## 
        ## Implement this to create custom data sources for Dow Jones prices.
        ## The default implementation fetches data from multiple HTTP sources
        ## with automatic failover.
        ## 
        ## **Example:**
        ## ```nim
        ## type MyProvider = ref object of DowJonesProvider
        ##
        ## method getDowPrice(provider: MyProvider, date: DateTime): float =
        ##     # Custom implementation
        ##     return myGetPrice(date)
        ## ```

    HttpDowProvider* = ref object of DowJonesProvider
        ## HTTP-based Dow Jones provider with multiple source URLs and failover.
        ##
        ## Automatically tries multiple data sources in order until one succeeds.
        ## Remembers which source last worked for improved performance.
        sources*: seq[string] ## List of HTTP data source URLs
        currentSourceIndex*: int ## Index of last successful source

    GeohashError* = object of CatchableError
        ## Base exception type for all geohashing-related errors.

    DowDataError* = object of GeohashError
        ## Exception thrown when Dow Jones data cannot be retrieved.
        ## 
        ## This can happen due to network issues, invalid dates,
        ## or when all configured data sources fail.


# =============================================================================
# CONSTANTS
# =============================================================================


const DOW_JONES_SOURCES: array[0..3, string] = 
    ["http://carabiner.peeron.com/xkcd/map/data/", "http://geo.crox.net/djia/",
     "http://www1.geo.crox.net/djia/", "http://www2.geo.crox.net/djia/"]
    ## Default HTTP sources for Dow Jones Industrial Average data.
    ## These sources provide daily opening prices in the format required
    ## by the geohashing algorithm.


# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================


proc parseHexFloat(hexStr: string): float =
    ## Convert a hexadecimal fraction string to decimal float.
    ## 
    ## Takes a string like `"0.db9318c2259923d0"` and converts it to
    ## a decimal number between `0.0` and `1.0`.
    ## 
    ## **Parameters:**
    ## - `hexStr`: Hex string starting with "0." followed by hex digits
    ##
    ## **Returns:** Decimal value between 0.0 and 1.0
    ##
    ## **Raises:** `ValueError` if the hex string is malformed
    let hexPart: string = hexStr[2..^1]  # Removes "0."
    var intValue: uint64
    if parseHex(hexPart, intValue) != hexPart.len:
        raise newException(ValueError, "Invalid hex string: " & hexStr)
    return float(intValue) / float(uint64.high)


proc findLatestDowDate(targetDate: DateTime): Datetime = 
    ## Find the latest date up to and including targetDate when
    ## the Dow Jones market was open (excluding weekends).
    ## 
    ## **TODO:** Check for holidays! https://geohashing.site/geohashing/Dow_holiday
    ## 
    ## **Note:** This is a simplified implementation that only excludes
    ## weekends. A complete implementation would also exclude market holidays.
    ##
    ## **Parameters:**
    ## - `targetDate`: The latest date to consider
    ##
    ## **Returns:** The latest valid Dow Jones trading date
    var checkDate: Datetime = targetDate

    while checkDate.weekDay == dSat or checkDate.weekDay == dSun:
        checkDate = checkDate - 1.days
    
    return checkDate


proc getApplicableDowDate(graticule: Graticule, targetDate: DateTime): DateTime =
    ## Determine the applicable Dow Jones opening date "DJOD" according to
    ## the 30W timezone rule and historical cutoff.
    ## 
    ## **Rules:**
    ## - Before 2008-05-27: Always use same day for all coordinates
    ## - From 2008-05-27 onwards:
    ##   - West of 30W longitude: Use same day
    ##   - East of 30W longitude: Use previous day
    ##
    ## **Parameters:**
    ## - `graticule`: Target graticule containing longitude for rule application
    ## - `targetDate`: The date for which to calculate geohash
    ##
    ## **Returns:** The date whose Dow Jones price should be used
    if graticule.lon >= -179 and graticule.lon <= -30:
        result = findLatestDowDate(targetDate)
    elif targetDate > dateTime(2008, mMay, 26):
        result = findLatestDowDate(targetDate - 1.days)
    else:
        result = findLatestDowDate(targetDate)
    return


proc getApplicableDowDateGlobal(targetDate: DateTime): DateTime =
    ## Determine the applicable Dow Jones opening date "DJOD" according to
    ## the global 30W timezone rule.
    ## 
    ## **Rules:**
    ## - Global Geohash (any longitude and date): Use previous day
    ##
    ## **Parameters:**
    ## - `targetDate`: The date for which to calculate geohash
    ##
    ## **Returns:** The date whose Dow Jones price should be used
    return findLatestDowDate(targetDate - 1.days)


# =============================================================================
# DOW JONES DATA PROVIDER
# =============================================================================


proc getDefaultDowProvider*(): HttpDowProvider = 
    ## Create a default HTTP-based Dow Jones provider.
    ##
    ## Returns an HttpDowProvider configured with the standard
    ## geohashing data sources and automatic failover.
    ##
    ## **Returns:** Configured HttpDowProvider ready for use
    return HttpDowProvider(
        sources: @DOW_JONES_SOURCES,
        currentSourceIndex: 0
    )


proc fetchFromSource(source: string, date: Datetime): float =
    ## Creates an `HttpClient` and tries to fetch the Dow Jones price
    ## for the date from the given source.
    ## 
    ## **Parameters:**
    ## - `source`: Dow Jones URL source
    ## - `date`: Valied DJOD
    ## 
    ## **Returns:** Opening price as a float
    ## 
    ## ## **Raises:** 
    ## - `DowDataError`: When the price cannot be parsed, the fetch failed, or an error happend when processing the response.
    let client: HttpClient = newHttpClient()
    defer: client.close() # like try/finally, so it closes the connection when done

    let url: string = source & date.format("yyyy/MM/dd")

    try: 
        var response: string = client.getContent(url) # request
        response = response.strip() # clean response
        
        var price: float
        if parseFloat(response, price) != 0: # overloaded from parseutils, returns ability of proc
            raise newException(DowDataError, "Could not parse price from response: " & response)
        
        return price

    except HttpRequestError: 
        raise newException(DowDataError, "Failed to fetch from: " & url)
    except:
        raise newException(DowDataError, "Error processing response from: " & url)


method getDowPrice*(provider: DowJonesProvider, date: DateTime): float {.base.} =
    ## Retrieve the Dow Jones Industrial Average opening price for a specific date.
    ##
    ## **Base method** - must be implemented by concrete provider types. 
    ##
    ## **Parameters:**
    ## - `provider`: The data provider instance
    ## - `date`: Date for which to retrieve the opening price
    ##
    ## **Returns:** Opening price as a float (typically with 2 decimal places)
    ##
    ## **Raises:** 
    ## - `DowDataError`: When the price cannot be retrieved
    ## - `CatchableError`: Base implementation always raises this
    raise newException(CatchableError, "Not Implemented")


method getDowPrice(provider: HttpDowProvider, date: Datetime): float =
    ## HTTP implementation of Dow Jones price retrieval.
    ##
    ## Tries each configured source URL in order until one succeeds.
    ## Automatically handles failover and remembers the last successful source.
    ##
    ## **Parameters:**
    ## - `provider`: HttpDowProvider instance with configured sources
    ## - `date`: Date for which to retrieve the price
    ##
    ## **Returns:** Dow Jones opening price for the specified date
    ##
    ## **Raises:** `DowDataError` when all sources fail
    var lastError: ref Exception = nil

    for i in 0..provider.sources.len:
        let sourceIndex  = (provider.currentSourceIndex + i) mod provider.sources.len
        let source = provider.sources[sourceIndex]

        try:
            let price: float = fetchFromSource(source, date)
            
            provider.currentSourceIndex = sourceIndex

            return price
        
        except Exception as e:
            lastError = e
            continue # failed, try next source
    
    raise newException(DowDataError, "All Dow Jones sources failed. Last error: " & 
                                     (if lastError != nil: lastError.msg else: "Unknown error"))


# =============================================================================
# GEOHASH ALGORITHM CORE
# =============================================================================


proc generateGeohashString(date: Datetime, dowPrice: float): string =
    ## Generate the hash input string from date and Dow Jones price.
    ##
    ## Combines the date (in YYYY-MM-DD format) and price (formatted to
    ## 2 decimal places) into the string that will be MD5 hashed.
    ## For example: "2005-05-26-10458.68"
    ##
    ## **Parameters:**
    ## - `date`: The applicable Dow Jones date
    ## - `dowPrice`: The Dow Jones opening price
    ##
    ## **Returns:** String in format "YYYY-MM-DD-NNNN.NN"
    let dateStr: string = date.format("yyyy-MM-dd")
    let priceStr: string = dowPrice.formatFloat(format = ffDecimal, precision = 2)
    return datestr & "-" & priceStr # Nim Strings are UTF-8 by default


proc md5ToCoordinateOffsets(hashStr: string): (float, float) =
    ## Convert MD5 hash string to coordinate offsets.
    ##
    ## Takes the geohash input string, calculates its MD5 hash,
    ## splits it into two 16-character halves, and converts each
    ## half to a decimal number between 0 and 1.
    ##
    ## **Parameters:**
    ## - `hashStr`: Input string to be hashed (e.g., "2005-05-26-10458.68")
    ##
    ## **Returns:** Tuple of (latitude_offset, longitude_offset), both floats
    
    # https://nim-lang.org/docs/md5.html
    let hash: string = getMD5(hashStr)
    let latitudeHex: string = "0." & hash[0..15]
    let longitudeHex: string = "0." & hash[16..31]

    # Convert hex to decimal
    let latitudeOffset: float = parseHexFloat(latitudeHex)
    let longitudeOffset: float = parseHexFloat(longitudeHex)

    return (latitudeOffset, longitudeOffset)


proc applyOffsetsToGraticule(graticule: Graticule, latitudeOffset: float, longitudeOffset: float): (float, float) =
    ## Apply coordinate offsets to a graticule using string concatenation.
    ##
    ## This implements the specific string-based coordinate calculation
    ## specified in the geohashing algorithm, where the decimal part of
    ## the offset is appended to the integer graticule coordinates.
    ##
    ## **Parameters:**
    ## - `graticule`: The target graticule (integer coordinates)
    ## - `latitudeOffset`: Latitude offset between 0.0 and 1.0
    ## - `longitudeOffset`: Longitude offset between 0.0 and 1.0
    ##
    ## **Returns:** Final (latitude, longitude) coordinates, both floats
    let latitudeStr: string = $graticule.lat & "." & ($latitudeOffset)[2..^1]
    let longitudeStr: string = $graticule.lon & "." & ($longitudeOffset)[2..^1]
    
    return (parseFloat(latitudeStr), parseFloat(longitudeStr))


# =============================================================================
# PUBLIC API
# =============================================================================


proc newGeohasher*(latitude: int, longitude: int, dowProvider: DowJonesProvider = getDefaultDowProvider()): Geohasher =
    ## Create a new Geohasher for the specified graticule.
    ##
    ## **Parameters:**
    ## - `latitude`: Integer latitude of the target graticule (-90 to +90)
    ## - `longitude`: Integer longitude of the target graticule (-179 to +179)
    ## - `dowProvider`: Optional custom Dow Jones data provider
    ##
    ## **Returns:** Configured Geohasher ready for coordinate calculations
    ##
    ## Example:
    ## ```nim
    ## # Skanderborg area with default provider
    ## let geohasher = newGeohasher(56, 9)
    ##
    ## # Berlin with custom provider
    ## let customProvider = getDefaultDowProvider()
    ## let berlinHasher = newGeohasher(52, 13, customProvider)
    ## ```
    return Geohasher(
        graticule: Graticule(lat: latitude, lon: longitude),
        dowProvider: dowProvider
    )


proc newGlobalGeohasher*(dowProvider: DowJonesProvider = getDefaultDowProvider()): GlobalGeohasher =
    ## Create a new Geohasher for the specified graticule.
    ## 
    ## **Parameters:**
    ## - `dowProvider`: Optional custom Dow Jones data provider
    ##
    ## **Returns:** Configured Geohasher ready for coordinate calculations
    return GlobalGeohasher(
        dowProvider: dowProvider
    )


proc hash*(geohasher: Geohasher, date: Datetime): GeohashResult =
    ## Calculate geohash coordinates for the specified date.
    ##
    ## Performs the complete geohashing algorithm:
    ## 1. Applies 30W timezone rule to determine Dow Jones date
    ## 2. Retrieves Dow Jones opening price
    ## 3. Generates and hashes the date-price string
    ## 4. Converts hash to coordinate offsets
    ## 5. Applies offsets to the graticule
    ## 
    ## **Parameters:**
    ## - `geohasher`: Configured Geohasher instance
    ## - `date`: Target date for coordinate calculation
    ##
    ## **Returns:** GeohashResult with coordinates and metadata
    ##
    ## **Raises:** `DowDataError` if Dow Jones data cannot be retrieved
    ##
    ## Example:
    ## ```nim
    ## let geohasher = newGeohasher(56, 9)
    ## let result = geohasher.hash(now())
    ## 
    ## echo "Today's coordinates: ", result.latitude, ", ", result.longitude
    ## echo "Used Dow date: ", result.usedDowDate.format("yyyy-MM-dd")
    ## ```
    let dowDate: Datetime = getApplicableDowDate(geohasher.graticule, date)
    let dowPrice: float = geohasher.dowProvider.getDowPrice(dowDate)
    let hashStr: string = generateGeohashString(date, dowPrice)
    let (latitudeOffset, longitudeOffset): (float, float) = md5ToCoordinateOffsets(hashStr)
    let (finalLatitude, finalLongitude): (float, float) = applyOffsetsToGraticule(geohasher.graticule, latitudeOffset, longitudeOffset)

    return GeohashResult(
        latitude: finalLatitude,
        longitude: finalLongitude,
        usedDowDate: dowDate,
        usedDate: date
    )


proc hash*(globalGeohasher: GlobalGeohasher, date: DateTime): GeohashResult =
    ## Calculate the global geohash coordinates for the specified date.
    ## 
    ## **Parameters:**
    ## - `globalGeohasher`: Configured GlobalGeohasher instance
    ## - `date`: Target date for coordinate calculation
    ##
    ## **Returns:** GeohashResult with coordinates and metadata
    ##
    ## **Raises:** `DowDataError` if Dow Jones data cannot be retrieved
    let zeroGraticule: Graticule = Graticule(lat: 0, lon: 0)
    let dowDate: Datetime = getApplicableDowDateGlobal(date)
    let dowPrice: float = globalGeohasher.dowProvider.getDowPrice(dowDate)
    let hashStr: string = generateGeohashString(date, dowPrice)
    let (latitudeOffset, longitudeOffset): (float, float) = md5ToCoordinateOffsets(hashStr)
    let (finalLatitude, finalLongitude): (float, float) = applyOffsetsToGraticule(zeroGraticule, latitudeOffset, longitudeOffset)

    let globalLatitude: float = finalLatitude * 180 - 90
    let globalLongitude: float = finalLongitude * 360 - 180

    return GeohashResult(
        latitude: globalLatitude,
        longitude: globalLongitude,
        usedDowDate: dowDate,
        usedDate: date
    )


proc xkcdgeohash*(latitude: float, longitude: float, date: DateTime, dowProvider: DowJonesProvider = getDefaultDowProvider()): GeohashResult =
    ## Calculate geohash coordinates using the functional API.
    ##
    ## This is a convenience function for one-off geohash calculations.
    ## It automatically creates a graticule from the provided coordinates
    ## and performs the complete geohashing algorithm.
    ## 
    ## **Parameters:**
    ## - `latitude`: Target latitude (will be truncated to integer for graticule)
    ## - `longitude`: Target longitude (will be truncated to integer for graticule)  
    ## - `date`: Date for coordinate calculation
    ## - `dowProvider`: Optional custom Dow Jones data provider
    ##
    ## **Returns:** GeohashResult with calculated coordinates and metadata
    ##
    ## **Raises:** `DowDataError` if Dow Jones data cannot be retrieved
    ##
    ## Example:
    ## ```nim
    ## # Simple calculation for today
    ## let result = xkcdgeohash(45.5, -93.7, now())
    ## 
    ## # Specific date with error handling
    ## try:
    ##     let coords = xkcdgeohash(52.0, 13.0, dateTime(2008, mMay, 21))
    ##     echo "Coordinates: ", coords.latitude, ", ", coords.longitude
    ## except DowDataError as e:
    ##     echo "Failed to get data: ", e.msg
    ## ```
    let graticule: Graticule = Graticule(lat: int(latitude), lon: int(longitude))
    let geohasher: Geohasher = Geohasher(graticule: graticule, dowProvider: dowProvider)
    return geohasher.hash(date)


proc xkcdglobalgeohash*(date: DateTime, dowProvider: DowJonesProvider = getDefaultDowProvider()): GeohashResult =
    ## Calculate globaL geohash coordinates using the functional API.
    ##
    ## It performs the complete geohashing algorithm and relates them to a point on the globe.
    ## 
    ## **Parameters:**
    ## - `date`: Date for coordinate calculation
    ## - `dowProvider`: Optional custom Dow Jones data provider
    ##
    ## **Returns:** GeohashResult with calculated coordinates and metadata
    ##
    ## **Raises:** `DowDataError` if Dow Jones data cannot be retrieved
    ##
    ## Example:
    ## ```nim
    ## # Simple calculation for today
    ## let result = xkcdglobalgeohash(now())
    ## 
    ## # Specific date with error handling
    ## try:
    ##     let coords = xkcdglobalgeohash(dateTime(2008, mMay, 21))
    ##     echo "Coordinates: ", coords.latitude, ", ", coords.longitude
    ## except DowDataError as e:
    ##     echo "Failed to get data: ", e.msg
    ## ```
    let geohasher: GlobalGeohasher = GlobalGeohasher(dowProvider: dowProvider)
    return geohasher.hash(date)


# =============================================================================
# OPERATOR OVERLOADS
# =============================================================================


proc `$`*(graticule: Graticule): string =
    ## Convert Graticule to string representation.
    return "(" & $graticule.lat & ", " & $graticule.lon & ")"


proc `$`*(geohashResult: GeohashResult): string =
    ## Convert GeohashResult to string representation.
    return "GeohashResult(lat: " & $geohashResult.latitude & 
        ", lon: " & $geohashResult.longitude & 
        ", usedDate: " & geohashResult.usedDate.format("yyyy-MM-dd") &
        ", usedDowDate: " & geohashResult.usedDowDate.format("yyyy-MM-dd") & ")"


proc `$`*(geohasher: Geohasher): string =
    ## Convert Geohasher to string representation.
    return "Geohasher(" & $geohasher.graticule & ")"


proc `$`*(globalGeohasher: GlobalGeohasher): string =
    ## Convert GlobalGeohasher to string representation.
    return "GlobalGeohasher()"


proc `==`*(a, b: Graticule): bool =
    ## Check equality between two Graticule objects.
    return a.lat == b.lat and a.lon == b.lon


proc `==`*(a, b: GeohashResult): bool =
    ## Check equality between two GeohashResult objects.
    return a.latitude == b.latitude and 
           a.longitude == b.longitude and
           a.usedDate == b.usedDate and
           a.usedDowDate == b.usedDowDate


proc `==`*(a, b: Geohasher): bool =
    ## Check equality between two Geohasher objects.
    return a.graticule == b.graticule


proc `==`*(a, b: GlobalGeohasher): bool =
    ## Check equality between two GlobalGeohasher objects.
    return a.dowProvider == b.dowProvider


proc `<`*(a, b: Graticule): bool =
    ## Compare Graticule objects for ordering (latitude first, then longitude).
    if a.lat != b.lat:
        return a.lat < b.lat
    return a.lon < b.lon


proc `<=`*(a, b: Graticule): bool =
    ## Check if Graticule a is less than or equal to b.
    return a == b or a < b


proc `<`*(a, b: GeohashResult): bool =
    ## Compare GeohashResult objects for ordering (date first, then coordinates).
    if a.usedDate != b.usedDate:
        return a.usedDate < b.usedDate
    if a.latitude != b.latitude:
        return a.latitude < b.latitude
    return a.longitude < b.longitude


proc `<=`*(a, b: GeohashResult): bool =
    ## Check if GeohashResult a is less than or equal to b.
    return a == b or a < b


proc `<`*(a, b: GlobalGeohasher): bool =
    ## Compare GlobalGeohasher objects for ordering (by provider).
    return cast[pointer](a.dowProvider) < cast[pointer](b.dowProvider)


proc `<=`*(a, b: GlobalGeohasher): bool =
    ## Check if GlobalGeohasher a is less than or equal to b.
    return a == b or a < b


# =============================================================================
# MAIN MODULE Command-line interface for XKCD Geohashing using docopt
# =============================================================================


when isMainModule:
    import std/[strutils, times, os, json, sequtils, strformat, options]
    import docopt


    # =============================================================================
    # DOCOPT SPECIFICATION
    # =============================================================================





























# =============================================================================
# DEFINE SPESIFIC EXPORTS
# =============================================================================


when defined(test):
    export parseHexFloat, findLatestDowDate, getApplicableDowDate, getApplicableDowDateGlobal,
           generateGeohashString, md5ToCoordinateOffsets, applyOffsetsToGraticule
