#!/usr/local/bin/python
# -*- coding: utf-8 -*-

import unittest

class MockPlPy:
    def notice(self, msg):
        print msg

import sys
sys.modules['plpy'] = MockPlPy()
import crankshaft

class TestPoc(unittest.TestCase):
    def test_should_have_xyz(self):
        assert crankshaft.poc.xyz() == "xyz-result"
