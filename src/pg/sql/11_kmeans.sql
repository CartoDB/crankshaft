-- Spatial k-means clustering

CREATE OR REPLACE FUNCTION CDB_KMeans(query text, no_clusters integer, no_init integer default 20)
RETURNS table (cartodb_id integer, cluster_no integer) as $$

    from crankshaft.clustering import Kmeans
    kmeans = Kmeans()
    return kmeans.spatial(query, no_clusters, no_init)

$$ LANGUAGE plpythonu VOLATILE PARALLEL UNSAFE;


CREATE OR REPLACE FUNCTION CDB_WeightedMeanS(state Numeric[],the_geom GEOMETRY(Point, 4326), weight NUMERIC)
RETURNS Numeric[] AS
$$
DECLARE
    newX NUMERIC;
    newY NUMERIC;
    newW NUMERIC;
BEGIN
    IF weight IS NULL OR the_geom IS NULL THEN
        newX = state[1];
        newY = state[2];
        newW = state[3];
    ELSE
        newX = state[1] + ST_X(the_geom)*weight;
        newY = state[2] + ST_Y(the_geom)*weight;
        newW = state[3] + weight;
    END IF;
    RETURN Array[newX,newY,newW];

END
$$ LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE;

CREATE OR REPLACE FUNCTION CDB_WeightedMeanF(state Numeric[])
RETURNS GEOMETRY AS
$$
BEGIN
    IF state[3] = 0 THEN
        RETURN ST_SetSRID(ST_MakePoint(state[1],state[2]), 4326);
    ELSE
        RETURN ST_SETSRID(ST_MakePoint(state[1]/state[3], state[2]/state[3]),4326);
    END IF;
END
$$ LANGUAGE plpgsql IMMUTABLE PARALLEL SAFE;

-- Create aggregate if it did not exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT *
        FROM pg_catalog.pg_proc p
            LEFT JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'cdb_crankshaft'
            AND p.proname = 'cdb_weightedmean'
            AND p.proisagg)
    THEN
        CREATE AGGREGATE CDB_WeightedMean(geometry(Point, 4326), NUMERIC) (
            SFUNC = CDB_WeightedMeanS,
            FINALFUNC = CDB_WeightedMeanF,
            STYPE = Numeric[],
            PARALLEL = SAFE,
            INITCOND = "{0.0,0.0,0.0}"
        );
    END IF;
END
$$ LANGUAGE plpgsql;
