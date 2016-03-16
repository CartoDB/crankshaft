# Release & Deployment Process

Please read the Working Process/Quickstart Guide in README.md
and the Development guidelines in CONTRIBUTING.md.

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

## Relevant release & deployment tasks available in the Makefile

```
* `make help` show a short description of the available targets

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
