# connect_vbms

Connect VBMS is a Ruby gem for communicating with the API provided by Veteran Benefits Management System (VBMS) at the Department of Veteran Affairs. Although the source code is open source, access to VBMS is restricted only to authorized users.

![](https://travis-ci.org/department-of-veterans-affairs/connect_vbms.svg?branch=master)

## Prerequisites

- Ruby 2.5 or above
- Bundler 1.10 or above (`gem install bundle`)

## Tests

For the first run of the tests, install the Ruby dependencies:

```
> bundle install
> bundle exec rake tests:prepare
```

Every other time, just run the below from the root directory:

`bundle exec rake`

This will run all the tests, [rubocop](http://batsov.com/rubocop/) to identify any stylistic problems in the code and [bundle-audit](https://github.com/rubysec/bundler-audit) to find vulnerable versions of gems in `Gemfile.lock`. You must ensure your code passes all tests and has no Rubocop violations before submitting a pull request.

Tests normally mock all web requests so tests can be run without needing any credentials for VBMS systems. To run the integration tests against a VBMS server, you must specify all the necessary `VBMS_CONNECT` environment variables. You can then execute tests with `CONNECT_VBMS_RUN_EXTERNAL_TESTS=1 bundle exec rake default` and it will not use local webmocks.

Our development group also includes HTTPLog for viewing raw HTTP messages. To enable HTTPLog, use the `CONNECT_VBMS_HTTPLOG=1` environment variable.

## Contributing

Please read our [Contributing guide](https://github.com/department-of-veterans-affairs/connect_vbms/blob/master/docs/contributing.rst) to get started.


## License

[The project is in the public domain](LICENSE.md), and all contributions will also be released in the public domain. By submitting a pull request, you are agreeing to waive all rights to your contribution under the terms of the [CC0 Public Domain Dedication](http://creativecommons.org/publicdomain/zero/1.0/).

This project constitutes an original work of the United States Government.
