# Development process

For any modification of crankshaft, such as adding new features,
refactoring or bugfixing, a topic branch must be created out of the `develop`.

Modifications are done inside `src/pg/sql` and `src/py/crankshaft`.

When adding a new PostgreSQL function or modifying an exiting one make sure that the
[VOLATILITY](https://www.postgresql.org/docs/current/static/xfunc-volatility.html) and [PARALLEL](https://www.postgresql.org/docs/9.6/static/parallel-safety.html) categories are updated accordingly.
As PARALLEL labels need to be stripped for incompatible PostgreSQL versions
please use _PARALLEL SAFE/RESTRICTED/UNSAFE_ in uppercase so it's handled
automatically.

Take into account:

*  Tests must be added for any new functionality
   (inside `src/pg/test`, `src/py/crankshaft/test`) as well as to
   detect any bugs that are being fixed.
*  Add or modify the corresponding documentation files in the `doc` folder.
*  Naming conventions for function names:
   - use `CamelCase`
   - prefix "public" functions with `CDB_`. E.g: `CDB_SpatialMarkovTrend`
   - prefix "private" functions with an underscore. E.g: `_CDB_MyObscureInternalImplementationDetail`

Once the code is ready to be tested, update the local development installation
with `sudo make install`.
This will update the 'dev' version of the extension in `src/pg/` and
make it available to PostgreSQL.

Run the tests with `make test`.

Update extension in a working database with:

```sql
ALTER EXTENSION crankshaft UPDATE TO 'current';
ALTER EXTENSION crankshaft UPDATE TO 'dev';
```

If the extension has not previously been installed in a database,
it can be installed directly with:
```sql
CREATE EXTENSION IF NOT EXISTS plpythonu;
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION crankshaft WITH VERSION 'dev';
```

Once the feature or bugfix is completed and all the tests are passing
a pull request shall be created, reviewed by a peer
and then merged back into the `develop` branch once all the CI tests pass.


## Relevant development targets in the Makefile

```shell
# Show a short description of the available targets
make help

# Generate the extension scripts and install the python package.
sudo make install

#  Run the tests against the installed extension.
make test
```

## Submitting contributions

Before opening a pull request (or submitting a contribution) you will need to sign a Contributor License Agreement (CLA) before making a submission, [learn more here](https://carto.com/contributions).
