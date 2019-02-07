
"""
CartoDB Spatial Analysis Python Library
See:
https://github.com/CartoDB/crankshaft
"""

from setuptools import setup, find_packages

setup(
    name='crankshaft',

    version='0.8.2',

    description='CartoDB Spatial Analysis Python Library',

    url='https://github.com/CartoDB/crankshaft',

    author='Data Services Team - CartoDB',
    author_email='dataservices@cartodb.com',

    license='MIT',

    classifiers=[
        'Development Status :: 3 - Alpha',
        'Intended Audience :: Mapping comunity',
        'Topic :: Maps :: Mapping Tools',
        'License :: OSI Approved :: MIT License',
        'Programming Language :: Python :: 2.7',
    ],

    keywords='maps mapping tools spatial analysis geostatistics',

    packages=find_packages(exclude=['contrib', 'docs', 'tests']),

    extras_require={
        'dev': ['unittest'],
        'test': ['unittest', 'nose', 'mock'],
    },

    # The choice of component versions is dictated by what's
    # provisioned in the production servers.
    # IMPORTANT NOTE: please don't change this line. Instead issue a ticket to systems for evaluation.
    install_requires=['joblib==0.9.4', 'numpy==1.11.0', 'scipy==0.17.0', 'pysal==1.14.3', 'scikit-learn==0.17.0'],

    requires=['pysal', 'numpy', 'sklearn'],

    test_suite='test'
)
