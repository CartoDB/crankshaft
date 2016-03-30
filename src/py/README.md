# Crankshaft Python Package

...
### Run the tests

```bash
cd crankshaft
nosetests test/
```

## Notes about Python dependencies
* This extension is targeted at production databases. Therefore certain restrictions must be assumed about the production environment vs other experimental environments.
* We're using `pip` and `virtualenv` to generate a suitable isolated environment for python code that has  all the dependencies
* Every dependency should be:
  - Added to the `setup.py` file
  - Installed through it
  - Tested, when they have a test suite.
  - Fixed in the `requirements.txt`
* At present we use Python version 2.7.3

---

To avoid troublesome compilations/linkings we will use
the available system package `python-scipy`.
This package and its dependencies provide numpy 1.6.1
and scipy 0.9.0. To be able to use these versions we cannot
PySAL 1.10 or later, so we'll stick to 1.9.1.

```
apt-get install -y python-scipy
```

We'll use virtual environments to install our packages,
but configued to use also system modules so that the
mentioned scipy and numpy are used.

    # Create a virtual environment for python
    $ virtualenv --system-site-packages dev

    # Activate the virtualenv
    $ source dev/bin/activate

    # Install all the requirements
    # expect this to take a while, as it will trigger a few compilations
    (dev) $ pip install -I ./crankshaft

#### Test the libraries with that virtual env

##### Test numpy library dependency:

    import numpy
    numpy.test('full')

##### Run scipy tests

    import scipy
    scipy.test('full')

##### Testing pysal

See [http://pysal.readthedocs.org/en/latest/developers/testing.html]

This will require putting this into `dev/lib/python2.7/site-packages/setup.cfg`:

```
[nosetests]
ignore-files=collection
exclude-dir=pysal/contrib

[wheel]
universal=1
```

And copying some files before executing the tests:
(we'll use a temporary directory from where the tests will be executed because
some tests expect some files in the current directory). Next must be executed
from

```
cp dev/lib/python2.7/site-packages/pysal/examples/geodanet/* dev/local/lib/python2.7/site-packages/pysal/examples
mkdir -p test_tmp && cd test_tmp && cp ../dev/lib/python2.7/site-packages/pysal/examples/geodanet/* ./
```

Then, execute the tests with:

    import pysal
    import nose
    nose.runmodule('pysal')
