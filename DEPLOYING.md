# Workflow

... (branching/merging flow)

# Deployment

...

Deployment to db servers

```
# Install python module
sudo pip install python/crankshaft --upgrade

# Install extension
(cd pg && sudo PGUSER=postgres make all install)
```

Caveat: note that `pip install ./crankshaft` will install
from local files, but `pip install crankshaft` will not.

Installing the extension in user databases:

...
