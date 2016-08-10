-- Install dependencies
CREATE EXTENSION plpythonu;
CREATE EXTENSION postgis VERSION '2.2.2';

-- Create role publicuser if it does not exist
DO
$$
BEGIN
   IF NOT EXISTS (
      SELECT *
      FROM   pg_catalog.pg_user
      WHERE  usename = 'publicuser') THEN

      CREATE ROLE publicuser LOGIN;
   END IF;
END
$$ LANGUAGE plpgsql;

-- Install the default version
CREATE EXTENSION crankshaft;
\dx
