-- Spatial k-means clustering

CREATE OR REPLACE FUNCTION CDB_KMeans(
  query TEXT,
  no_clusters INTEGER,
  no_init INTEGER DEFAULT 20
)
RETURNS TABLE(
  cartodb_id INTEGER,
  cluster_no INTEGER
) AS $$

from crankshaft.clustering import Kmeans
kmeans = Kmeans()
return kmeans.spatial(query, no_clusters, no_init)

$$ LANGUAGE plpythonu VOLATILE PARALLEL UNSAFE;

-- Non-spatial k-means clustering
-- query: sql query to retrieve all the needed data
-- colnames: text array of column names for doing the clustering analysis
-- no_clusters: number of requested clusters
-- standardize: whether to scale variables to a mean of zero and a standard
--              deviation of 1
-- id_colname: name of the id column

CREATE OR REPLACE FUNCTION CDB_KMeansNonspatial(
  query TEXT,
  colnames TEXT[],
  no_clusters INTEGER,
  standardize BOOLEAN DEFAULT true,
  id_col TEXT DEFAULT 'cartodb_id'
)
RETURNS TABLE(
  cluster_label text,
  cluster_center json,
  silhouettes numeric,
  inertia numeric,
  rowid bigint
) AS $$

from crankshaft.clustering import Kmeans
kmeans = Kmeans()
return kmeans.nonspatial(query, colnames, no_clusters,
                         standardize=standardize,
                         id_col=id_col)
$$ LANGUAGE plpythonu VOLATILE PARALLEL UNSAFE;


CREATE OR REPLACE FUNCTION CDB_WeightedMeanS(
  state NUMERIC[],
  the_geom GEOMETRY(Point, 4326),
  weight NUMERIC
)
RETURNS Numeric[] AS $$
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


CREATE OR REPLACE FUNCTION CDB_WeightedMeanF(state NUMERIC[])
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
DO $$ BEGIN
    CREATE AGGREGATE CDB_WeightedMean(geometry(Point, 4326), NUMERIC) (
        SFUNC = CDB_WeightedMeanS,
        FINALFUNC = CDB_WeightedMeanF,
        STYPE = Numeric[],
        PARALLEL = SAFE,
        INITCOND = "{0.0,0.0,0.0}"
);
EXCEPTION
    WHEN duplicate_function THEN NULL;
END $$;
