import unittest

from mock_plpy import MockPlPy
plpy = MockPlPy()

import sys
sys.modules['plpy'] = plpy
