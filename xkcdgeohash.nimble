# Package

version       = "1.0.0"
author        = "Naitsabot"
description   = "Implementation for the geohashing algorithm described in xkcd #426"
license       = "MIT"
srcDir        = "src"
bin           = @["xkcdgeohash"]


# Dependencies

requires "nim >= 2.0.1" # Latest supported by checksums dependency
requires "checksums >= 0.2.1"
requires "docopt >= 0.7.1" # https://github.com/docopt/docopt.nim
