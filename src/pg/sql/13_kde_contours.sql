CREATE OR REPLACE FUNCTION CDB_KDEContours(geoms geometry[], point_vals numeric[], levels numeric[], bandwidth double precision, gridx integer DEFAULT 100, gridy integer DEFAULT 100)
  RETURNS TABLE(geom geometry, val float) AS
$BODY$
DECLARE
extent box2d;
rast    raster;
xcorner double precision;
ycorner double precision;
resolutionx double precision;
resolutiony double precision;
width double precision;
height double precision;
ynew double precision;
xnew double precision;
kde_value double precision;
kde_matrix double precision[];
distance double precision[];
point_value integer[];
length integer;
kde_term double precision;
query character varying;
constant double precision;
BEGIN
SELECT ST_EXTENT(ST_Collect(geoms)) INTO extent;

rast := st_makeemptyraster(gridx,
                         gridy,
                         ST_XMIN(extent),
                         ST_YMIN(extent),
                         (ST_XMAX(extent) - ST_XMIN(extent))/gridx,
                         (ST_YMAX(extent) - ST_YMIN(extent))/gridy,
                         0,
                         0,
                         4326);

rast := ST_AddBand(rast, 1, '32BF', 0, 0);

SELECT ST_UpperLeftX(rast) INTO xcorner;
SELECT ST_UpperLeftY(rast) INTO ycorner;
SELECT ST_ScaleX(rast) INTO resolutionx;
SELECT ST_ScaleY(rast) INTO resolutiony;
SELECT ST_Width(rast) into width;
SELECT ST_Height(rast) into height;

xcorner=xcorner + resolutionx/2;
ycorner=ycorner + resolutiony/2;
constant = 1; -- 3/(pi()*power(bandwidth, 2))*1000000;
FOR j in 0..height-1 LOOP
    ynew=ycorner+j*resolutiony;
    FOR i in 0..width-1 LOOP
        xnew=xcorner+i*resolutionx;
        SELECT
        array_agg(
            st_distance(
                CDB_LATLNG(ynew,xnew),
                a.geom
            )
        ), array_agg(value)
        INTO distance, point_value
        FROM (select unnest(geoms) as geom , unnest(point_vals) as value ) as a
        WHERE ST_DWITHIN(a.geom, CDB_LATLNG(ynew,xnew), bandwidth) ;

        SELECT array_length(point_value, 1 ) into length;
        kde_value=0;

        IF length IS NOT NULL THEN
            FOR k in 1..length LOOP

                kde_term = point_value[k]*constant*power(1-power(distance[k]/bandwidth, 2), 2);
                kde_value := kde_value+kde_term;
            END LOOP;
        END IF;
    IF kde_value < levels[1] THEN
      kde_matrix[i] := 1;
    ELSE
      kde_matrix[i] := (select bin - 1 from (
            select GENERATE_SERIES(1, array_upper(levels,1)) as bin, unnest(levels) as level
          ) As x where kde_value < level limit 1);
    END IF;

    END LOOP;
    SELECT ST_SetValues(rast, 1, 1, j+1, kde_matrix) into rast;
END LOOP;

RETURN QUERY
  select x.geom, levels[x.val::int]::float from (
    select (ST_DumpAsPolygons(rast)).*
  ) as x;
RETURN ;

END;
$BODY$
LANGUAGE plpgsql;
