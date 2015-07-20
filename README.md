# connect_vbms

Connect VBMS is a Ruby library for connecting to VBMS.

## Pre-requisites

- [Java JDK 1.7 or above](http://www.oracle.com/technetwork/java/javase/downloads/index.html)
- [Python 2.6 or above](https://www.python.org/downloads/)
	- Sphinx 1.3.1 or above (`pip install sphinx`)
- Ruby 2.2 or above
	- Bundler 1.10 or above (`gem install bundle`)

## Build

From the root directory, run:

`rake build`

## Tests

For the first run of the tests, install the Ruby dependencies:

`bundle install`

Every other time, just run the below from the root directory:

`bundle exec rspec`

The tests are dependent on your network and on the VBMS test server being up and running.

## Docs

From the root directory, run:

`rake docs`
