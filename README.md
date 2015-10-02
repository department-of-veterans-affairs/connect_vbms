# connect_vbms

Connect VBMS is a Ruby gem for communicating with version 4 of the eDocumentService API provided by Veteran Benefits Management System (VBMS) at the Department of Veteran Affairs. Although the source code is open source, access to VBMS is restricted only to authorized users.

![](https://travis-ci.org/department-of-veterans-affairs/connect_vbms.svg?branch=master)

## Prerequisites

- Ruby 2.2 or above
	- Bundler 1.10 or above (`gem install bundle`)
- [Java JDK 1.7 or above](http://www.oracle.com/technetwork/java/javase/downloads/index.html)
- [Python 2.6 or above](https://www.python.org/downloads/)
	- Sphinx 1.3.1 or above (`pip install sphinx`)

The library currently uses Java for some encryption functionality. When this is replaced, the integration tests will continue to use the Java encryption/decryption utilities as a reference to check against. Python is currently used to generate documentation.

## Build

From the root directory, run:

`rake build`

## Tests

For the first run of the tests, install the Ruby dependencies:

`bundle install`

Every other time, just run the below from the root directory:

`bundle exec rake default`

This will run all the tests and also runs [rubocop](http://batsov.com/rubocop/) to identify any stylistic problems in the code. You must ensure your code passes all tests and has no Rubocop violations before submitting a pull request.

Tests normally mock all web requests so tests can be run without needing any credentials for VBMS systems. To run the integration tests against a VBMS server, you must specify all the necessary `VBMS_CONNECT` environment variables. You can then execute tests with `CONNECT_VBMS_RUN_EXTERNAL_TESTS=1 bundle exec rake default` and it will not use local webmocks.

## Docs

From the root directory, run:

`rake docs`

## VM Development

Requires:
  - [Vagrant 1.7.2 or above](http://www.vagrantup.com/downloads.html)
  - [VirtualBox](https://www.virtualbox.org/wiki/Downloads) or [VMWare Fusion](https://www.vmware.com/go/downloadfusion)

Copy the provided example Vagrantfile and Vagrant up!
```bash
$ cp Vagrantfile.example Vagrantfile
$ vagrant up
```

