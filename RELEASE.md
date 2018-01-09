# Release & Deployment Process

The release process of a new version of the extension
shall be performed by the designated *Release Manager*.

## Release steps
* Make sure `develop` branch passes all the tests.
* Merge `develop` into `master`
* Update the version number in `src/pg/crankshaft.control`.
* Generate the next release files with this command:

  ```shell
  make release
  ```
* Generate an upgrade path from the previous to the next release by copying the generated release file. E.g:

  ```shell
  cp release/crankshaft--X.Y.Z.sql release/crankshaft--A.B.C--X.Y.Z.sql
  ```
  NOTE: you can rely on this thanks to the compatibility checks.
  TODO: automate this step [#94](https://github.com/CartoDB/crankshaft/issues/94)

    * Update the [NEWS.md](https://github.com/CartoDB/crankshaft/blob/master/NEWS.md) file
    * Commit and push the generated files.
    * Tag the release:

  ```
  git tag -a X.Y.Z -m "Release X.Y.Z"
  git push origin X.Y.Z
  ```

* Deploy and test in staging
* Merge `master` into **`stable`**
* Deploy and test in production
* Merge `master` into **`develop`**


## Some remarks
* Version numbers shall follow [Semantic Versioning 2.0](http://semver.org/).
* CI tests will take care of **forward compatibility** of the extension at postgres level.
* **Major version changes** (breaking forward compatibility) are a major event and are out of the scope of this doc. They **shall be avoided as much as we can**.
* We will go forward, never backwards. **Generating upgrade paths automatically is easy** and we'll rely on the CI checks for that.

## Deploy commands

The new release can be deployed for staging/smoke tests with this command:

  ```shell
  sudo make deploy
  ```

To install a specific version 'X.Y.Z' different from the default one:

  ```shell
  sudo make deploy RELEASE_VERSION=X.Y.Z
  ```
