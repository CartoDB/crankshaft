-- Function to obtain an estimate of the population living inside
-- an area (polygon) from the CartoDB Data Observatory
CREATE OR REPLACE FUNCTION cdb_population(area geometry)
RETURNS NUMERIC AS $$
DECLARE
  georef_column TEXT;
  table_id TEXT;
  tag_value TEXT;
  table_name TEXT;
  column_name TEXT;
  population NUMERIC;
BEGIN

  -- Note: comments contain pseudo-code that should be implemented

  -- Register metadata tables:
  /*
  SELECT cdb_add_remote_table('observatory', 'bmd_column_table');
  SELECT cdb_add_remote_table('observatory', 'bmd_column_2_column');
  SELECT cdb_add_remote_table('observatory', 'bmd_table');
  SELECT cdb_add_remote_table('observatory', 'bmd_column_table');
  SELECT cdb_add_remote_table('observatory', 'bmd_column_tag');
  SELECT cdb_add_remote_table('observatory', 'bmd_tag');
  */

  tag_value := 'population';


  -- Determine the georef column id to be used: it must have type 'geometry',
  -- the maximum weight.
  -- TODO: in general, multiple columns with maximal weight could be found;
  -- we should use the timespan of the table to disambiguate (choose the
  -- most recent). Also a rank of geometry columns should be introduced to
  -- find select the greatest resolution available.
  /*
  WITH selected_tables AS (
    -- Find tables that have population columns and cover the input area
    SELECT tab.id AS id
    FROM observatory.bmd_column col,
         observatory.bmd_column_table coltab,
         observatory.bmd_table tab,
         observatory.bmd_tag tag,
         observatory.bmd_column_tag coltag
    WHERE coltab.column_id = col.id
      AND coltab.table_id = tab.id
      AND coltag.tag_id = tag.id
      AND coltag.column_id = col.id
      AND tag.name ILIKE tag_value
      AND tab.id = table_id
      AND tab.bounds && area;
  )
  SELECT
    FROM bmd_column col
    JOIN bmd_table tab ON col.table_id = tab.id
    WHERE type = 'geometry'
      AND tab.id IN (selected_tables)
    ORDER BY weight DESC LIMIT 1;
  */
  georef_column := '"us.census.tiger".block_group_2013';

  -- Now we will query the metadata to find which actual tables correspond
  -- to this datasource and resolution/timespan
  -- and choose the 'parent' or more general of them.
  /*
  SELECT from_table_geoid.id data_table_id
  FROM observatory.bmd_column_table from_column_table_geoid,
       observatory.bmd_column_table to_column_table_geoid,
       observatory.bmd_column_2_column rel,
       observatory.bmd_column_table to_column_table_geom,
       observatory.bmd_table from_table_geoid,
       observatory.bmd_table to_table_geoid,
       observatory.bmd_table to_table_geom
  WHERE from_column_table_geoid.column_id = to_column_table_geoid.column_id
    AND to_column_table_geoid.column_id = rel.from_id
    AND rel.reltype = 'geom_ref'
    AND rel.to_id = to_column_table_geom.column_id
    AND to_column_table_geom.column_id = georef_column
    AND from_table_geoid.id = from_column_table_geoid.table_id
    AND to_table_geoid.id = to_column_table_geoid.table_id
    AND to_table_geom.id = to_column_table_geom.table_id
    AND from_table_geoid.bounds && area
  ORDER by from_table_geoid.timespan desc
  INTO table_id;
  */
  table_id := '"us.census.acs".extract_2013_5yr_block_group';

  -- Next will fetch the columns of that table that are tagged as population:
  -- and get the more general one (not having a parent or denominator)
  /*
  WITH column_ids AS (
    SELECT col.id AS id
    FROM observatory.bmd_column col,
         observatory.bmd_column_table coltab,
         observatory.bmd_table tab,
         observatory.bmd_tag tag,
         observatory.bmd_column_tag coltag
    WHERE coltab.column_id = col.id
      AND coltab.table_id = tab.id
      AND coltag.tag_id = tag.id
      AND coltag.column_id = col.id
      AND tag.name ILIKE tag_value
      AND tab.id = table_id;
  ),
  excluded_column_ids AS (
    SELECT from_id AS id
    FROM observatory.bmd_column_2_column
    WHERE from_id in (column_ids)
      AND reltype in ('parent', 'denominator')
      AND to_id in (column_ids)
  ),
  SELECT bmd_table.tablename, bmd_column_table.colname
  FROM observatory.bmd_column_table,
       observatory.bmd_table
  WHERE bmd_column_table.table_id = bmd_table.id
    AND bmd_column_table.column_id IN (column_ids)
    AND NOT bmd_column_table.column_id IN (exclude_column_ids)
  INTO (table_name, column_name);
  */
  table_name := 'us_census_acs2013_5yr_block_group';
  column_name := 'total_pop';

  -- Register the foreign table
  SELECT cdb_add_remote_table('observatory', table_name);

  -- Perform the query
  SELECT cdb_crankshaft.cdb_overlap_sum(
    area,
    table_name,
    table_column,
    schema_name := 'observatory')
  INTO population;

  RETURN population;
END;
$$
LANGUAGE plpgsql VOLATILE
