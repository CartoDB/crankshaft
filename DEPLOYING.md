# Workflow

... (branching/merging flow)

# Deployment

...

Deployment to db servers: the next command will install both the Python
package and the extension.

```
sudo make install
```

Installing only the Python package:

```
sudo pip install python/crankshaft --upgrade
```

Caveat: note that `pip install ./crankshaft` will install
from local files, but `pip install crankshaft` will not.

CI: Install and run the tests on the installed extension and package:

```
(sudo make install && PGUSER=postgres make testinstalled)
```

Installing the extension in user databases:
Once installed in a server, the extension can be added
to a database with the next SQL command:

```
CREATE EXTENSION crankshaft;
```

To upgrade the extension to an specific version X.Y.Z:

```
ALTER EXTENSION crankshaft UPGRADE TO 'X.Y.Z';
```
