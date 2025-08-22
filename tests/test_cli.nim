## Geohashing library for Nim - Testing of src/private/cli.nim
##
## Copyright (c) 2025 Sebastian H. Lorenzen
## Licensed under MIT License

## ## Method
## Subprocess testing for integration tests of CLI
## Wont bother with splitting the processGeohash funciton and making unit tests
## Standalone functions will get unit tests

import unittest

import xkcdgeohash, osproc, strutils, json, os

const BINARY_PATH = "./xkcdgeohash"

suite "CLI Integration Tests":
    setup:
        # Build the binary before running tests
        let buildResult = execCmd("nimble build")
        if buildResult != 0:
            fail("Failed to build binary")
        
        # Check if binary exists
        if not fileExists(BINARY_PATH):
            fail("Binary not found at " & BINARY_PATH)

    test "shows help":
        let (output, code) = execCmdEx(BINARY_PATH & " --help")
        check code == 0
        check "XKCD Geohash Calculator" in output
        check "Usage:" in output
        check "Examples:" in output