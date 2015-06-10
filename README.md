# connect_vbms

## Pre-requisites

- [Java JDK 1.7 or above](http://www.oracle.com/technetwork/java/javase/downloads/index.html)
- [Python 2.6 or above](https://www.python.org/downloads/)
- Sphinx 1.3.1 or above (`pip install sphinx`)

## Build

From the root directory, run:

`make build`

## Tests

From the root directory, run:

`bundle exec rspec`

The tests are dependent on your network and on the VBMS test server being up and running.

## Docs

From the root directory, run:

`make docs`