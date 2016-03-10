# Crankshaft Python Package

...
### Run the tests

```bash
cd crankshaft
nosetests test/
```

## Notes about python dependencies
* This extension is targeted at production databases. Therefore certain restrictions must be assumed about the production environment vs other experimental environments.
* We're using `pip` and `virtualenv` to generate a suitable isolated environment for python code that has  all the dependencies
* Every dependency should be:
  - Added to the `setup.py` file
  - Installed through it
  - Tested, when they have a test suite.
  - Fixed in the `requirements.txt`
* At present we use Python version 2.7.3

---

We have two possible approaches being considered as to how manage
the Python virtual environment: using a pure virtual enviroment
or combine it with some system packages that include depencencies
for the *hard-to-compile* packages (and pin them in somewhat old versions).

### Alternative A: pure virtual environment

In this case we will install all the packages needed in the
virtual environment.
This will involve, specially for the numerical packages compiling
and linking code that uses a number of third party libraries,
and requires having theses depencencies solved for the production
environments.

#### Create and use a virtual env

We'll use a virtual enviroment directory `dev`
under the `src/pg` directory.

    # Create the virtual environment for python
    $ virtualenv dev

    # Activate the virtualenv
    $ source dev/bin/activate

    # Install all the requirements
    # expect this to take a while, as it will trigger a few compilations
    (dev) $ pip install -r requirements.txt

    # Add a new pip to the party
    (dev) $ pip install pandas

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


### Alternative B: using some packaged modules

This option avoids troublesome compilations/linkings, at the cost
of freezing some module versions as available in system packages,
namely numpy 1.6.1 and scipy 0.9.0. (in turn, this implies
the most recent version of PySAL we can use is 1.9.1)


TODO: to use this alternative the python-scipy package must be
installed (this will have to be included in server provisioning)

```
apt-get install -y python-scipy
```

#### Create and use a virtual env

We'll use a `dev` enviroment as before, but will configure it to
use also system modules.


    # Create the virtual environment for python
    $ virtualenv --system-site-packages dev

    # Activate the virtualenv
    $ source dev/bin/activate

    # Install all the requirements
    # expect this to take a while, as it will trigger a few compilations
    (dev) $ pip install -I ./crankshaft

Then we can proceed to testing as in Alternative A.
