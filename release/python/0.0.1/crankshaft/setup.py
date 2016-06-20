
"""
CartoDB Spatial Analysis Python Library
See:
https://github.com/CartoDB/crankshaft
"""

from setuptools import setup, find_packages

setup(
    name='crankshaft',

    version='0.0.01',

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
    install_requires=['pysal==1.11.0','numpy==1.10.1','scipy==0.17.0','pandas','sklearn'],


    test_suite='test'
)
