## Geohashing library for Nim
##
## Implementation of the geohashing algorithm from https://xkcd.com/426/
## Algorithm spec can be seen at: https://geohashing.site/geohashing/The_Algorithm
## 
## Basic usage:
##
## Copyright (c) 2025 Your Name
## Licensed under MIT License

import std/[httpclient, math, md5, options, parseutils, strutils, times]


type
    # Geohashing Types
    Graticule* = object
        lat*: int # -90 to +90 (ambigious -0/+0 distriction excluded)
        lon*: int # -179 to +179 (ambigious -0/+0 distriction excluded)
    
    GeohashResult* = object
        latitude*: float
        longitude*: float
        usedDowDate*: DateTime
    
    Geohasher* = object
        graticule*: Graticule
        dowProvider*: DowJonesProvider  # Selected at runtime (strategy/policy pattern)
    
    # Strategy Interface
    DowJonesProvider* = ref object of RootObj

    HttpDowProvider* = ref object of DowJonesProvider
        sources*: seq[string]
        currentSourceIndex*: int

    # Exeption Types
    GeohashError* = object of CatchableError
    DowDataError* = object of GeohashError


const DOW_JONES_SOURCES: array[0..3, string] = 
    ["http://carabiner.peeron.com/xkcd/map/data/", "http://geo.crox.net/djia/",
     "http://www1.geo.crox.net/djia/", "http://www2.geo.crox.net/djia/"]


proc getDefaultDowProvider*(): DowJonesProvider = 
    return HttpDowProvider(
        sources: @DOW_JONES_SOURCES,
        currentSourceIndex: 0
    )


proc fetchFromSource(source: string, date: Datetime): float =
    let client = newHttpClient()
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


proc parseHexFloat*(hexStr: string): float =
    let hexPart = hexStr[2..^1]  # Removes "0."
    var intValue: uint64
    if parseHex(hexPart, intValue) != hexPart.len:
        raise newException(ValueError, "Invalid hex string: " & hexStr)
    return float(intValue) / float(uint64.high)


proc findLatestDowDate(targetDate: DateTime): Datetime = 
    # TODO: Check for holidays! https://geohashing.site/geohashing/Dow_holiday
    var checkDate: Datetime = targetDate

    while checkDate.weekDay == dSat or checkDate.weekDay == dSun:
        checkDate = checkDate - 1.days
    
    return checkDate


proc getApplicableDowDate(graticule: Graticule, targetDate: DateTime): DateTime =
    ## Determine the applicable Dow Jones opening date "DJOD"
    
    if graticule.lon >= -179 and graticule.lon <= -30:
        # If the longitude is between -179 and -30 inclusive, 
        # use the latest date up to and including GD on which 
        # a Dow Jones opening price has been or will be published.
        # (On weekends and Dow holidays, DJOD will be earlier than GD.)

        # using date up to and including targetDate
        result = findLatestDowDate(targetDate)
    else:
        # Otherwise (if the longitude is between -29 and +179 inclusive), 
        # use the latest date up to and including one day before GD on 
        # which a Dow Jones opening price has been or will be published. 
        # (DJOD will always be at least one day earlier than GD.)

        # using date up to and including (targetDate - 1 day)
        result = findLatestDowDate(targetDate)
    return


method getDowPrice(provider: DowJonesProvider, date: DateTime): float {.base.} =
    # Obtain the opening price of the Dow Jones Industrial Average for the DJOD. 
    # This is usually available from 9.30 am New York time, and published to two decimal places.

    raise newException(CatchableError, "Not Implemented")


method getDowPrice(provider: HttpDowProvider, date: Datetime): float =
    # trying each soruce untill it either works or dosn't
    var lastError: ref Exception = nil

    for i in 0..provider.sources.len:
        let sourceIndex  = (provider.currentSourceIndex + i) mod provider.sources.len
        let source = provider.sources[sourceIndex]

        try:
            let price = fetchFromSource(source, date)
            
            provider.currentSourceIndex = sourceIndex

            return price
        
        except Exception as e:
            lastError = e
            continue # failed, try next source
    
    raise newException(DowDataError, "All Dow Jones sources failed. Last error: " & (if lastError != nil: lastError.msg else: "Unknown error"))


proc generateGeohashString(date: Datetime, dowPrice: float): string =
    # Form a string by concatenating GD (in YYYY-MM-DD format), 
    # a hyphen "-", and the applicable opening price. 
    # For example: "2005-05-26-10458.68"

    let dateStr: string = date.format("yyyy-MM-dd")
    let priceStr: string = dowPrice.formatFloat(format = ffDecimal, precision = 2) # formats floats to two decimals
    return datestr & "-" & priceStr


proc md5ToCoordinateOffsets(hashStr: string): (float, float) =
    # Pass this string through the MD5 cryptographic algorithm to 
    # generate an MD5 hash of 32 hexadecimal digits.
    # Split the hash into two halves of 16 hexadecimal digits each.
    # Prepend a decimal point before each half, 
    # forming a hexadecimal number between 0 and 1. (Example: 0.db9318c2259923d0)
    # Convert each half to decimal. (Example: 0.857713267707002344)
    
    # https://nim-lang.org/docs/md5.html
    let hash: string = getMD5(hashStr)
    let latitudeHex: string = "0." & hash[0..15]
    let longitudeHex: string = "0." & hash[16..31]

    # Convert hex to decimal
    let latitudeOffset: float = parseHexFloat(latitudeHex)
    let longitudeOffset: float = parseHexFloat(longitudeHex)

    return (latitudeOffset, longitudeOffset)


proc applyOffsetsToGraticule(graticule: Graticule, latitudeOffset: float, longitudeOffset: float): (float, float) =
    # Append the first decimal number formed, without the leading 0, to the graticule's 
    # latitude to form the geohash latitude. (Note this is a string operation: appending 
    # 0.8577 to longitude -1 yields -1.8577)
    # Similarly, append the second decimal number formed to the graticule's longitude to 
    # form the geohash longitude.

    let latitudeStr: string = $graticule.lat & "." & ($latitudeOffset)[2..^1]
    let longitudeStr: string = $graticule.lon & "." & ($longitudeOffset)[2..^1]
    
    return (parseFloat(latitudeStr), parseFloat(longitudeStr))


proc hash*(geohasher: Geohasher, date: Datetime): GeohashResult =
    let dowDate: Datetime = getApplicableDowDate(geohasher.graticule, date)
    let dowPrice: float = geohasher.dowProvider.getDowPrice(dowDate)
    let hashStr: string = generateGeohashString(dowDate, dowPrice)
    let (latitudeOffset, longitudeOffset): (float, float) = md5ToCoordinateOffsets(hashStr)
    let (finalLatitude, finalLongitude): (float, float) = applyOffsetsToGraticule(geohasher.graticule, latitudeOffset, longitudeOffset)

    return GeohashResult(
        latitude: finalLatitude,
        longitude: finalLongitude,
        usedDowDate: dowDate
    )


proc xkcdgeohash*(latitude: float, longitude: float, date: DateTime, dowProvider: DowJonesProvider = getDefaultDowProvider()): GeohashResult =
    let graticule = Graticule(lat: int(latitude), lon: int(longitude))
    let geohasher = Geohasher(graticule: graticule, dowProvider: dowProvider)
    return geohasher.hash(date)


proc newGeohasher*(latitude: int, longitude: int, dowProvider: DowJonesProvider = getDefaultDowProvider()): Geohasher =
    return Geohasher(
        graticule: Graticule(lat: latitude, lon: longitude),
        dowProvider: dowProvider
    )


when isMainModule:
    echo parseHexFloat($"0.DB9318c2259923d0")