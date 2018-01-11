"""Random seed generator used for non-deterministic functions in crankshaft"""
import random
import numpy


def set_random_seeds(value):
    """
    Set the seeds of the RNGs (Random Number Generators)
    used internally.
    """
    random.seed(value)
    numpy.random.seed(value)
