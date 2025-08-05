## Geohashing library for Nim
##
## Implementation of the geohashing algorithm from https://xkcd.com/426/
## 
## Basic usage:
##
## Copyright (c) 2025 Your Name
## Licensed under MIT License


import std/[md5]

const DOW_JONES_SOURCES: array[0..3, string] = 
    ["http://carabiner.peeron.com/xkcd/map/data/", "http://geo.crox.net/djia/",
     "http://www1.geo.crox.net/djia/", "http://www2.geo.crox.net/djia/"]


when isMainModule:
    discard