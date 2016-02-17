# Contributing guide

## How to add new functions

Try to put as little logic in the SQL extension as possible and
just use it as a wrapper to the Python module functionality.

Once a function is defined it should never change its signature in subsequent
versions. To change a function's signature a new function with a different
name must be created.

### Version numbers

The version of both the SQL extension and the Python package shall
follow the[Semantic Versioning 2.0](http://semver.org/) guidelines:

* When backwards incompatibility is introduced the major number is incremented
* When functionally is added (in a backwards-compatible manner) the minor number
  is incremented
* When only fixes are introduced (backwards-compatible) the patch number is
  incremented

### Python Package

...

### SQL Extension

* Generate a **new subfolder version** for `sql` and `test` folders to define
  the new functions and tests
  - Use symlinks to avoid file duplication between versions that don't update them
  - Add new files or modify copies of the old files to add new functions or
    modify existing functions (remember to rename a function if the signature
    changes)
  - Create tests for the new functions/behaviour

* Generate the **upgrade and downgrade files** for the extension

* Update the control file and the Makefile to generate the complete SQL
  file for the new created version. After running `make` a new
  file `crankshaft--X.Y.Z.sql` will be created for the current version.
  Additional files for migrating to/from the previous version A.B.Z should be
  created:
  - `crankshaft--X.Y.Z--A.B.C.sql`
  - `crankshaft--A.B.C--X.Y.Z.sql`
  All these new files must be added to git and pushed.

* Update the public docs! ;-)

## Conventions

# SQL

Use snake case (i.e. `snake_case` and not `CamelCase`) for all
functions. Prefix functions intended for public use with `cdb_`
and private functions (to be used only internally inside
the extension)  with `_cdb_`.

# Python

...
