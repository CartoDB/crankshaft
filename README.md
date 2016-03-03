# crankshaft

CartoDB Spatial Analysis extension for PostgreSQL.

## Code organization

* *pg* contains the PostgreSQL extension source code
* *python* Python module

## Running with Docker

Crankshaft comes with a Dockerfile to build and run a sandboxed machine for testing
and development.

First you have to build the docker container

    docker build -t crankshaft .

To run the pg tests run

    docker run -it --rm -v $(pwd):/crankshaft  crankshaft /root/run_tests.sh

if there are failures it will dump the reasion to the screen.

To run a server you can develop on run

    docker run -it --rm -v $(pwd):/crankshaft -p $(docker-machine ip default):5432:5432 /root/run_server.sh

and connect from you host using

    psql -U pggis -h $(docker-machine ip default) -p 5432 -W

the password is pggis




## Requirements

* pip
