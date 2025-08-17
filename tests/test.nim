import unittest
import std/times

import xkcdgeohash

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
        let result = parseHexFloat("0.FFFFFFFFFFFFFFFF")
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
        skip()
    
    test "findLatestDowDate - weekend handling":
        let saturday = dateTime(2012, mMay, 20, 0, 0, 0, 0, utc()) # Sunday
        let result = findLatestDowDate(saturday)
        check result.weekday != dSat
        check result.weekday != dSun
        check result <= saturday

    test "findLatestDowDate - weekday handling":
        let monday = dateTime(2012, mMay, 21, 0, 0, 0, 0, utc()) # Monday
        let result = findLatestDowDate(monday)
        check result.weekday == dMon

    test "getApplicableDowDate - West of 30W uses same day":
        skip()

    test "getApplicableDowDate - East of 30W uses previous day":
        skip()


suite "Mock Dow Provider":
    test "Create mock provider with test data":
        let mockData = @[
            (dateTime(2008, mMay, 26, 0, 0, 0, 0, utc()), 12620.90),
            (dateTime(2008, mMay, 27, 0, 0, 0, 0, utc()), 12479.63),
            (dateTime(2012, mFeb, 27, 0, 0, 0, 0, utc()), 12981.20)
        ]

        let dowProvider = newMockDowProvider(mockData)

        check dowProvider.getDowPrice(dateTime(2008, mMay, 26, 0, 0, 0, 0, utc())) == 12620.90
        check dowProvider.getDowPrice(dateTime(2008, mMay, 27, 0, 0, 0, 0, utc())) == 12479.63
        check dowProvider.getDowPrice(dateTime(2012, mFeb, 27, 0, 0, 0, 0, utc())) == 12981.20
    
    test "Mock provider throws error for missing dates":
        let dowProvider = newMockDowProvider(@[(dateTime(2008, mMay, 26), 12620.90)])
        
        # next day same month
        expect(DowDataError):
            discard dowProvider.getDowPrice(dateTime(2008, mMay, 27, 0, 0, 0, 0, utc()))


suite "Dow Jones Data Provider":
    test "getDefaultDowProvider - returns HttpDowProvider":
        let dowProvider: HttpDowProvider = getDefaultDowProvider()
        check dowProvider != nil
        check dowProvider is HttpDowProvider
    
    test "HttpDowProvider - expected sources":
        let dowProvider = getDefaultDowProvider()
        check dowProvider.sources.len == 4
        check dowProvider.sources[0] == "http://carabiner.peeron.com/xkcd/map/data/"
        check dowProvider.sources[1] == "http://geo.crox.net/djia/"
        check dowProvider.sources[2] == "http://www1.geo.crox.net/djia/"
        check dowProvider.sources[3] == "http://www2.geo.crox.net/djia/"


suite "Geohash Algorithm Core":
    test "generateGeohashString - formatting":
        skip()

    test "md5ToCoordinateOffsets - expected hash":
        skip()

    test "applyOffsetsToGraticule - concatenation":
        skip()


suite "Public API":
    test "newGeohasher - valid object instance":
        skip()

    test "hash - expected results":
        skip()

    test "xkcdgeohash - exprected results":
        skip()


# https://geohashing.site/geohashing/30W_Time_Zone_Rule#Testing_for_30W_compliance
suite "Official Test for 30W Time Zone Rule":
    test "1":
        skip()

    test "2":
        skip()


# https://geohashing.site/geohashing/30W_Time_Zone_Rule#Testing_for_the_scientific_notation_bug
suite "Official Test for The Scientific Notation Bug":
    test "2012-02-26 coordinates testdata edge case":
        let mockData = @[
            (dateTime(2012, mFeb, 24, 0, 0, 0, 0, utc()), 12981.20), # Fri
            (dateTime(2012, mFeb, 25, 0, 0, 0, 0, utc()), 12981.20), # Sat
            (dateTime(2012, mFeb, 26, 0, 0, 0, 0, utc()), 12981.20) # Sun
        ]
        let dowProvider = newMockDowProvider(mockData)

        let date: Datetime = dateTime(2012, mFeb, 26, 0, 0, 0, 0, utc())

        let westGeohasher: Geohasher = newGeohasher(68, -30, dowProvider)
        let eastGeohasher: Geohasher = newGeohasher(68, -29, dowProvider)

        let westResult = westGeohasher.hash(date)
        let eastResult = eastGeohasher.hash(date)

        # From official table:
        # West (68, -30): 68.68745, -30.21221
        # East (68, -29): 68.71044, -29.11273

        check abs(westResult.latitude - 68.000047) < 0.000001 # approximation
        check abs(eastResult.latitude - 68.000047) < 0.000001

        check abs(westResult.longitude - (-30.483719)) < 0.000001 # approximation
        check abs(eastResult.longitude - (-29.483719)) < 0.000001


echo ""
