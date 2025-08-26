# Package

version       = "1.1.3"
author        = "Naitsabot"
description   = "Implementation for the geohashing algorithm described in xkcd #426"
license       = "MIT"
srcDir        = "src"
bin           = @["xkcdgeohash"]

# Dependencies

requires "nim >= 2.2.2" # Latest version clearing all tests (Win10 problem with choosnim 2.2.0)
requires "checksums >= 0.2.1"
requires "docopt >= 0.7.1" # https://github.com/docopt/docopt.nim


#task test, "Runs the tests!":
    #exec "nimble build -d:test"
    #exec "xkcdgeohash --lat=68.0 --lon=-30.0 --date=2025-08-29 --test" #works
    #exec "nim c -d:test tests/test_cli" #does not work
    #exec "nim c -d:test tests/test_xkcdgeohash"
