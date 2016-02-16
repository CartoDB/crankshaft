#!/usr/local/bin/python
# -*- coding: utf-8 -*-

import unittest

from mock_plpy import MockPlPy
plpy = MockPlPy()

import sys
sys.modules['plpy'] = plpy

import crankshaft

class TestPoc(unittest.TestCase):
    def test_should_have_xyz(self):
        plpy._reset()
        plpy._define_result('select\s+\*\s+from\s+table', [{'x': 111}])
        assert crankshaft.poc.xyz() == 111
        assert plpy.notices[0] == 'XYZ...'
