import unittest
import std/times

import xkcdgeohash


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


suite "Dow Jones Data Provider":
    test "getDefaultDowProvider returns HttpDowProvider":
        let provider: HttpDowProvider = getDefaultDowProvider()
        check provider != nil
        check provider is HttpDowProvider
    
    test "HttpDowProvider has expected sources":
        let provider = getDefaultDowProvider()
        check provider.sources.len == 4
        check provider.sources[0] == "http://carabiner.peeron.com/xkcd/map/data/"
        check provider.sources[1] == "http://geo.crox.net/djia/"
        check provider.sources[2] == "http://www1.geo.crox.net/djia/"
        check provider.sources[3] == "http://www2.geo.crox.net/djia/"


suite "Mock Dow Provider":
    test "Create mock provider":
        type MockDowProvider = ref object of DowJonesProvider
            data: seq[(DateTime, float)]
        
        skip()


#[ suite "Geohash Algorithm Core":
    skip() ]#


#[ suite "Public API":
    skip() ]#


# https://geohashing.site/geohashing/30W_Time_Zone_Rule
#[ suite "Official Test for 30W Time Zone Rule":
    skip() ]#


# https://geohashing.site/geohashing/30W_Time_Zone_Rule
#[ suite "Official Test for The Scientific Notation Bug":
    skip() ]#
