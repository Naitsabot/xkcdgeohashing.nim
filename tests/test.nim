## Geohashing library for Nim - Testing
##
## Implementation of the geohashing algorithm from https://xkcd.com/426/
## Algorithm spec can be seen at: https://geohashing.site/geohashing/The_Algorithm
## 
## Basic usage:
## Run: `nimble test`
##
## Copyright (c) 2025 Sebastian H. Lorenzen
## Licensed under MIT License

import unittest
import std/times

import xkcdgeohash

# Consts

# The refrence coordinates has a percition of something like 68.63099
# a change is likely of by a bit because of floating points
# a tolerance set to 0.000005 degrees corrospnds to ~0.56 meters
const GEO_TOLERANCE: float64 = 0.000005


# Mock Dow Jones Provider

type MockDowProvider = ref object of DowJonesProvider
    data: seq[(DateTime, float)]


method getDowPrice(dowProvider: MockDowProvider, date: Datetime): float =
    for (mockdate, price) in dowProvider.data:
        if mockdate.format("yyyy-MM-dd") == date.format("yyyy-MM-dd"):
            return price
        
    raise newException(DowDataError, "No mock data for date: " & date.format("yyyy-MM-dd"))


proc newMockDowProvider(data: seq[(DateTime, float)]): MockDowProvider =
    return MockDowProvider(data: data)


suite "Utility Functions":
    test "parseHexFloat  - basic conversion":
        check parseHexFloat($"0.DB9318c2259923d0") == 0.8577132677070023
      
    test "parseHexFloat - all zeros":
        check parseHexFloat("0.0000000000000000") == 0.0
    
    test "parseHexFloat - all F's (should be close to 1.0)":
        let result: float = parseHexFloat("0.FFFFFFFFFFFFFFFF")
        check result > 0.999999
        check result <= 1.0

    test "parseHexFloat - mixed letter case":
        check parseHexFloat("0.AbCdEf1234567890") == parseHexFloat("0.abcdef1234567890")
    
    test "parseHexFloat - invalid format raises exception":
        expect(ValueError):
            discard parseHexFloat("invalid")
        expect(ValueError):
            discard parseHexFloat("0.GGGG")
    
    test "parseHexFloat - small values":
        let result: float = parseHexFloat("0.0000000000000001")
        check result > 0.0
        check result < 0.000001  # Small but not zero
    
    test "findLatestDowDate - weekend handling":
        let saturday: DateTime = dateTime(2012, mMay, 20, 0, 0, 0, 0, utc()) # Sunday
        let result: DateTime = findLatestDowDate(saturday)
        check result.weekday != dSat
        check result.weekday != dSun
        check result <= saturday

    test "findLatestDowDate - weekday handling":
        let monday: DateTime = dateTime(2012, mMay, 21, 0, 0, 0, 0, utc()) # Monday
        let result: DateTime = findLatestDowDate(monday)
        check result.weekday == dMon

    test "getApplicableDowDate - West of 30W uses same day":
        let graticule: Graticule = Graticule(lat: 68, lon: -30)
        let date: DateTime = dateTime(2012, mFeb, 24, 0, 0, 0, 0, utc()) # Friday
        let result: DateTime = getApplicableDowDate(graticule, date)
        check result == date


    test "getApplicableDowDate - East of 30W uses previous day":
        let graticule = Graticule(lat: 68, lon: -29)
        let date: DateTime = dateTime(2012, mFeb, 24, 0, 0, 0, 0, utc()) # Friday
        let result: DateTime = getApplicableDowDate(graticule, date)
        check result == (date - 1.days) # Should be prev day


    test "getApplicableDowDate - West of 30W uses same day - 2008-05-26 and earlier":
        let graticule = Graticule(lat: 68, lon: -30)
        let date: DateTime = dateTime(2007, mApr, 13, 0, 0, 0, 0, utc()) # Friday
        let result: DateTime = getApplicableDowDate(graticule, date)
        check result == date

    test "getApplicableDowDate - East of 30W uses same day - 2008-05-26 and earlier":
        let graticule = Graticule(lat: 68, lon: -29)
        let date: DateTime = dateTime(2007, mApr, 13, 0, 0, 0, 0, utc()) # Friday
        let result: DateTime = getApplicableDowDate(graticule, date)
        check result == date
    
    test "getApplicableDowDateGlobal - always uses previous day":
        let monday: DateTime = dateTime(2025, mAug, 19, 0, 0, 0, 0, utc())
        let result: DateTime = getApplicableDowDateGlobal(monday)
        check result == dateTime(2025, mAug, 18, 0, 0, 0, 0, utc())
        

suite "Mock Dow Provider":
    test "Create mock provider with test data":
        let mockData: seq[(DateTime, float)] = @[
            (dateTime(2008, mMay, 26, 0, 0, 0, 0, utc()), 12620.90),
            (dateTime(2008, mMay, 27, 0, 0, 0, 0, utc()), 12479.63),
            (dateTime(2012, mFeb, 27, 0, 0, 0, 0, utc()), 12981.20)
        ]

        let dowProvider: MockDowProvider = newMockDowProvider(mockData)

        check dowProvider.getDowPrice(dateTime(2008, mMay, 26, 0, 0, 0, 0, utc())) == 12620.90
        check dowProvider.getDowPrice(dateTime(2008, mMay, 27, 0, 0, 0, 0, utc())) == 12479.63
        check dowProvider.getDowPrice(dateTime(2012, mFeb, 27, 0, 0, 0, 0, utc())) == 12981.20
    
    test "Mock provider throws error for missing dates":
        let dowProvider: MockDowProvider = newMockDowProvider(@[(dateTime(2008, mMay, 26), 12620.90)])
        
        # next day same month
        expect(DowDataError):
            discard dowProvider.getDowPrice(dateTime(2008, mMay, 27, 0, 0, 0, 0, utc()))


suite "Dow Jones Data Provider":
    test "getDefaultDowProvider - returns HttpDowProvider":
        let dowProvider: HttpDowProvider = getDefaultDowProvider()
        check dowProvider != nil
        check dowProvider is HttpDowProvider
    
    test "HttpDowProvider - expected sources":
        let dowProvider: HttpDowProvider = getDefaultDowProvider()
        check dowProvider.sources.len == 4
        check dowProvider.sources[0] == "http://carabiner.peeron.com/xkcd/map/data/"
        check dowProvider.sources[1] == "http://geo.crox.net/djia/"
        check dowProvider.sources[2] == "http://www1.geo.crox.net/djia/"
        check dowProvider.sources[3] == "http://www2.geo.crox.net/djia/"


suite "Geohash Algorithm Core":
    test "generateGeohashString - formatting":
        let date: DateTime = dateTime(2025, mAug, 18, 0, 0, 0, 0, utc())
        let price: float = 12345.67
        let result: string = generateGeohashString(date, price)
        check result == "2025-08-18-12345.67"
    
    test "generateGeohashString - formatting of price":
        let date: DateTime = dateTime(2025, mAug, 18, 0, 0, 0, 0, utc())
        let price: float = 12345.6
        let result: string = generateGeohashString(date, price)
        check result == "2025-08-18-12345.60"

    test "md5ToCoordinateOffsets - expected hash":
        # Values from: https://geohashing.site/geohashing/The_Algorithm#Specification
        let hashStr: string = "2005-05-26-10458.68"
        let (latOffset, lonOffset): (float, float) = md5ToCoordinateOffsets(hashStr)
        check abs(latOffset - 0.85771326770700234438) < 0.00000000001 # Seems like enougth precision
        check abs(lonOffset - 0.54454306955928210562) < 0.00000000001

    test "applyOffsetsToGraticule - positive graticule":
        let graticule: Graticule = Graticule(lat: 68, lon: -30)
        let latOffset: float = 0.85771326770700234438
        let lonOffset: float = 0.54454306955928210562

        let (finalLat, finalLon): (float, float) = applyOffsetsToGraticule(graticule, latOffset, lonOffset)

        check abs(finalLat - 68.85771326770700234438) < GEO_TOLERANCE
        check abs(finalLon - -30.54454306955928210562) < GEO_TOLERANCE

    test "applyOffsetsToGraticule - negative graticule":
        let graticule: Graticule = Graticule(lat: -1, lon: -1)
        let latOffset: float = 0.85771326770700234438
        let lonOffset: float = 0.54454306955928210562

        let (finalLat, finalLon): (float, float) = applyOffsetsToGraticule(graticule, latOffset, lonOffset)

        check abs(finalLat - -1.85771326770700234438) < GEO_TOLERANCE
        check abs(finalLon - -1.54454306955928210562) < GEO_TOLERANCE


suite "Public API":
    test "newGeohasher - valid object instance":
        let mockProvider: MockDowProvider = newMockDowProvider(@[(dateTime(2000, mDec, 13, 0, 0, 0, 0, utc()), 19992.19)])
        let geohasher: Geohasher = newGeohasher(68, -30, mockProvider)
        
        check geohasher.graticule.lat == 68
        check geohasher.graticule.lon == -30
        check geohasher.dowProvider == mockProvider
    
    test "newGlobalGeohasher - valid object instance":
        let mockProvider: MockDowProvider = newMockDowProvider(@[(dateTime(2008, mMay, 20), 13026.04)])
        let globalGeohasher: GlobalGeohasher = newGlobalGeohasher(mockProvider)
        
        check globalGeohasher.dowProvider == mockProvider

    test "Geohasher.hash - expected results from known data":
        let mockData: seq[(DateTime, float)] = @[
            (dateTime(2012, mFeb, 24, 0, 0, 0, 0, utc()), 12981.20), # Fri
            (dateTime(2012, mFeb, 25, 0, 0, 0, 0, utc()), 12981.20), # Sat
            (dateTime(2012, mFeb, 26, 0, 0, 0, 0, utc()), 12981.20) # Sun
        ]
        let mockProvider: MockDowProvider = newMockDowProvider(mockData)
        
        let result: GeohashResult = xkcdgeohash(68.0, -29.0, dateTime(2012, mFeb, 26), mockProvider)

        check abs(result.latitude - 68.000047) < GEO_TOLERANCE
        check abs(result.longitude - -29.483719) < GEO_TOLERANCE
        check result.usedDowDate.format("yyyy-MM-dd") == "2012-02-24"
        check result.usedDate.format("yyyy-MM-dd") == "2012-02-26"

    test "Geohasher.hash - expected results with known data - xkcd comic":
        let mockData: seq[(DateTime, float)] = @[(dateTime(2005, mMay, 26), 10458.68)]
        let mockProvider: MockDowProvider = newMockDowProvider(mockData)
        let geohasher: Geohasher = newGeohasher(37, -122, mockProvider)
        
        let result: GeohashResult = geohasher.hash(dateTime(2005, mMay, 26))
        
        check abs(result.latitude - 37.857713) < GEO_TOLERANCE
        check abs(result.longitude - -122.544544) < GEO_TOLERANCE
        check result.usedDowDate.format("yyyy-MM-dd") == "2005-05-26"
    
    test "GlobalGeohasher.hash - expected results from known data":
        let mockData: seq[(DateTime, float)] = @[
            (dateTime(2008, mMay, 20, 0, 0, 0, 0, utc()), 13026.04)
        ]
        let mockProvider: MockDowProvider = newMockDowProvider(mockData)
        let globalGeohasher: GlobalGeohasher = newGlobalGeohasher(mockProvider)
        
        let result: GeohashResult = globalGeohasher.hash(dateTime(2008, mMay, 21, 0, 0, 0, 0, utc()))
        
        check abs(result.latitude - 85.74626) < GEO_TOLERANCE
        check abs(result.longitude - 146.18662) < GEO_TOLERANCE
        check result.usedDate.format("yyyy-MM-dd") == "2008-05-21"
        check result.usedDowDate.format("yyyy-MM-dd") == "2008-05-20"

    test "xkcdgeohash - exprected results":
        let mockData: seq[(DateTime, float)] = @[
            (dateTime(2012, mFeb, 24, 0, 0, 0, 0, utc()), 12981.20), # Fri
            (dateTime(2012, mFeb, 25, 0, 0, 0, 0, utc()), 12981.20), # Sat
            (dateTime(2012, mFeb, 26, 0, 0, 0, 0, utc()), 12981.20) # Sun
        ]
        let mockProvider: MockDowProvider = newMockDowProvider(mockData)
        
        let result: GeohashResult = xkcdgeohash(68.0, -30.0, dateTime(2012, mFeb, 26, 0, 0, 0, 0, utc()), mockProvider)
        
        check abs(result.latitude - 68.000047) < GEO_TOLERANCE
        check abs(result.longitude - -30.483719) < GEO_TOLERANCE

    test "xkcdgeohash - 30W rule test (west side)":
        let mockData: seq[(DateTime, float)] = @[(dateTime(2025, mAug, 19), 12981.20)]
        let mockProvider: MockDowProvider = newMockDowProvider(mockData)
        
        # Minneapolis area (west of 30W)
        let result: GeohashResult = xkcdgeohash(45.0, -93.0, dateTime(2025, mAug, 19), mockProvider)
        
        check result.usedDowDate.format("yyyy-MM-dd") == "2025-08-19"  # Same day
        check result.usedDate.format("yyyy-MM-dd") == "2025-08-19"

    test "xkcdgeohash - 30W rule test (east side)":
        let mockData: seq[(DateTime, float)] = @[(dateTime(2025, mAug, 18), 12981.20)]  # Note: previous day
        let mockProvider: MockDowProvider = newMockDowProvider(mockData)
        
        # Berlin area (east of 30W)  
        let result: GeohashResult = xkcdgeohash(52.0, 13.0, dateTime(2025, mAug, 19), mockProvider)
        
        check result.usedDowDate.format("yyyy-MM-dd") == "2025-08-18"  # Previous day
        check result.usedDate.format("yyyy-MM-dd") == "2025-08-19"
    
    test "xkcdglobalgeohash - expected results":
        let mockData: seq[(DateTime, float)] = @[
            (dateTime(2008, mMay, 20, 0, 0, 0, 0, utc()), 13026.04)
        ]
        let mockProvider: MockDowProvider = newMockDowProvider(mockData)
        
        let result: GeohashResult = xkcdglobalgeohash(dateTime(2008, mMay, 21, 0, 0, 0, 0, utc()), mockProvider)
        
        check abs(result.latitude - 85.74626) < GEO_TOLERANCE
        check abs(result.longitude - 146.18662) < GEO_TOLERANCE


# https://geohashing.site/geohashing/30W_Time_Zone_Rule#Testing_for_30W_compliance
suite "Official Test for 30W Time Zone Rule":
    test "2008-05-26 and earlier":
        let westExpected: seq[(float, float)] = @[
            (68.63099, -30.61895),
            (68.17947, -30.86154),
            (68.97287, -30.2387),
            (68.40025, -30.72277),
            (68.12665, -30.54753),
            (68.94177, -30.18287),
            (68.67313, -30.60731),
        ]

        let eastExpected: seq[(float, float)] = @[
            (68.63099, -29.61895),
            (68.17947, -29.86154),
            (68.97287, -29.2387),
            (68.40025, -29.72277),
            (68.12665, -29.54753),
            (68.94177, -29.18287),
            (68.67313, -29.60731),
        ] 

        let mockData: seq[(DateTime, float)] = @[
            (dateTime(2008, mMay, 20, 0, 0, 0, 0, utc()), 13026.04),
            (dateTime(2008, mMay, 21, 0, 0, 0, 0, utc()), 12824.94),
            (dateTime(2008, mMay, 22, 0, 0, 0, 0, utc()), 12597.69),
            (dateTime(2008, mMay, 23, 0, 0, 0, 0, utc()), 12620.90),
            (dateTime(2008, mMay, 24, 0, 0, 0, 0, utc()), 12620.90),
            (dateTime(2008, mMay, 25, 0, 0, 0, 0, utc()), 12620.90),
            (dateTime(2008, mMay, 26, 0, 0, 0, 0, utc()), 12620.90),
        ]
        let dowProvider: MockDowProvider = newMockDowProvider(mockData)

        for i in 0 .. (mockData.len - 1):
            let date: Datetime = mockData[i][0]

            let westGeohasher: Geohasher = newGeohasher(68, -30, dowProvider)
            let eastGeohasher: Geohasher = newGeohasher(68, -29, dowProvider)

            let westResult: GeohashResult = westGeohasher.hash(date)
            let eastResult: GeohashResult = eastGeohasher.hash(date)

            check abs(westResult.latitude - westExpected[i][0]) < GEO_TOLERANCE
            check abs(eastResult.latitude - eastExpected[i][0]) < GEO_TOLERANCE

            check abs(westResult.longitude - westExpected[i][1]) < GEO_TOLERANCE
            check abs(eastResult.longitude - eastExpected[i][1]) < GEO_TOLERANCE


    test "2008-05-27 and later":
        let westExpected: seq[(float, float)] = @[
            (68.20968, -30.10144),
            (68.68745, -30.21221),
            (68.4647, -30.03412),
            (68.8531, -30.2446),
        ]

        let eastExpected: seq[(float, float)] = @[
            (68.12537, -29.57711),
            (68.71044, -29.11273),
            (68.27833, -29.74114),
            (68.32272, -29.70458),
        ] 

        let mockData: seq[(DateTime, float)] = @[
            (dateTime(2008, mMay, 26, 0, 0, 0, 0, utc()), 12620.90), # Needed for 2008-05-27 east
            (dateTime(2008, mMay, 27, 0, 0, 0, 0, utc()), 12479.63),
            (dateTime(2008, mMay, 28, 0, 0, 0, 0, utc()), 12542.90),
            (dateTime(2008, mMay, 29, 0, 0, 0, 0, utc()), 12593.87),
            (dateTime(2008, mMay, 30, 0, 0, 0, 0, utc()), 12647.36),
        ]
        let dowProvider = newMockDowProvider(mockData)

        for i in 0 .. (mockData.len - 2):
            let date: Datetime = mockData[1 + i][0]

            let westGeohasher: Geohasher = newGeohasher(68, -30, dowProvider)
            let eastGeohasher: Geohasher = newGeohasher(68, -29, dowProvider)

            let westResult: GeohashResult = westGeohasher.hash(date)
            let eastResult: GeohashResult = eastGeohasher.hash(date)

            if date >= dateTime(2008, mMay, 27, 0, 0, 0, 0, utc()):
                check westResult.usedDowDate == date  # West = same day
                check eastResult.usedDowDate == (date - 1.days)  # East = previous day

            check abs(westResult.latitude - westExpected[i][0]) < GEO_TOLERANCE
            check abs(eastResult.latitude - eastExpected[i][0]) < GEO_TOLERANCE

            check abs(westResult.longitude - westExpected[i][1]) < GEO_TOLERANCE
            check abs(eastResult.longitude - eastExpected[i][1]) < GEO_TOLERANCE
    
    test "Global - 2008-05-21 to 2008-05-30 (2008-05-20 excluded)":
        let expected: seq[(float, float)] = @[
            (85.74626, 146.18662), # 2008-05-21
            (61.62927, 69.96869),
            (78.42559, 129.50128),
            (-67.20336, 17.11192),
            (79.51947, -114.16550),
            (31.16306, 38.63088),
            (-67.43391, 27.75993),
            (37.87947, -139.41640),
            (-39.90121, 86.81114),
            (-31.91030, 73.65004),
        ] 

        let mockData: seq[(DateTime, float)] = @[
            (dateTime(2008, mMay, 20, 0, 0, 0, 0, utc()), 13026.04), # Needed for 2008-05-21 as prev day
            (dateTime(2008, mMay, 21, 0, 0, 0, 0, utc()), 12824.94),
            (dateTime(2008, mMay, 22, 0, 0, 0, 0, utc()), 12597.69),
            (dateTime(2008, mMay, 23, 0, 0, 0, 0, utc()), 12620.90),
            (dateTime(2008, mMay, 24, 0, 0, 0, 0, utc()), 12620.90),
            (dateTime(2008, mMay, 25, 0, 0, 0, 0, utc()), 12620.90),
            (dateTime(2008, mMay, 26, 0, 0, 0, 0, utc()), 12620.90),
            (dateTime(2008, mMay, 27, 0, 0, 0, 0, utc()), 12479.63),
            (dateTime(2008, mMay, 28, 0, 0, 0, 0, utc()), 12542.90),
            (dateTime(2008, mMay, 29, 0, 0, 0, 0, utc()), 12593.87),
            (dateTime(2008, mMay, 30, 0, 0, 0, 0, utc()), 12647.36),
        ]
        let dowProvider = newMockDowProvider(mockData)

        for i in 0 .. (mockData.len - 2):
            let date: Datetime = mockData[1 + i][0]

            let globalGeohasher: GlobalGeohasher = newGlobalGeohasher(dowProvider)

            let result: GeohashResult = globalGeohasher.hash(date)

            check abs(result.latitude - expected[i][0]) < GEO_TOLERANCE
            check abs(result.longitude - expected[i][1]) < GEO_TOLERANCE


# https://geohashing.site/geohashing/30W_Time_Zone_Rule#Testing_for_the_scientific_notation_bug
suite "Official Test for The Scientific Notation Bug":
    test "2012-02-26 coordinates testdata edge case":
        let mockData: seq[(DateTime, float)] = @[
            (dateTime(2012, mFeb, 24, 0, 0, 0, 0, utc()), 12981.20), # Fri
            (dateTime(2012, mFeb, 25, 0, 0, 0, 0, utc()), 12981.20), # Sat
            (dateTime(2012, mFeb, 26, 0, 0, 0, 0, utc()), 12981.20) # Sun
        ]
        let dowProvider: MockDowProvider = newMockDowProvider(mockData)

        let date: Datetime = dateTime(2012, mFeb, 26, 0, 0, 0, 0, utc())

        let westGeohasher: Geohasher = newGeohasher(68, -30, dowProvider)
        let eastGeohasher: Geohasher = newGeohasher(68, -29, dowProvider)

        let westResult: GeohashResult = westGeohasher.hash(date)
        let eastResult: GeohashResult = eastGeohasher.hash(date)

        check abs(westResult.latitude - 68.000047) < GEO_TOLERANCE
        check abs(eastResult.latitude - 68.000047) < GEO_TOLERANCE

        check abs(westResult.longitude - -30.483719) < GEO_TOLERANCE
        check abs(eastResult.longitude - -29.483719) < GEO_TOLERANCE
    
    test "Global - 2012-02-26 coordinates testdata edge case":
        let mockData: seq[(DateTime, float)] = @[
            (dateTime(2012, mFeb, 24, 0, 0, 0, 0, utc()), 12981.20), # Fri
            (dateTime(2012, mFeb, 25, 0, 0, 0, 0, utc()), 12981.20), # Sat
            (dateTime(2012, mFeb, 26, 0, 0, 0, 0, utc()), 12981.20) # Sun
        ]
        let dowProvider: MockDowProvider = newMockDowProvider(mockData)

        let date: Datetime = dateTime(2012, mFeb, 26, 0, 0, 0, 0, utc())

        let globalGeohasher: GlobalGeohasher = newGlobalGeohasher(dowProvider)

        let result: GeohashResult = globalGeohasher.hash(date)

        check abs(result.latitude - -89.99161) < GEO_TOLERANCE
        check abs(result.longitude - -5.86128) < GEO_TOLERANCE


suite "Operator Overloads":
    test "Graticule string representation":
        let graticule = Graticule(lat: 68, lon: -30)
        check $graticule == "(68, -30)"
        
        let negativeGraticule = Graticule(lat: -45, lon: 93)
        check $negativeGraticule == "(-45, 93)"

    test "Graticule equality":
        let graticule1 = Graticule(lat: 68, lon: -30)
        let graticule2 = Graticule(lat: 68, lon: -30)
        let graticule3 = Graticule(lat: 45, lon: -93)
        
        check graticule1 == graticule2
        check graticule1 != graticule3

    test "Graticule ordering":
        let graticule1 = Graticule(lat: 45, lon: -93)
        let graticule2 = Graticule(lat: 68, lon: -30)
        let graticule3 = Graticule(lat: 45, lon: -30)
        
        check graticule1 < graticule2  # lat: 45 < 68
        check graticule1 < graticule3  # same lat, lon: -93 < -30
        check graticule1 <= graticule1  # equal
        check graticule1 <= graticule2  # less than

    test "GeohashResult string representation":
        let result = GeohashResult(
            latitude: 68.857713,
            longitude: -30.544544,
            usedDate: dateTime(2008, mMay, 26),
            usedDowDate: dateTime(2008, mMay, 26)
        )
        let expected = "GeohashResult(lat: 68.857713, lon: -30.544544, usedDate: 2008-05-26, usedDowDate: 2008-05-26)"
        check $result == expected

    test "GeohashResult equality":
        let result1 = GeohashResult(
            latitude: 68.857713,
            longitude: -30.544544,
            usedDate: dateTime(2008, mMay, 26),
            usedDowDate: dateTime(2008, mMay, 26)
        )
        let result2 = GeohashResult(
            latitude: 68.857713,
            longitude: -30.544544,
            usedDate: dateTime(2008, mMay, 26),
            usedDowDate: dateTime(2008, mMay, 26)
        )
        let result3 = GeohashResult(
            latitude: 45.123456,
            longitude: -93.654321,
            usedDate: dateTime(2008, mMay, 27),
            usedDowDate: dateTime(2008, mMay, 26)
        )
        
        check result1 == result2
        check result1 != result3

    test "GeohashResult ordering":
        let result1 = GeohashResult(
            latitude: 45.0,
            longitude: -93.0,
            usedDate: dateTime(2008, mMay, 26),
            usedDowDate: dateTime(2008, mMay, 26)
        )
        let result2 = GeohashResult(
            latitude: 68.0,
            longitude: -30.0,
            usedDate: dateTime(2008, mMay, 27),
            usedDowDate: dateTime(2008, mMay, 27)
        )
        let result3 = GeohashResult(
            latitude: 45.0,
            longitude: -95.0,
            usedDate: dateTime(2008, mMay, 26),
            usedDowDate: dateTime(2008, mMay, 26)
        )
        
        check result1 < result2  # earlier date
        check result3 < result1  # same date, same lat, lon: -95.0 < -93.0
        check result1 <= result1  # equal
        check result1 <= result2  # less than

    test "Geohasher string representation":
        let mockProvider = newMockDowProvider(@[(dateTime(2008, mMay, 26), 12620.90)])
        let geohasher = newGeohasher(68, -30, mockProvider)
        check $geohasher == "Geohasher((68, -30))"

    test "Geohasher equality":
        let mockProvider1 = newMockDowProvider(@[(dateTime(2008, mMay, 26), 12620.90)])
        let mockProvider2 = newMockDowProvider(@[(dateTime(2008, mMay, 27), 12479.63)])
        
        let geohasher1 = newGeohasher(68, -30, mockProvider1)
        let geohasher2 = newGeohasher(68, -30, mockProvider2)
        let geohasher3 = newGeohasher(45, -93, mockProvider1)
        
        check geohasher1 == geohasher2  # same graticule, different providers
        check geohasher1 != geohasher3  # different graticule

    test "GlobalGeohasher string representation":
        let mockProvider = newMockDowProvider(@[(dateTime(2008, mMay, 26), 12620.90)])
        let globalGeohasher = newGlobalGeohasher(mockProvider)
        check $globalGeohasher == "GlobalGeohasher()"

    test "GlobalGeohasher equality":
        let mockProvider1 = newMockDowProvider(@[(dateTime(2008, mMay, 26), 12620.90)])
        let mockProvider2 = newMockDowProvider(@[(dateTime(2008, mMay, 27), 12479.63)])
        
        let globalGeohasher1 = newGlobalGeohasher(mockProvider1)
        let globalGeohasher2 = newGlobalGeohasher(mockProvider1)
        let globalGeohasher3 = newGlobalGeohasher(mockProvider2)
        
        check globalGeohasher1 == globalGeohasher2  # same provider
        check globalGeohasher1 != globalGeohasher3  # different providers

    test "GlobalGeohasher ordering":
        let mockProvider1 = newMockDowProvider(@[(dateTime(2008, mMay, 26), 12620.90)])
        let mockProvider2 = newMockDowProvider(@[(dateTime(2008, mMay, 27), 12479.63)])
        
        let globalGeohasher1 = newGlobalGeohasher(mockProvider1)
        let globalGeohasher2 = newGlobalGeohasher(mockProvider2)
        
        # Ordering is based on pointer comparison, so we just check consistency
        let isLess = globalGeohasher1 < globalGeohasher2
        check (globalGeohasher1 < globalGeohasher2) != (globalGeohasher2 < globalGeohasher1)  # antisymmetric
        check globalGeohasher1 <= globalGeohasher1  # reflexive
        
        if isLess:
            check globalGeohasher1 <= globalGeohasher2
        else:
            check globalGeohasher2 <= globalGeohasher1


echo ""
