Contributing
============

We aspire to create a welcoming environment for collaboration on this
project.

Public domain
-------------

This project is in the public domain within the United States, and
copyright and related rights in the work worldwide are waived through
the `CC0 1.0 Universal public domain dedication`_.

All contributions to this project will be released under the CC0
dedication. By submitting a pull request, you are agreeing to comply
with this waiver of copyright interest.

Communication
=============

You should be using the master branch for most stable release, please
review `release notes`_ regularly. We’re generally using `semantic
versioning`_, but we’re pre-1.0, so the API can change at any time. We
use the minor version for when there are not significant API changes.

Development Process
===================

This project follows a similar development process to `git flow`_. We
use feature branches for all development, with frequent rebases to keep
our feature branches in sync. All pull requests are community reviewed
and must pass our continuous integration spec run and code style
enforcer in `Travis CI`_.

We have a pre-configured `Vagrant environment`_ which generates a fresh
Ubuntu development environment with all necessary dependencies.

Example:

1. Pull latest code from master branch.

   ::

       git checkout master
       git pull

2. Create a feature branch for your work.

   ::

       git checkout -b feature/do_something_awesome

3. Commit your work and associate with an Issue.

   ::

       git add <files>
       git commit -m"[Issue #<number>] Does something awesome"

4. Push your work up and create a Pull Request for review.

   ::

       git push origin feature/do_something_awesome

.. _CC0 1.0 Universal public domain dedication: https://creativecommons.org/publicdomain/zero/1.0/
.. _release notes: https://github.com/department-of-veterans-affairs/connect_vbms/releases
.. _semantic versioning: http://semver.org/
.. _git flow: http://nvie.com/posts/a-successful-git-branching-model/
.. _Travis CI: https://travis-ci.org/department-of-veterans-affairs/connect_vbms
.. _Vagrant environment: https://github.com/department-of-veterans-affairs/connect_vbms/blob/master/docs/developing_with_vagrant.rst