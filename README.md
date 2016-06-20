# crankshaft

CartoDB Spatial Analysis extension for PostgreSQL.

## Code organization

* *doc* documentation
* *src* source code
* - *src/pg* contains the PostgreSQL extension source code
* - *src/py* Python module source code
* *release* reseleased versions

## Requirements

* pip, PostgreSQL
* python-scipy system package (see [src/py/README.md](https://github.com/CartoDB/crankshaft/blob/master/src/py/README.md))

# Working Process -- Quickstart Guide

We distinguish two roles regarding the development cycle of crankshaft:

* *developers* will implement new functionality and bugfixes into
  the codebase and will request for new releases of the extension.
* A *release manager* will attend these requests and will handle
  the release process. The release process is sequential:
  no concurrent releases will ever be in the works.

We use the default `develop` branch as the basis for development.
The `master` branch is used to merge and tag releases to be
deployed in production.

Developers shall create a new topic branch from `develop` for any new feature
or bugfix and commit their changes to it and eventually merge back into
the `develop` branch. When a new release is required a Pull Request
will be open against the `develop` branch.

The `develop` pull requests will be handled by the release manage,
who will merge into master where new releases are prepared and tagged.
The `master` branch is the sole responsibility of the release masters
and developers must not commit or merge into it.

## Development Guidelines

For a detailed description of the development process please see
the [CONTRIBUTING.md](https://github.com/CartoDB/crankshaft/blob/master/CONTRIBUTING.md) guide.

Any modification to the source code (`src/pg/sql` for the SQL extension,
`src/py/crankshaft` for the Python package) shall always be done
in a topic branch created from the `develop` branch.

Tests, documentation and peer code reviewing are required for all
modifications.

The tests (both for SQL and Python) are executed by running,
from the top directory:

```
sudo make install
make test
```

To request a new release, which will be handled by them
release manager, a Pull Request must be created in the `develop`
branch.

## Release

The release and deployment process is described in the
[RELEASE.md](https://github.com/CartoDB/crankshaft/blob/master/RELEASE.md) guide and it is the responsibility of the designated
release manager.
