# Workflow

... (branching/merging flow)

# Deployment

...

Deployment to db servers

```
# Install python module
sudo pip install {{path}}/python/crankshaft --upgrade

# Install extension
cd {{path}}/pg && sudo PGUSER=postgres make all install
```

Caveat: note that `pip install ./crankshaft` will install
from local files, but `pip install crankshaft` will not.

Installing the extension in user databases:

...
