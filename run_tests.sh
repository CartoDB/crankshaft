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
PGUSER=pggis PGPASSOWRD=pggis PGHOST=localhost make installcheck



if [ "$?" -eq "0" ]
then
  echo "PASSED"
else
  cat /crankshaft/pg/test/0.0.1/regression.diffs
fi
