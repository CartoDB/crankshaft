-- =============================================================================================
--
-- CDB_Voronoi
--
-- =============================================================================================
CREATE OR REPLACE FUNCTION CDB_voronoi(
    IN geomin geometry[],
    IN buffer numeric DEFAULT 0.5,
    IN tolerance numeric DEFAULT 1e-9
    )
RETURNS geometry  AS $$
DECLARE
    geomout geometry;
BEGIN
    -- we need to make the geometry calculations in (pseudo)meters!!!
    with a as (
        SELECT unnest(geomin) as g1
    ),
    b as(
        SELECT st_transform(g1, 3857) g2 from a
    )
    SELECT array_agg(g2) INTO geomin from b;

    WITH
    convexhull_1 as (
        SELECT
            ST_ConvexHull(ST_Collect(geomin)) as g,
            buffer * |/ (st_area(ST_ConvexHull(ST_Collect(geomin)))/PI()) as r
    ),
    clipper as(
        SELECT
            st_buffer(ST_MinimumBoundingCircle(a.g), buffer*a.r)  as g
        FROM convexhull_1 a
    ),
    env0 as (
        SELECT
            (st_dumppoints(st_expand(a.g, buffer*a.r))).geom as e
        FROM  convexhull_1 a
    ),
    env as (
        SELECT
            array_agg(env0.e) as e
        FROM  env0
    ),
    sample AS (
        SELECT
            ST_Collect(geomin || env.e) as geom
        FROM env
    ),
    convexhull as (
        SELECT
            ST_ConvexHull(ST_Collect(geomin)) as cg
    ),
    tin as (
        SELECT
            ST_Dump(ST_DelaunayTriangles(geom, tolerance, 0)) as gd
        FROM
            sample
    ),
    tin_polygons as (
        SELECT
            (gd).Path as id,
            (gd).Geom as pg,
            ST_Centroid(ST_MinimumBoundingCircle((gd).Geom, 180)) as ct
        FROM tin
    ),
    tin_lines as (
        SELECT
            id,
            ST_ExteriorRing(pg) as lg
        FROM tin_polygons
    ),
    tin_nodes as (
        SELECT
            id,
            ST_PointN(lg,1) p1,
            ST_PointN(lg,2) p2,
            ST_PointN(lg,3) p3
        FROM tin_lines
    ),
    tin_edges AS (
        SELECT
            p.id,
            UNNEST(ARRAY[
            ST_MakeLine(n.p1,n.p2) ,
            ST_MakeLine(n.p2,n.p3) ,
            ST_MakeLine(n.p3,n.p1)]) as Edge,
            ST_Force2D(cdb_crankshaft._Find_Circle(n.p1,n.p2,n.p3)) as ct,
            CASE WHEN st_distance(p.ct, ST_ExteriorRing(p.pg)) < tolerance THEN
                TRUE
            ELSE  FALSE END AS ctx,
            p.pg,
            ST_within(p.ct, convexhull.cg) as ctin
        FROM
            tin_polygons p,
            tin_nodes n,
            convexhull
        WHERE p.id = n.id
    ),
    voro_nodes as (
        SELECT
            CASE WHEN x.ctx = TRUE THEN
                ST_Centroid(x.edge)
            ELSE
                x.ct
            END as xct,
            CASE WHEN y.id is null THEN
                CASE WHEN x.ctin = TRUE THEN
                    ST_SetSRID(ST_MakePoint(
                        ST_X(x.ct) + ((ST_X(ST_Centroid(x.edge)) - ST_X(x.ct)) * (1+buffer)),
                        ST_Y(x.ct) + ((ST_Y(ST_Centroid(x.edge)) - ST_Y(x.ct)) * (1+buffer))
                    ), ST_SRID(x.ct))
                END
            ELSE
                y.ct
            END as yct
        FROM
            tin_edges x
        LEFT OUTER JOIN
            tin_edges y
        ON x.id <> y.id AND ST_Equals(x.edge, y.edge)
    ),
    voro_edges as(
        SELECT
            ST_LineMerge(ST_Collect(ST_MakeLine(xct, yct))) as v
        FROM
            voro_nodes
    ),
    voro_cells as(
        SELECT
            ST_Polygonize(
                ST_Node(
                    ST_LineMerge(
                        ST_Union(v, ST_ExteriorRing(
                            ST_Convexhull(v)
                            )
                        )
                    )
                )
            ) as g
        FROM
            voro_edges
    ),
    voro_set as(
        SELECT
        (st_dump(v.g)).geom as g
        FROM voro_cells v
    ),
    clipped_voro as(
        SELECT
            ST_intersection(c.g, v.g) as g
        FROM
            voro_set v,
            clipper c
        WHERE
            ST_GeometryType(v.g) = 'ST_Polygon'
    )
    SELECT
        st_collect(
            ST_Transform(
                ST_ConvexHull(g),
                4326
            )
        )
    INTO geomout
    FROM
        clipped_voro;
    RETURN geomout;
END;
$$ language plpgsql IMMUTABLE PARALLEL SAFE;

/** ----------------------------------------------------------------------------------------
  * @function   : FindCircle
  * @precis     : Function that determines if three points form a circle. If so a table containing
  *               centre and radius is returned. If not, a null table is returned.
  * @version    : 1.0.1
  * @param      : p_pt1        : First point in curve
  * @param      : p_pt2        : Second point in curve
  * @param      : p_pt3        : Third point in curve
  * @return     : geometry     : In which X,Y ordinates are the centre X, Y and the Z being the radius of found circle
  *                              or NULL if three points do not form a circle.
  * @history    : Simon Greener - Feb 2012 - Original coding.
  *               Rafa de la Torre - Aug 2016 - Small fix for type checking
  *               Raul Marin - Sept 2017 - Remove unnecessary NULL checks and set function categories
  * @copyright  : Simon Greener @ 2012
  *               Licensed under a Creative Commons Attribution-Share Alike 2.5 Australia License. (http://creativecommons.org/licenses/by-sa/2.5/au/)
**/
CREATE OR REPLACE FUNCTION _Find_Circle(
    IN p_pt1 geometry,
    IN p_pt2 geometry,
    IN p_pt3 geometry)
  RETURNS geometry AS
$BODY$
DECLARE
   v_Centre geometry;
   v_radius NUMERIC;
   v_CX     NUMERIC;
   v_CY     NUMERIC;
   v_dA     NUMERIC;
   v_dB     NUMERIC;
   v_dC     NUMERIC;
   v_dD     NUMERIC;
   v_dE     NUMERIC;
   v_dF     NUMERIC;
   v_dG     NUMERIC;
BEGIN
   IF ( ST_GeometryType(p_pt1) <> 'ST_Point' OR
        ST_GeometryType(p_pt2) <> 'ST_Point' OR
        ST_GeometryType(p_pt3) <> 'ST_Point' ) THEN
      RAISE EXCEPTION 'All supplied geometries must be points.';
      RETURN NULL;
   END IF;
   v_dA := ST_X(p_pt2) - ST_X(p_pt1);
   v_dB := ST_Y(p_pt2) - ST_Y(p_pt1);
   v_dC := ST_X(p_pt3) - ST_X(p_pt1);
   v_dD := ST_Y(p_pt3) - ST_Y(p_pt1);
   v_dE := v_dA * (ST_X(p_pt1) + ST_X(p_pt2)) + v_dB * (ST_Y(p_pt1) + ST_Y(p_pt2));
   v_dF := v_dC * (ST_X(p_pt1) + ST_X(p_pt3)) + v_dD * (ST_Y(p_pt1) + ST_Y(p_pt3));
   v_dG := 2.0  * (v_dA * (ST_Y(p_pt3) - ST_Y(p_pt2)) - v_dB * (ST_X(p_pt3) - ST_X(p_pt2)));
   -- If v_dG is zero then the three points are collinear and no finite-radius
   -- circle through them exists.
   IF ( v_dG = 0 ) THEN
      RETURN NULL;
   ELSE
      v_CX := (v_dD * v_dE - v_dB * v_dF) / v_dG;
      v_CY := (v_dA * v_dF - v_dC * v_dE) / v_dG;
      v_Radius := SQRT(POWER(ST_X(p_pt1) - v_CX,2) + POWER(ST_Y(p_pt1) - v_CY,2) );
   END IF;
   RETURN ST_SetSRID(ST_MakePoint(v_CX, v_CY, v_radius),ST_Srid(p_pt1));
END;
$BODY$
  LANGUAGE plpgsql IMMUTABLE STRICT PARALLEL SAFE;

