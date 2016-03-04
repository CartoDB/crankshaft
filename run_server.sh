#!/bin/bash
/sbin/my_init &

echo "Waiting for PostgreSQL to run..."
sleep 1
while ! /usr/bin/pg_isready -q
do
    sleep 1
    echo -n "."
done

cd /crankshaft/pg
make install
fg
