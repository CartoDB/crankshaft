--
-- Creates N points randomly distributed arround the polygon
--
-- @param g - the geometry to be turned in to points
--
-- @param no_points - the number of points to generate
--
-- @params max_iter_per_point - the function generates points in the polygon's bounding box
-- and discards points which don't lie in the polygon. max_iter_per_point specifies how many
-- misses per point the funciton accepts before giving up.
--
-- Returns: Multipoint with the requested points

CREATE OR REPLACE FUNCTION CDB_DotDensity(g geometry, no_points integer, max_iter integer DEFAULT 1000)
 RETURNS SETOF geometry
AS $$
 DECLARE
     extent GEOMETRY;
     eq_area_geom GEOMETRY;
     test_point Geometry;
     width    NUMERIC;
     height   NUMERIC;
     x0       NUMERIC;
     y0       NUMERIC;
     no_left  INTEGER;
     sample_points GEOMETRY[];
     points   GEOMETRY[];
 BEGIN        
   eq_area_geom := ST_TRANSFORM(g,2163);
   extent   := ST_Envelope(eq_area_geom);
   max_iter := 0;
   width    := ST_XMax(extent) - ST_XMIN(extent);
   height   := ST_YMax(extent) - ST_YMIN(extent);
   x0       := ST_XMin(extent);
   y0       := ST_YMin(extent);
   no_left  := no_points;
   
   LOOP
     IF(no_left<=0 or max_iter=1000) THEN
       RETURN;
     END IF;

    
    with random_points as( 
        SELECT ST_SetSRID(ST_MAKEPOINT( x0 + width*random(),y0 + height*random()), 2163) as p
        FROM generate_series(1,no_left)
     )
     SELECT array_agg(p) from random_points
     WHERE ST_WITHIN(p, eq_area_geom)
     into sample_points;
     
     RETURN QUERY select ST_TRANSFORM(a,4236) from unnest(sample_points) as a;
     
     IF sample_points IS NOT null THEN 
        no_left = no_left - array_length(sample_points,1);
     END IF;
     max_iter = max_iter + 1;
   END LOOP;
 
   RETURN;
 END
$$ LANGUAGE plpgsql;

--
-- Creates N points randomly distributed in the specified secondary polygons
--
-- @param g - array of the geometries to be turned in to points
--
-- @param no_points - the number of points to generate
-- 
-- @params max_iter_per_point - the function generates points in the polygon's bounding box
-- and discards points which don't lie in the polygon. max_iter_per_point specifies how many
-- misses per point the funciton accepts before giving up.
--
-- Returns: Multipoint with the requested points



--
-- Generate a random response based on the weights given
--
-- @param array_ids an array of ids representing the category to return
--
-- @param weights an array of weights for each category
--
-- Returns : The randomly selected ID.

CREATE OR REPLACE function _cdb_SelectRandomWeights(array_ids numeric[], weights numeric[]) returns NUMERIC
 as $$
 DECLARE
     result NUMERIC;
 BEGIN
 
     WITH idw as (
         select unnest(array_ids) as id, unnest(weights) as percent
     ),
     CTE AS (
         SELECT random() * (SELECT SUM(percent) FROM idw) R
     )
     SELECT *
     FROM (
         SELECT id, SUM(percent) OVER (ORDER BY id) S, R
         FROM idw as percent CROSS JOIN CTE
     ) Q
     WHERE S >= R
     ORDER BY id
     LIMIT 1
     into result;
     return result;
 END
 $$ LANGUAGE plpgsql;

-- 
-- Weighted Dot Density
--
-- @param no_points the number of points to generate 
--
-- @param geoms the target geometries to place the points in 
--
-- @param weights the weight for each of the target polygons
--
-- RETURNS set of points 

CREATE OR REPLACE FUNCTION _cdb_WeightedDD(no_points numeric, geoms geometry[], weights numeric[])
 RETURNS SETOF geometry
AS $$
DECLARE 
 i NUMERIC;
 ids NUMERIC[];
 perGeom NUMERIC[];
 selected_poly NUMERIC;
BEGIN
 with idseries as (
     select generate_series(1,array_upper(geoms,1)) as id      
 )    
 select array_agg(id) from idseries into ids;

 FOR i in 1..no_points
 LOOP
    select cdb_crankshaft._cdb_SelectRandomWeights(ids, weights) INTO selected_poly;
    perGeom[selected_poly] = coalesce(perGeom[selected_poly] + 1, 0 );
 END LOOP;

 raise notice 'pergeom %', perGeom;

 FOR i in 1..array_length(ids,1)
 LOOP
     return QUERY
     select cdb_crankshaft.CDB_DotDensity(geoms[i], coalesce(perGeom[i],0)::INTEGER);
 END LOOP;
END
$$
LANGUAGE plpgsql;


-- 
-- Daysymetric Dot Density
--
-- @param geom: the geometry that has the  
--
-- @param no_points: the total number of points to create 
-- 
-- @param targetGeoms: the geometry that has the 
--
-- @param weights: targetGeom weights
--
-- RETURNS setof points 

CREATE OR REPLACE FUNCTION CDB_DasymetricDotDensity(geom GEOMETRY, no_points NUMERIC, targetGeoms GEOMETRY[], weights numeric [])
RETURNS setof GEOMETRY 
AS $$
  BEGIN
    RAISE NOTICE 'running Dasymetric';
    RETURN QUERY 
        SELECT cdb_crankshaft._CDB_WeightedDD(no_points, array_agg( ST_INTERSECTION(geom,g)), array_agg(ST_AREA(ST_INTERSECTION(geom,g))*w)::NUMERIC[]) 
        FROM unnest(targetGeoms) as g , unnest(weights) as w 
        WHERE geom && g;
  END
$$ 
LANGUAGE plpgsql;
