## Geohashing library for Nim - Testing of src/private/cli.nim
##
## Copyright (c) 2025 Sebastian H. Lorenzen
## Licensed under MIT License

## ## Method
## Subprocess testing for integration tests of CLI
## Wont bother with splitting the processGeohash funciton and making unit tests
## Standalone functions will get unit tests


import std/[json, os, osproc, strutils, unittest]


const BINARY_PATH: string = "./xkcdgeohash.exe"


suite "CLI Integration Tests":
    setup:
        # Build the binary before running tests
        let buildResult: int = execCmd("nimble build")
        if buildResult != 0:
            let text: string = "Failed to build binary"
            checkpoint(text)
            fail()
        
        # Check if binary exists
        if not fileExists(BINARY_PATH):
            let text: string = "Binary not found at " & BINARY_PATH
            checkpoint(text)
            fail()

    test "shows help":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --help")
        check exitCode == 0
        check "XKCD Geohash Calculator" in output
        check "Usage:" in output
        check "Examples:" in output
    
    test "shows version":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --version")
        check exitCode == 0
        check output.strip().len > 0
    
    test "basic geohash calculation - positive and positive":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --lat=56.0 --lon=9.0")
        check exitCode == 0
        let coords = output.strip()
        check coords.contains(",")
        check coords.contains(".") # Should have decimal places
    
    test "basic geohash calculation - positive and negative":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --lat=68.0 --lon=-30.0")
        check exitCode == 0
        let coords = output.strip()
        check coords.contains(",")
        check coords.contains(".") # Should have decimal places

    test "basic geohash calculation - negative and positive":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --lat=-25.0 --lon=40.0")
        check exitCode == 0
        let coords = output.strip()
        check coords.contains(",")
        check coords.contains(".") # Should have decimal places

    test "basic geohash calculation - negative and negative":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --lat=-25.0 --lon=-69.0")
        check exitCode == 0
        let coords = output.strip()
        check coords.contains(",")
        check coords.contains(".") # Should have decimal places

    test "global geohash":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --global")
        check exitCode == 0
        let coords = output.strip()
        check coords.contains(",")
    
    test "specific date - 2008-05-26":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --lat=68.0 --lon=-30.0 --date=2008-05-26")
        check exitCode == 0
        let coords = output.strip()
        check coords.contains(",")

    test "specific date - 2000-02-02":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --lat=68.0 --lon=-30.0 --date=2000-02-02")
        check exitCode == 0
        let coords = output.strip()
        check coords.contains(",")
    
    test "specific date - 2012-12-12":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --lat=68.0 --lon=-30.0 --date=2012-12-12")
        check exitCode == 0
        let coords = output.strip()
        check coords.contains(",")
    
    test "verbose output":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --lat=68.0 --lon=-30.0 --verbose")
        check exitCode == 0
        check "used Dow:" in output
        check "target:" in output
    
    test "DMS format":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --lat=68.0 --lon=-30.0 --format=dms")
        check exitCode == 0
        let coords = output.strip()
        check "°" in coords
        check ("N" in coords or "S" in coords)
        check ("E" in coords or "W" in coords)
    
    test "coordinates format":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --lat=68.0 --lon=-30.0 --format=coordinates")
        check exitCode == 0
        let coords = output.strip()
        check coords.contains(",")
        check not coords.contains(" ")  # No spaces in coordinates format
    
    test "JSON output":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --lat=68.0 --lon=-30.0 --json")
        check exitCode == 0
        
        # Should be valid JSON
        try:
            let jsonData = parseJson(output.strip())
            check jsonData.kind == JArray
            check jsonData.len == 1
            
            let result = jsonData[0]
            check result.hasKey("latitude")
            check result.hasKey("longitude")
            check result.hasKey("date")
            check result.hasKey("used_dow_date")
        except JsonParsingError:
            let text: string = "Output is not valid JSON: " & output
            checkpoint(text)
            fail()
    
    test "multiple days":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --lat=68.0 --lon=-30.0 --days=3")
        check exitCode == 0
        let lines = output.strip().split('\n')
        check lines.len == 3  # Should have 3 lines of output
        for line in lines:
            check ":" in line  # Should have date: coordinates format
    
    test "Google Maps URL":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --lat=68.0 --lon=-30.0 --url=google")
        check exitCode == 0
        let lines = output.strip().split('\n')
        check lines.len == 2  # Coordinates + URL
        check "https://maps.google.com" in lines[1]
    
    test "OpenStreetMap URL with custom zoom":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --lat=68.0 --lon=-30.0 --url=osm --zoom=12")
        check exitCode == 0
        let lines = output.strip().split('\n')
        check "openstreetmap.org" in lines[1]
        check "zoom=12" in lines[1]

    test "Bing Maps URL":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --lat=68.0 --lon=-30.0 --url=bing")
        check exitCode == 0
        let lines = output.strip().split('\n')
        check lines.len == 2  # Coordinates + URL
        check "https://www.bing.com/maps/" in lines[1]

    test "Waymarked Trails (Hiking) map URL":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --lat=68.0 --lon=-30.0 --url=waymarked")
        check exitCode == 0
        let lines = output.strip().split('\n')
        check lines.len == 2  # Coordinates + URL
        check "https://hiking.waymarkedtrails.org/" in lines[1]
    
    test "verbose with map URL":
        let (output, code) = execCmdEx(BINARY_PATH & " --lat=68.0 --lon=-30.0 --verbose --url=google")
        check code == 0
        check "used Dow:" in output
        check "Map: https://maps.google.com" in output


suite "CLI Error Handling":
    test "missing coordinates":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --lat=68.0")
        check exitCode == 0
        check "Usage" in output
    
    test "invalid coordinates":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --lat=invalid --lon=coords")
        check exitCode == 1
        check "Invalid input:" in output
    
    test "invalid date format":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --lat=68.0 --lon=-30.0 --date=invalid")
        check exitCode == 1
        check "Invalid" in output
    
    test "invalid output format":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --lat=68.0 --lon=-30.0 --format=invalid")
        check exitCode == 1
        check "Invalid format" in output
    
    test "invalid map service":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --lat=68.0 --lon=-30.0 --url=invalid")
        check exitCode == 1
        check "Invalid service" in output
    
    test "coordinates without global flag":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH)
        check exitCode == 0
        check "Usage" in output


suite "CLi Possible Edge Cases":
    test "zero coordinates":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --lat=0.0 --lon=0.0")
        check exitCode == 0
        check output.strip().contains(",")
    
    test "large coordinate values":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --lat=89.9 --lon=179.9")
        check exitCode == 0
        check output.strip().contains(",")

    test "JSON with multiple days":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --lat=68.0 --lon=-30.0 --days=2 --json")
        check exitCode == 0
        
        try:
            let jsonData = parseJson(output.strip())
            check jsonData.kind == JArray
            check jsonData.len == 2
        except JsonParsingError:
            let text: string = "Invalid JSON output"
            checkpoint(text)
            fail()


suite "CLI Performance":
    test "many days calculation":
        let (output, exitCode): (string, int) = execCmdEx(BINARY_PATH & " --lat=68.0 --lon=-30.0 --days=30")
        check exitCode == 0
        let lines: seq[string] = output.strip().split('\n')
        check lines.len == 30
