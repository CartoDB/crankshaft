# Workflow

... (branching/merging flow)

# Deployment

...

Deployment to db servers

```
(cd pg && sudo PGUSER=postgres make all install)
```

Installing only the Python package:

```
sudo pip install python/crankshaft --upgrade
```

Caveat: note that `pip install ./crankshaft` will install
from local files, but `pip install crankshaft` will not.

Installing the extension in user databases:

...
