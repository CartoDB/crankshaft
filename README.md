# crankshaft

CartoDB Spatial Analysis extension for PostgreSQL.

## Code organization

* *doc* documentation
* *src* source code
* - *src/pg* contains the PostgreSQL extension source code
* - *src/py* Python module source code
* *release* reseleased versions

## Requirements

* pip, virtualenv, PostgreSQL
* python-scipy system package (see src/py/README.md)

# Working Process

## Development

Work in `src/pg/sql`, `src/py/crankshaft`;
use a topic branch. See src/py/README.md
for the procedure to work with the Python local environment.

Take into account:

*  Always remember to add tests for any new functionality
   documentation.
*  Add or modify the corresponding documentation files in the `doc` folder.
   Since we expect to have highly technical functions here, an extense
   background explanation would be of great help to users of this extension.
*  Convention: Use snake case (i.e. `snake_case` and not `CamelCase`) for all
   functions. Prefix functions intended for public use with `cdb_`
   and private functions (to be used only internally inside
   the extension)  with `_cdb_`.

Update local installation with `sudo make install`
(this will update the 'dev' version of the extension in 'src/pg/')

Run the tests with `PGUSER=postgres make test`

Update extension in working database with

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

Once the tests are succeeding a new Pull-Request can be created.
CI-tests must be checked to be successfull.

Before merging a topic branch peer code reviewing of the code is a must.


## Release

The release process of a new version of the extension
shall by performed by the designated *Release Manager*.

Note that we expect to gradually automate this process.

Having checkout the topic branch of the PR to be released:

The version number in `pg/cranckshaft.control` must first be updated.
To do so [Semantic Versioning 2.0](http://semver.org/) is in order.

We now will explain the process for the case of backwards-compatible
releases (updating the minor or patch version numbers).

TODO: document the complex case of major releases.

The next command must be executed to produce the main installation
script for the new release, `release/cranckshaft--X.Y.Z.sql`.

```
make release
```

Then, the release manager shall produce upgrade and downgrade scripts
to migrate to/from the previous release. In the case of minor/patch
releases this simply consist in extracting the functions that have changed
and placing them in the proper `release/cranckshaft--X.Y.Z--A.B.C.sql`
file.

TODO: configure the local enviroment to be used by the release;
currently should be directory `src/py/X.Y.Z`, but this must be fixed;
a possibility to explore is to use the `cdb_conf` table.

TODO: testing procedure for the new release

TODO: push, merge, tag, deploy procedures.
