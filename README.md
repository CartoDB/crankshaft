# Crankshaft [![Build Status](https://travis-ci.org/CartoDB/crankshaft.svg?branch=develop)](https://travis-ci.org/CartoDB/crankshaft)

CartoDB Spatial Analysis extension for PostgreSQL.

## Code organization

* `doc/` documentation
* `src/` source code
 - `pg/` contains the PostgreSQL extension source code
 - `py/` Python module source code
* `release` reseleased versions

## Requirements

* PostgreSQL
* plpythonu and postgis extensions
* python-scipy system package (see [src/py/README.md](https://github.com/CartoDB/crankshaft/blob/develop/src/py/README.md))

# Development Process

We distinguish two roles:

* *developers* will implement new functionality and bugfixes into
  the codebase.
* A *release manager* will handle the release process.

We use the branch `develop` as the main integration branch for development. The `master` is reserved to handle releases.

The process is as follows:

1. Create a new **topic branch** from `develop` for any new feature
or bugfix and commit their changes to it:
```shell
git fetch && git checkout -b my-cool-feature origin/develop
```
1. Code, commit, push, repeat.
1. Write some **tests** for your feature or bugfix.
1. Update the [NEWS.md](https://github.com/CartoDB/crankshaft/blob/develop/NEWS.md) doc.
1. Create a pull request and mention relevant people for a **peer review**.
1. Address the comments and improvements you get from the peer review.
1. Mention `@CartoDB/dataservices` in the PR to get it merged into `develop`.

In order for a pull request to be accepted, the following criteria should be met:
* The peer review should pass and no major issue should be left unaddressed.
* CI tests must pass (travis will take care of that).


## Development Guidelines

For a detailed description of the development process please see
the [CONTRIBUTING.md](https://github.com/CartoDB/crankshaft/blob/develop/CONTRIBUTING.md) guide.


## Testing

The tests (both for SQL and Python) are executed by running, from the top directory:

```shell
sudo make install
make test
```

## Release

The release process is described in the
[RELEASE.md](https://github.com/CartoDB/crankshaft/blob/develop/RELEASE.md) guide and is the responsibility of the designated *release manager*.
