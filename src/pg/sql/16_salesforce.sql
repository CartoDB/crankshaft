CREATE OR REPLACE FUNCTION CDB_SalesForce(
    IN salesmen_g geometry[],
    IN salesmen_id bigint[],
    IN clients_g geometry[],
    IN clients_id bigint[],
    IN clients_w numeric[] DEFAULT '{}'::numeric[]
    )
RETURNS TABLE(
    cartodb_id bigint,
    the_geom geometry,
    salesman bigint,
    dist numeric
)  AS $$
DECLARE
    id_c bigint;
    i integer;
    j integer;
    lim integer;
    flag boolean;
    cids bigint[];
    cws numeric[];
    sids bigint[][]; -- [c][s]
    dists numeric[][];
    rs integer[][];
    poss integer[][];
    results text[]; -- [s]concat(c) !!!
    we numeric []; -- [s]
    s bigint;
BEGIN

    -- init salesmen weights to zero
    we := array_fill(0, ARRAY[array_length(salesmen_id,1)]);

    -- init results
    results := array_fill(''::text, ARRAY[array_length(salesmen_id,1)]);

    -- if not weighting is set, default to 1, so the share is based only on counting the clients
    IF clients_w = '{}'::numeric[] THEN
        clients_w := array_fill(1, ARRAY[array_length(clients_id,1)]);
        SELECT ceil((sum(t.a)::numeric/array_length(salesmen_id,1)::numeric)) into lim FROM unnest(clients_w) as t(a);
    ELSE
        lim := ceil((array_length(clients_id,1)::numeric/array_length(salesmen_id,1)::numeric));
    END IF;

    -- magic tricks to create a weighted-ordered set of clients to assign to salesmen
    WITH
    c AS(
        SELECT *
        FROM unnest(clients_id, clients_g, clients_w) AS t(id, geom, w)
    ),
    s AS(
        SELECT *
        FROM unnest(salesmen_id, salesmen_g) AS t(id, geom)
    ),
    d AS(
        SELECT
            c.id AS cid,
            c.w as cw,
            c.geom AS cgeom,
            s.id AS sid,
            ST_Distance(c.geom::geography, s.geom::geography) as dista
        FROM c, s
    ),
    ra AS(
        SELECT
            *,
            rank() over(order by dista) as r
        FROM d
        ORDER BY dista ASC
    ),
    ag AS(
        SELECT
            array_agg(cid) as cids,
            array_agg(cw) as cws,
            array_agg(sid) as sids,
            array_agg(dista) as dists,
            array_agg(r) as ranks
        FROM ra
        GROUP BY sid
    ),
    un AS(
        SELECT
            t.*
        FROM
            ag,
            unnest(ag.cids, ag.cws, ag.sids, ag.dists, ag.ranks) WITH ORDINALITY AS t(cid, cw, sid, dista, r, pos)
    ),
    un0 AS(
        SELECT
        *
        FROM un
        ORDER BY pos ASC, r ASC
    ),
    un1 AS(
        SELECT
            cid,
            max(cw) as cw,
            array_agg(sid) as s1,
            array_agg(dista) as d1,
            array_agg(r) as r1,
            array_agg(pos) as p1
        FROM un0
        GROUP BY cid
    )

    -- TODO necesito que todos las arrays que voy a agregar tengan las mismas dimensiones
    -- deberían tenerlas, así que tengo que debuggear esto a fondo

    SELECT
        array_agg(cid),
        array_agg(cw),
        array_agg(s1),
        array_agg(d1),
        array_agg(r1),
        array_agg(p1)
    INTO cids, cws, sids, dists, rs, poss
    FROM un1;

    raise notice 'BLOQUE 1';

    -- cids[n_clientes]
    -- xxxx[n_clientes][m_vendedores]

    -- assign clients to salesmen in an fare way

    -- clients with bigger weight than the share and assign to the closest one


    -- assign normal clients
    -- clients loop
    FOR i IN 1..array_length(cids,1)
    LOOP

        flag := false;

         -- salesmen loop to check
        FOR j IN 1..array_length(sids,2)
        LOOP
            s := array_position(salesmen_id, sids[i][j]);
            IF results[s]=''::text THEN
                results[s] := cids[i]::text;
                we[s] := we[s] + cws[i];
                flag := true;
            ELSEIF (we[s] + cws[i]) <= lim::numeric THEN
                results[s] := results[s] || ',' || cids[i]::text;
                we[s] := we[s] + cws[i];
                flag := true;
            ELSE
                CONTINUE;
            END IF;
        END LOOP;

        -- assign leftovers to salesmen with the least weight assigned
        IF flag = false THEN
            WITH a AS(
                SELECT min(t.w) as mw FROM unnest(we) as t(w)
            )
            SELECT array_position(we, mw) INTO s FROM a;
            results[s] = results[s] || ',' || cids[i]::text;
        END IF;

    END LOOP;

    raise notice 'BLOQUE 2';

    RETURN QUERY
    WITH
    a AS(
        SELECT *
        FROM unnest(clients_id, clients_g) WITH ORDINALITY AS t(id, geom, cnum)
    ),
    b AS(
        SELECT unnest(salesmen_id) as id
    ),
    c AS(
        SELECT
            b.id as sales_id,
            string_to_array(results[b.id]::text,',') as clients_list
        FROM b
    ),
    d AS(
        SELECT
            sales_id,
            unnest(clients_list) as c_id
        FROM c
    )
    SELECT
        d.c_id::bigint as cartodb_id,
        a.geom as the_geom,
        d.sales_id as salesman,
        0.0 as dist
    FROM d LEFT JOIN a
    ON d.c_id::bigint = a.id;
END;
$$ language plpgsql;


 -- ====================== ^^^ ====================================
-- test
 -- ====================== ^^^ ====================================
WITH
a0 AS (
    with gs as (SELECT generate_series(1001,1100) as g) select array_agg(g::bigint) as id from gs
),
a AS(
    SELECT
    ARRAY[ST_GeomFromText('POINT(2.0094998 41.56084)',4326),ST_GeomFromText('POINT(1.9017609 41.751904)',4326),ST_GeomFromText('POINT(2.2879717 41.607166)',4326),ST_GeomFromText('POINT(2.440357 41.537346)',4326),ST_GeomFromText('POINT(2.1818209 41.3845)',4326),ST_GeomFromText('POINT(2.17232 41.387226)',4326),ST_GeomFromText('POINT(2.662422 41.614433)',4326),ST_GeomFromText('POINT(2.0884423 41.56739)',4326),ST_GeomFromText('POINT(2.1622047 41.396294)',4326),ST_GeomFromText('POINT(2.1431918 41.393257)',4326),ST_GeomFromText('POINT(2.038296 41.498665)',4326),ST_GeomFromText('POINT(2.1885037 41.4086)',4326),ST_GeomFromText('POINT(2.2620609 41.933983)',4326),ST_GeomFromText('POINT(2.1774142 41.393185)',4326),ST_GeomFromText('POINT(1.7493595 41.52091)',4326),ST_GeomFromText('POINT(1.8066354 41.237595)',4326),ST_GeomFromText('POINT(2.1870465 41.484047)',4326),ST_GeomFromText('POINT(2.1743655 41.379704)',4326),ST_GeomFromText('POINT(2.1593754 41.386795)',4326),ST_GeomFromText('POINT(1.6866413 41.530136)',4326),ST_GeomFromText('POINT(1.753264 41.319954)',4326),ST_GeomFromText('POINT(2.154538 41.37552)',4326),ST_GeomFromText('POINT(2.1545222 41.39503)',4326),ST_GeomFromText('POINT(1.8620557 42.252544)',4326),ST_GeomFromText('POINT(2.2524126 41.924335)',4326),ST_GeomFromText('POINT(1.90089 41.75168)',4326),ST_GeomFromText('POINT(2.2647865 41.5435)',4326),ST_GeomFromText('POINT(2.3511453 41.637638)',4326),ST_GeomFromText('POINT(2.319214 41.47927)',4326),ST_GeomFromText('POINT(2.123184 41.39765)',4326),ST_GeomFromText('POINT(2.192867 41.447216)',4326),ST_GeomFromText('POINT(1.6158936 41.582874)',4326),ST_GeomFromText('POINT(2.114771 41.534817)',4326),ST_GeomFromText('POINT(1.8649682 42.250668)',4326),ST_GeomFromText('POINT(2.1476336 41.392284)',4326),ST_GeomFromText('POINT(2.1742537 41.374542)',4326),ST_GeomFromText('POINT(2.1457734 41.379475)',4326),ST_GeomFromText('POINT(2.1604836 41.430164)',4326),ST_GeomFromText('POINT(2.1750448 41.37939)',4326),ST_GeomFromText('POINT(2.134749 41.40244)',4326),ST_GeomFromText('POINT(2.1439674 41.397182)',4326),ST_GeomFromText('POINT(2.2578955 41.92931)',4326),ST_GeomFromText('POINT(2.1476197 41.397587)',4326),ST_GeomFromText('POINT(1.7001969 41.346264)',4326),ST_GeomFromText('POINT(2.076396 41.37873)',4326),ST_GeomFromText('POINT(2.1260679 41.37957)',4326),ST_GeomFromText('POINT(2.289589 41.606815)',4326),ST_GeomFromText('POINT(2.108391 41.547398)',4326),ST_GeomFromText('POINT(1.7509174 41.522194)',4326),ST_GeomFromText('POINT(2.1763213 41.385777)',4326),ST_GeomFromText('POINT(2.238362 41.45272)',4326),ST_GeomFromText('POINT(2.205175 41.408443)',4326),ST_GeomFromText('POINT(2.009889 41.57183)',4326),ST_GeomFromText('POINT(2.0244138 41.557167)',4326),ST_GeomFromText('POINT(2.22637 41.561535)',4326),ST_GeomFromText('POINT(2.2566855 41.930283)',4326),ST_GeomFromText('POINT(1.7567875 41.233097)',4326),ST_GeomFromText('POINT(2.1602619 41.42969)',4326),ST_GeomFromText('POINT(1.7700683 41.53431)',4326),ST_GeomFromText('POINT(2.03162 41.49191)',4326),ST_GeomFromText('POINT(2.192872 41.43037)',4326),ST_GeomFromText('POINT(2.1681633 41.39523)',4326),ST_GeomFromText('POINT(2.4401972 41.540558)',4326),ST_GeomFromText('POINT(1.9775051 41.28186)',4326),ST_GeomFromText('POINT(2.1657417 41.396236)',4326),ST_GeomFromText('POINT(2.1153424 41.533634)',4326),ST_GeomFromText('POINT(2.1345563 41.3797)',4326),ST_GeomFromText('POINT(2.435904 41.53745)',4326),ST_GeomFromText('POINT(2.176592 41.406162)',4326),ST_GeomFromText('POINT(1.8065257 41.23488)',4326),ST_GeomFromText('POINT(2.2529287 41.93208)',4326),ST_GeomFromText('POINT(2.4287484 41.535984)',4326),ST_GeomFromText('POINT(2.0866933 41.57029)',4326),ST_GeomFromText('POINT(1.6189902 41.580177)',4326),ST_GeomFromText('POINT(1.6384473 41.571526)',4326),ST_GeomFromText('POINT(2.172351 41.38475)',4326),ST_GeomFromText('POINT(2.121256 41.340267)',4326),ST_GeomFromText('POINT(2.085507 41.555305)',4326),ST_GeomFromText('POINT(2.188931 41.434994)',4326),ST_GeomFromText('POINT(2.093369 41.567547)',4326),ST_GeomFromText('POINT(2.286381 41.681458)',4326),ST_GeomFromText('POINT(2.247702 41.952023)',4326),ST_GeomFromText('POINT(2.1565368 41.40413)',4326),ST_GeomFromText('POINT(2.1508124 41.393314)',4326),ST_GeomFromText('POINT(2.212577 41.42288)',4326),ST_GeomFromText('POINT(2.2535474 41.92362)',4326),ST_GeomFromText('POINT(2.174553 41.401142)',4326),ST_GeomFromText('POINT(2.286412 41.68044)',4326),ST_GeomFromText('POINT(2.035615 41.557808)',4326),ST_GeomFromText('POINT(2.178693 41.421482)',4326),ST_GeomFromText('POINT(2.11166 41.536526)',4326),ST_GeomFromText('POINT(2.162958 41.390892)',4326),ST_GeomFromText('POINT(2.112093 41.337353)',4326),ST_GeomFromText('POINT(1.9768894 41.27896)',4326),ST_GeomFromText('POINT(2.1691065 41.403767)',4326),ST_GeomFromText('POINT(2.1812606 41.397297)',4326),ST_GeomFromText('POINT(2.188594 41.449318)',4326),ST_GeomFromText('POINT(2.1094196 41.548416)',4326),ST_GeomFromText('POINT(2.4432209 41.69423)',4326),ST_GeomFromText('POINT(2.690405 41.629364)',4326)] as g
),
b AS(
    SELECT
    ARRAY[1::bigint, 2::bigint, 3::bigint, 4::bigint, 5::bigint, 6::bigint, 7::bigint, 8::bigint] AS id,
    ARRAY[ST_GeomFromText('POINT(2.1744 41.403)',4326),ST_GeomFromText('POINT(2.1228 41.380)',4326),ST_GeomFromText('POINT(2.1511 41.374)',4326),ST_GeomFromText('POINT(2.1528 41.413)',4326),ST_GeomFromText('POINT(2.165 41.391)',4326),ST_GeomFromText('POINT(2.1498 41.371)',4326),ST_GeomFromText('POINT(2.1533 41.368)',4326),ST_GeomFromText('POINT(2.131386 41.41399)',4326)] AS g
)
SELECT
test.*
FROM
a0,
a,
b,
CDB_SalesForce(
    b.g,
    b.id,
    a.g,
    a0.id
) test;


