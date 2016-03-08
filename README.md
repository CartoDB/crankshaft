# crankshaft

CartoDB Spatial Analysis extension for PostgreSQL.

## Code organization

* *doc* documentation
* *src* source code
* - *src/pg* contains the PostgreSQL extension source code
* - *src/py* Python module source code
* *release* reselesed versions

## Requirements

* pip, virtualenv, PostgreSQL

# Working Process

## Development

Work in `src/pg/sql`, `src/py/crankshaft`;
use topic branch.

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

Add tests...

* `CREATE EXTENSION crankshaft WITH VERSION 'dev';`

Test

Commit, push, create PR, wait for CI tests, CR, ...

## Release

To release current development version
(working directory should be clean in dev branch)

(process to be gradually automated)

For backwards compatible changes (no return value, num of arguments, etc. changes...)
new version number increasing either patch level (no new functionality)
or minor level (new functionality) => 'X.Y.Z'.
Update version in src/pg/crankshaft.control
Copy release/crankshaft--current.sql to release/crankshaft--X.Y.Z.sql
Prepare incremental downgrade, upgrade scripts....

Python: ...

Install the new release

`make install-release`

Test the new release

`make test-release`

Push the release

Wait for CI tests

Merge into master

Deploy: install extension and python to production hosts,
update extension in databases (limited to team users, data observatory, ...)

Release manager role: ...

.sql release scripts
commit
tests: staging....
merge, tag, deploy...
