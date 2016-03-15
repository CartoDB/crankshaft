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

We use the default `develop` branch as the basis for development.
This branch and `master` are maintained by the *Release Manager*.
The `master` branch is used to merge and tag releases to be
deployed in production.

In addition to these two permanent branches, temporal *topic*
branches will be used for all modifications.

## Development

A topic branch should be created out of the `develop` branch
and be used for the development process; see src/py/README.md

Modifications are done inside `src/pg/sql` and `src/py/crankshaft`.
Take into account:

*  Always remember to add tests (`src/pg/test`, `src/py/crankshaft/test`)
   for any new functionality.
*  Add or modify the corresponding documentation files in the `doc` folder.
   Since we expect to have highly technical functions here, an extense
   background explanation would be of great help to users of this extension.
*  Convention: Use snake case (i.e. `snake_case` and not `CamelCase`) for all
   functions. Prefix functions intended for public use with `cdb_`
   and private functions (to be used only internally inside
   the extension)  with `_cdb_`.

Update the local development installation with `sudo make install`.
This will update the 'dev' version of the extension in 'src/pg/' and
make it available to PostgreSQL.
It will also install the python package (crankshaft) in a virtual
environment `env/dev`.

Run the tests with `make test`

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

If the extension has not previously been installed in a database
we can:

* `CREATE EXTENSION crankshaft WITH VERSION 'dev';`

Note: the development extension uses the development pyhton virtual
environment automatically.

Once the tests are succeeding a new Pull-Request can be created.
CI-tests must be checked to be successful.

Before proceeding to the release process peer code reviewing of the code is a must.

## Release

The release process of a new version of the extension
shall by performed by the designated *Release Manager*.

Note that we expect to gradually automate more of this process.

Having checked the topic branch of the PR to be released it shall be
merged back into the `develop` branch to prepare the new release.

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

This will make the 'X.Y.Z' version of the extension to PostgreSQL.
The corresponding Python extension will be installed in a
virtual environment in `envs/X.Y.Z`

It can be activated with:

```
source envs/X.Y.Z/bin/activate
```

But note that this is needed only for using the package directly;
the 'X.Y.Z' version of the extension will automatically use the
python package from this virtual environment.

The `sudo make deploy` operation can be also used for installing
the new version after it has been released.

TODO: testing procedure for the new release.

TODO: procedure for staging deployment.

TODO: procedure for merging to master, tagging and deploying
in production.
