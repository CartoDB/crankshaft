import unittest

from mock_plpy import MockPlPy
plpy = MockPlPy()

import sys
sys.modules['plpy'] = plpy

import os

def fixture_file(name):
    dir = os.path.dirname(os.path.realpath(__file__))
    return os.path.join(dir, 'fixtures', name)
