## Geohashing library for Nim - Mock Dow Jones Provider and data for testing
##
## Copyright (c) 2025 Sebastian H. Lorenzen
## Licensed under MIT License


import std/[times]

import xkcdgeohash


# =============================================================================
# MOCK DOW JONES PROVIDER FOR TESTING PURPOSES
# =============================================================================


type MockDowProvider = ref object of DowJonesProvider
    data: seq[(DateTime, float)]


method getDowPrice(dowProvider: MockDowProvider, date: Datetime): float =
    for (mockdate, price) in dowProvider.data:
        if mockdate.format("yyyy-MM-dd") == date.format("yyyy-MM-dd"):
            return price
        
    raise newException(DowDataError, "No mock data for date: " & date.format("yyyy-MM-dd"))


proc newMockDowProvider(data: seq[(DateTime, float)]): MockDowProvider =
    return MockDowProvider(data: data)


let mockData: seq[(DateTime, float)] = @[
    # 2008-05-26 range (-5 to +5)
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
    (dateTime(2008, mMay, 31, 0, 0, 0, 0, utc()), 12700.15),
    
    # 2000-02-02 range (-5 to +5)
    (dateTime(2000, mJan, 28, 0, 0, 0, 0, utc()), 10305.76),
    (dateTime(2000, mJan, 29, 0, 0, 0, 0, utc()), 10350.25),
    (dateTime(2000, mJan, 30, 0, 0, 0, 0, utc()), 10400.73),
    (dateTime(2000, mJan, 31, 0, 0, 0, 0, utc()), 10940.53),
    (dateTime(2000, mFeb, 1, 0, 0, 0, 0, utc()), 10960.43),
    (dateTime(2000, mFeb, 2, 0, 0, 0, 0, utc()), 10980.77),
    (dateTime(2000, mFeb, 3, 0, 0, 0, 0, utc()), 10997.92),
    (dateTime(2000, mFeb, 4, 0, 0, 0, 0, utc()), 11020.84),
    (dateTime(2000, mFeb, 5, 0, 0, 0, 0, utc()), 11041.67),
    (dateTime(2000, mFeb, 6, 0, 0, 0, 0, utc()), 11062.55),
    (dateTime(2000, mFeb, 7, 0, 0, 0, 0, utc()), 11083.24),
    
    # 2012-12-12 range (-5 to +5)
    (dateTime(2012, mDec, 7, 0, 0, 0, 0, utc()), 13025.58),
    (dateTime(2012, mDec, 8, 0, 0, 0, 0, utc()), 13040.77),
    (dateTime(2012, mDec, 9, 0, 0, 0, 0, utc()), 13055.94),
    (dateTime(2012, mDec, 10, 0, 0, 0, 0, utc()), 13070.13),
    (dateTime(2012, mDec, 11, 0, 0, 0, 0, utc()), 13085.25),
    (dateTime(2012, mDec, 12, 0, 0, 0, 0, utc()), 13100.34),
    (dateTime(2012, mDec, 13, 0, 0, 0, 0, utc()), 13115.67),
    (dateTime(2012, mDec, 14, 0, 0, 0, 0, utc()), 13130.89),
    (dateTime(2012, mDec, 15, 0, 0, 0, 0, utc()), 13145.82),
    (dateTime(2012, mDec, 16, 0, 0, 0, 0, utc()), 13160.45),
    (dateTime(2012, mDec, 17, 0, 0, 0, 0, utc()), 13175.73),
    
    # Current date range (-5 to +5) - using 2025-08-24 as base
    (dateTime(2025, mJul, 25, 0, 0, 0, 0, utc()), 38700.45),
    (dateTime(2025, mJul, 26, 0, 0, 0, 0, utc()), 38750.78),
    (dateTime(2025, mJul, 27, 0, 0, 0, 0, utc()), 38800.23),
    (dateTime(2025, mJul, 28, 0, 0, 0, 0, utc()), 38850.56),
    (dateTime(2025, mJul, 29, 0, 0, 0, 0, utc()), 38900.89),
    (dateTime(2025, mJul, 30, 0, 0, 0, 0, utc()), 38950.15),
    (dateTime(2025, mJul, 31, 0, 0, 0, 0, utc()), 39000.42),
    (dateTime(2025, mAug, 1, 0, 0, 0, 0, utc()), 39050.67),
    (dateTime(2025, mAug, 2, 0, 0, 0, 0, utc()), 39100.23),
    (dateTime(2025, mAug, 3, 0, 0, 0, 0, utc()), 39150.78),
    (dateTime(2025, mAug, 4, 0, 0, 0, 0, utc()), 39200.34),
    (dateTime(2025, mAug, 5, 0, 0, 0, 0, utc()), 39250.89),
    (dateTime(2025, mAug, 6, 0, 0, 0, 0, utc()), 39300.45),
    (dateTime(2025, mAug, 7, 0, 0, 0, 0, utc()), 39350.12),
    (dateTime(2025, mAug, 8, 0, 0, 0, 0, utc()), 39400.67),
    (dateTime(2025, mAug, 9, 0, 0, 0, 0, utc()), 39450.23),
    (dateTime(2025, mAug, 10, 0, 0, 0, 0, utc()), 39500.56),
    (dateTime(2025, mAug, 11, 0, 0, 0, 0, utc()), 39550.89),
    (dateTime(2025, mAug, 12, 0, 0, 0, 0, utc()), 39600.15),
    (dateTime(2025, mAug, 13, 0, 0, 0, 0, utc()), 39650.42),
    (dateTime(2025, mAug, 14, 0, 0, 0, 0, utc()), 39700.78),
    (dateTime(2025, mAug, 15, 0, 0, 0, 0, utc()), 39750.23),
    (dateTime(2025, mAug, 16, 0, 0, 0, 0, utc()), 39800.56),
    (dateTime(2025, mAug, 17, 0, 0, 0, 0, utc()), 39850.89),
    (dateTime(2025, mAug, 18, 0, 0, 0, 0, utc()), 39900.15),
    (dateTime(2025, mAug, 19, 0, 0, 0, 0, utc()), 39950.42),
    (dateTime(2025, mAug, 20, 0, 0, 0, 0, utc()), 40000.78),
    (dateTime(2025, mAug, 21, 0, 0, 0, 0, utc()), 40050.23),
    (dateTime(2025, mAug, 22, 0, 0, 0, 0, utc()), 40100.67),
    (dateTime(2025, mAug, 23, 0, 0, 0, 0, utc()), 40150.89),
    (dateTime(2025, mAug, 24, 0, 0, 0, 0, utc()), 40200.34),
    (dateTime(2025, mAug, 25, 0, 0, 0, 0, utc()), 40250.75),
    (dateTime(2025, mAug, 26, 0, 0, 0, 0, utc()), 40300.12),
    (dateTime(2025, mAug, 27, 0, 0, 0, 0, utc()), 40350.45),
    (dateTime(2025, mAug, 28, 0, 0, 0, 0, utc()), 40400.78),
    (dateTime(2025, mAug, 29, 0, 0, 0, 0, utc()), 40450.23),
]