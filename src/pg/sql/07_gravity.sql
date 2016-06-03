CREATE OR REPLACE FUNCTION CDB_Gravity(
    IN t_id bigint[],
    IN t_geom geometry[],
    IN t_weight numeric[],
    IN s_id bigint[],
    IN s_geom geometry[],
    IN s_pop numeric[],
    IN target bigint,
    IN radius integer,
    IN minval numeric DEFAULT -10e307
    )
RETURNS TABLE(
    the_geom geometry,
    source_id bigint,
    target_id bigint,
    dist numeric,
    h numeric,
    hpop numeric)  AS $$
DECLARE
    t_type text;
    s_type text;
    t_center geometry[];
    s_center geometry[];
BEGIN
    t_type := GeometryType(t_geom[1]);
    s_type := GeometryType(s_geom[1]);
    IF t_type = 'POINT' THEN
        t_center := t_geom;
    ELSE
        WITH tmp as (SELECT unnest(t_geom) as g) SELECT array_agg(ST_Centroid(g)) INTO t_center FROM tmp;
    END IF;
    IF s_type = 'POINT' THEN
        s_center := s_geom;
    ELSE
        WITH tmp as (SELECT unnest(s_geom) as g) SELECT array_agg(ST_Centroid(g)) INTO s_center FROM tmp;
    END IF;
    RETURN QUERY
        with target0 as(
            SELECT unnest(t_center) as tc, unnest(t_weight) as tw, unnest(t_id) as td
        ),
        source0 as(
            SELECT unnest(s_center) as sc, unnest(s_id) as sd, unnest (s_geom) as sg, unnest(s_pop) as sp
        ),
        prev0 as(
            SELECT
                source0.sg,
                source0.sd as sourc_id,
                coalesce(source0.sp,0) as sp,
                target.td as targ_id,
                coalesce(target.tw,0) as tw,
                GREATEST(1.0,ST_Distance(geography(target.tc), geography(source0.sc)))::numeric as distance
            FROM source0
            CROSS JOIN LATERAL
                (
                SELECT
                    *
                FROM target0
                    WHERE tw > minval
                    AND ST_DWithin(geography(source0.sc), geography(tc), radius)
                ) AS target
        ),
        deno as(
            SELECT
                sourc_id,
                sum(tw/distance) as h_deno
            FROM
                prev0
            GROUP BY sourc_id
        )
        SELECT
            p.sg as the_geom,
            p.sourc_id as source_id,
            p.targ_id as target_id,
            case when p.distance > 1 then p.distance else 0.0 end as dist,
            100*(p.tw/p.distance)/d.h_deno as h,
            p.sp*(p.tw/p.distance)/d.h_deno as hpop
        FROM
            prev0 p,
            deno d
        WHERE
            p.targ_id = target AND
            p.sourc_id = d.sourc_id;
END;
$$ language plpgsql;
