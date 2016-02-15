# Contributing guide

## How to add new functions

Try to put as little logic in the SQL extension as possible and
just use it as a wrapper to the Python module functionality.

Once a function is defined it should never change its signature in subsequent
versions. To change a function's signature a new function with a different
name must be created.

### Python

...

### SQL

* Generate a **new subfolder version** for `sql` and `test` folders to define the new functions and tests
  * Use symlinks to avoid file duplication between versions that don't update them
  * Add or upgrade your SQL server functions
  * Create tests for the client and server functions -- at least, to check that those are created

* Generate the **upgrade and downgrade files** for the extension for both client and server

* Update the control files and the Makefiles to generate the complete SQL file for the new created version
  * These new version file (`crankshaft--X.Y.Z.sql`)
    must be pushed and frozen. You should add it to the `.gitignore` file.

* Update the public docs! ;-)

## Naming things

# SQL

Use snake case (i.e. `snake_case` and not `CamelCase`) for all
functions. Prefix functions intended for public use with `cdb_`
and private functions (to be used only internally inside
the extension)  with `_cdb_`.

# Python

...
