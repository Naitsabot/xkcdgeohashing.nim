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
        let result = parseHexFloat("0.0000000000000001")
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
        let result = getApplicableDowDate(graticule, testDate)
        check result == testDate


    test "getApplicableDowDate - East of 30W uses previous day":
        let graticule = Graticule(lat: 68, lon: -29)
        let date: DateTime = dateTime(2012, mFeb, 24, 0, 0, 0, 0, utc()) # Friday
        let result = getApplicableDowDate(graticule, testDate)
        check result == (testDate - 1.days) # Should be prev day


    test "getApplicableDowDate - West of 30W uses same day - 2008-05-26 and earlier":
        let graticule = Graticule(lat: 68, lon: -30)
        let date: DateTime = dateTime(2007, mApr, 13, 0, 0, 0, 0, utc()) # Friday
        let result = getApplicableDowDate(graticule, testDate)
        check result == testDate

    test "getApplicableDowDate - East of 30W uses same day - 2008-05-26 and earlier":
        let graticule = Graticule(lat: 68, lon: -29)
        let date: DateTime = dateTime(2007, mApr, 13, 0, 0, 0, 0, utc()) # Friday
        let result = getApplicableDowDate(graticule, testDate)
        check result == testDate


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

            echo i

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


echo ""
