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

### Sample session with virtualenv
#### Create and use a virtual env

    # Create the virtual environment for python
    $ virtualenv myenv

    # Activate the virtualenv
    $ source myenv/bin/activate

    # Install all the requirements
    # expect this to take a while, as it will trigger a few compilations
    (myenv) $ pip install -r requirements.txt

    # Add a new pip to the party
    (myenv) $ pip install pandas

#### Test the libraries with that virtual env
##### Test numpy library dependency:

    import numpy
    numpy.test('full')

output:
```
======================================================================
ERROR: test_multiarray.TestNewBufferProtocol.test_relaxed_strides
----------------------------------------------------------------------
Traceback (most recent call last):
  File "/home/ubuntu/www/crankshaft/src/py/dev2/lib/python2.7/site-packages/nose/case.py", line 197, in runTest
    self.test(*self.arg)
  File "/home/ubuntu/www/crankshaft/src/py/dev2/lib/python2.7/site-packages/numpy/core/tests/test_multiarray.py", line 5366, in test_relaxed_strides
    fd.write(c.data)
TypeError: 'buffer' does not have the buffer interface

----------------------------------------------------------------------
Ran 6153 tests in 84.561s

FAILED (KNOWNFAIL=3, SKIP=5, errors=1)
Out[2]: <nose.result.TextTestResult run=6153 errors=1 failures=0>
```

NOTE: this is expected to fail with Python 2.7.3, which is the version embedded in our postgresql installation


##### Run scipy tests

    import scipy
    scipy.test('full')

Output:
```
Ran 21562 tests in 321.610s

OK (KNOWNFAIL=130, SKIP=1840)
Out[2]: <nose.result.TextTestResult run=21562 errors=0 failures=0>
```
Ok, this looks good...

##### Testing pysal
See [http://pysal.readthedocs.org/en/latest/developers/testing.html]

    import pysal
    import nose
    nose.runmodule('pysal')

```
Ran 537 tests in 42.182s

FAILED (errors=48, failures=17)
An exception has occurred, use %tb to see the full traceback.
```

This doesn't look good... Taking a deeper look at the failures, many have the `IOError: [Errno 2] No such file or directory: 'streets.shp'`

In the source code, there's the following [config](https://github.com/pysal/pysal/blob/master/setup.cfg) that seems to be missing in the pip package. By copying it to `lib/python2.7/site-packages` within the environment, it goes down to 17 failures.

The remaining failures don't look good. I see two types: precision calculation errors and arrays/matrices missing 1 element when comparing... TODO: FIX this
