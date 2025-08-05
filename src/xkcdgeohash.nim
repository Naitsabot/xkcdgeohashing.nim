## Geohashing library for Nim
##
## Implementation of the geohashing algorithm from https://xkcd.com/426/
## 
## Basic usage:
##
## Copyright (c) 2025 Your Name
## Licensed under MIT License

import std/[md5, options, strutils, times]


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

    # Exeption Types
    GeohashError* = object of CatchableError
    DowDataError* = object of GeohashError


const DOW_JONES_SOURCES: array[0..3, string] = 
    ["http://carabiner.peeron.com/xkcd/map/data/", "http://geo.crox.net/djia/",
     "http://www1.geo.crox.net/djia/", "http://www2.geo.crox.net/djia/"]


when isMainModule:
    discard