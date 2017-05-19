-- Calculate the distance matrix using underlying road network
-- Sample usage:
--   select * from cdb_distancematrix('drain_table'::regclass,
--                                    'source_table'::regclass)
CREATE OR REPLACE FUNCTION CDB_DistanceMatrix(
    origin_table regclass,
    destination_table regclass,
    transit_mode text DEFAULT 'car'
    )
    RETURNS TABLE(origin_id bigint, destination_id bigint,
                  the_geom geometry(geometry, 4326),
                  length_km numeric, duration_sec numeric)
AS $$
BEGIN
    RETURN QUERY
    EXECUTE format('
        WITH pairs AS (
            SELECT
                o."cartodb_id" AS origin_id,
                d."cartodb_id" AS destination_id,
                o."the_geom" AS origin_point,
                d."the_geom" AS destination_point
            FROM
                (SELECT * FROM %I) AS o,
                (SELECT * FROM %I) AS d),
        results AS (
            SELECT
                origin_id,
                destination_id,
                (cdb_route_point_to_point(origin_point,
                                          destination_point,
                                          $1)).*
            FROM pairs)
        SELECT
            origin_id::bigint AS origin_id,
            destination_id::bigint AS destination_id,
            shape AS the_geom,
            length::numeric AS length_km,
            duration::numeric AS duration_sec
        FROM results;', origin_table, destination_table)
        USING transit_mode;
    RETURN;
END;
$$ LANGUAGE plpgsql;
