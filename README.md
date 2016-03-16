# crankshaft

CartoDB Spatial Analysis extension for PostgreSQL.

## Code organization

* *doc* documentation
* *src* source code
* - *src/pg* contains the PostgreSQL extension source code
* - *src/py* Python module source code
* *release* reseleased versions
* *env* base directory for Python virtual environments

## Requirements

* pip, virtualenv, PostgreSQL
* python-scipy system package (see src/py/README.md)

# Working Process

We distinguish two roles regarding the development cycle of crankshaft:

* *developers* will implement new functionality and bugfixes into
  the codebase and will request for new releases of the extension.
* A *release manager* will attend these requests and will handle
  the release process. The release process is sequential:
  no concurrent releases will ever be in the works.

We use the default `develop` branch as the basis for development.
This branch and `master` are maintained by the *Release Manager*.
The `master` branch is used to merge and tag releases to be
deployed in production.

Developers shall create a new topic branch from `develop` for any new feature
or bugfix and commit their changes to it and eventually merge back into
the `develop` branch. When a new release is required a Pull Request
will be open againt the `develop` branch.

The `develop` pull requests will be handled by the release manage,
who will merge into master where new releases are prepared and tagged.
The `master` branch is the sole responsibility of the release masters
and developers must not commit or merge into it.

## Development

For any modification of crankshaft, such as adding new features,
refactoring or bug-fixing, topic branch must be created out of the `develop`
branch and be used for the development process.

Modifications are done inside `src/pg/sql` and `src/py/crankshaft`.

Take into account:

*  Tests must be added for any new functionality
   (inside `src/pg/test`, `src/py/crankshaft/test`) as well as to
   detect any bugs that are being fixed.
*  Add or modify the corresponding documentation files in the `doc` folder.
   Since we expect to have highly technical functions here, an extense
   background explanation would be of great help to users of this extension.
*  Convention: snake case(i.e. `snake_case` and not `CamelCase`)
   shall be used for all function names.
   Prefix function names intended for public use with `cdb_`
   and private functions (to be used only internally inside
   the extension)  with `_cdb_`.

Once the code is ready to be tested, update the local development installation
with `sudo make install`.
This will update the 'dev' version of the extension in `src/pg/` and
make it available to PostgreSQL.
It will also install the python package (crankshaft) in a virtual
environment `env/dev`.

The version number of the Python package, defined in
`src/pg/crankshaft/setup.py` will be overridden when
the package is released and always match the extension version number,
but for development it shall be kept as '0.0.0'.

Run the tests with `make test`.

To use the python extension for custom tests, activate the virtual
environment with:

```
source envs/dev/bin/activate
```

Update extension in a working database with:

* `ALTER EXTENSION crankshaft VERSION TO 'current';`
  `ALTER EXTENSION crankshaft VERSION TO 'dev';`

Note: we keep the current development version install as 'dev' always;
we update through the 'current' alias to allow changing the extension
contents but not the version identifier. This will fail if the
changes involve incompatible function changes such as a different
return type; in that case the offending function (or the whole extension)
should be dropped manually before the update.

If the extension has not previously been installed in a database,
it can be installed directly with:

* `CREATE EXTENSION crankshaft WITH VERSION 'dev';`

Note: the development extension uses the development python virtual
environment automatically.

Before proceeding to the release process peer code reviewing of the code is
a must.

Once the feature or bugfix is completed, all the tests are passing
and the code has been accepted by peer reviewing,
the topic branch can be merged back into the `develop` branch and a
new Pull-Request can be created on it.
CI-tests must be checked to be successful.

The release manage will take hold of the PR at this moment to proceed
to the release process for a new revision of the extension.

## Release

The release process of a new version of the extension
shall be performed by the designated *Release Manager*.

Note that we expect to gradually automate more of this process.

Having checked PR to be released it shall be
merged back into the `master` branch to prepare the new release.

The version number in `pg/cranckshaft.control` must first be updated.
To do so [Semantic Versioning 2.0](http://semver.org/) is in order.

Thew `NEWS.md` will be updated.

We now will explain the process for the case of backwards-compatible
releases (updating the minor or patch version numbers).

TODO: document the complex case of major releases.

The next command must be executed to produce the main installation
script for the new release, `release/cranckshaft--X.Y.Z.sql` and
also to copy the python package to `release/python/X.Y.Z/crankshaft`.

```
make release
```

Then, the release manager shall produce upgrade and downgrade scripts
to migrate to/from the previous release. In the case of minor/patch
releases this simply consist in extracting the functions that have changed
and placing them in the proper `release/cranckshaft--X.Y.Z--A.B.C.sql`
file.

The new release can be deployed for staging/smoke tests with this command:

```
sudo make deploy
```

This will copy the current 'X.Y.Z' released version of the extension to
PostgreSQL. The corresponding Python extension will be installed in a
virtual environment in `envs/X.Y.Z`.

It can be activated with:

```
source envs/X.Y.Z/bin/activate
```

But note that this is needed only for using the package directly;
the 'X.Y.Z' version of the extension will automatically use the
python package from this virtual environment.

The `sudo make deploy` operation can be also used for installing
the new version after it has been released.

To install a specific version 'X.Y.Z' different from the current one
(which must be present in `releases/`) you can:

```
sudo make deploy RELEASE_VERSION=X.Y.Z
```

TODO: testing procedure for the new release.

TODO: procedure for staging deployment.

TODO: procedure for merging to master, tagging and deploying
in production.

## Relevant tasks available in the Makefile

```
* `make help` show a short description of the available targets

# Development tasks

* `sudo make install` will generate the extension scripts for the development
  version ('dev'/'current') and install the python package into the
  development virtual environment `envs/dev`.
  Intended for use by developers.

* `make test` will run the tests for the installed development extension.
  Intended for use by developers.

# Release tasks

* `make release` will generate a new release (version number defined in
  `src/pg/crankshaft.control`) into `release/`.
  Intended for use by the release manager.

* `sudo make deploy` will install the current release X.Y.Z from the
  `release/` files into PostgreSQL and a Python virtual environment
  `envs/X.Y.Z`.
  Intended for use by the release manager and deployment jobs.

* `sudo make deploy RELEASE_VERSION=X.Y.Z` will install specified version
  previously generated in `release/`
  into PostgreSQL and a Python virtual environment `envs/X.Y.Z`.
  Intended for use by the release manager and deployment jobs.
```
