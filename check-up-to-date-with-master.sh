#!/bin/bash

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)

if [[ "$CURRENT_BRANCH" == "master" || "$CURRENT_BRANCH" == "HEAD" ]]
then
    echo "master branch or detached HEAD"
    exit 0
fi

# Add remote-master
git remote add -t master remote-master https://github.com/CartoDB/crankshaft.git

# Fetch master reference
git fetch --depth=1 remote-master master

# Compare HEAD with master
# NOTE: travis by default uses --depth=50 so we are actually checking that the tip
# of the branch is no more than 50 commits away from master as well.
git rev-list HEAD | grep $(git rev-parse remote-master/master) ||
    { echo "Your branch is not up to date with latest release";
      echo "Please update it by running the following:";
      echo "    git fetch && git merge origin/develop";
      false; }
