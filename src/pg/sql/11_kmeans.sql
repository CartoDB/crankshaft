CREATE OR REPLACE FUNCTION  CDB_KMeans(query text, no_clusters integer,no_init integer default 20)
RETURNS table (cartodb_id integer, cluster_no integer) as $$
    
    import plpy 
    plpy.execute('SELECT cdb_crankshaft._cdb_crankshaft_activate_py()')
    from crankshaft.clustering import kmeans
    return kmeans(query,no_clusters,no_init)

$$ language plpythonu;

CREATE OR REPLACE FUNCTION CDB_WeightedMean(query text, weight_column text, category_column text default null )
RETURNS table (the_geom geometry,class integer ) as $$
BEGIN

RETURN QUERY
    EXECUTE format( $string$
        select ST_SETSRID(st_makepoint(cx, cy),4326) the_geom, class  from (
            select  
                   %I as class,
                   sum(st_x(the_geom)*%I)/sum(%I) cx,
                   sum(st_y(the_geom)*%I)/sum(%I) cy
                   from (%s) a
                   group by %I
            ) q          
     
        $string$, category_column, weight_column,weight_column,weight_column,weight_column,query, category_column 
    )
    using the_geom
    RETURN;
END 
$$ LANGUAGE plpgsql;
