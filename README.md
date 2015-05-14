# connect_vbms

## Java

To build the java code, run `make build` from the root directory

## Tests

To run the tests, make sure you have built the java code, then: `bundle exec rspec`

The tests are dependent on your network and on the VBMS test server being up and running.

## Docs

To build the docs you will need to have python and sphinx >= 1.3.1 installed.
If you don't have it installed, try `pip install sphinx`.

Once you have that, just run `make docs`
