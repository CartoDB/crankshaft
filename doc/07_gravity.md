## Gravity Model

Gravity Models are derived from Newton's Law of Gravity and are used to predict the interaction between a group of populated areas (sources) and a specific target among a group of potential targets, in terms of an attraction factor (weight)

**CDB_Gravity** is based on the model defined in *Huff's Law of Shopper attraction (1963)*

### CDB_Gravity(t_id bigint[], t_geom geometry[], t_weight numeric[], s_id bigint[], s_geom geometry[], s_pop numeric[], target bigint, radius integer, minval numeric DEFAULT -10e307)

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| t_id     | bigint[]    | Array of targets ID |
| t_geom   | geometry[]  | Array of targets' geometries |
| t_weight | numeric[]   | Array of targets's weights |
| s_id     | bigint[]    | Array of sources ID |
| s_geom   | geometry[]  | Array of sources' geometries |
| s_pop    | numeric[]   | Array of sources's population |
| target   | bigint      | ID of the target under study |
| radius   | integer     | Radius in meters around the target under study that will be taken into account|
| minval (optional)   | numeric     | Lowest accepted value of weight, defaults to numeric min_value |

### CDB_Gravity( target_query text, weight_column text, source_query text, pop_column text, target bigint, radius integer, minval numeric DEFAULT -10e307)

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| target_query     | text    | Query that defines targets |
| weight_column   | text  | Column name of weights |
| source_query     | text    | Query that defines sources |
| pop_column   | text  | Column name of population |
| target   | bigint      | cartodb_id of the target under study |
| radius   | integer     | Radius in meters around the target under study that will be taken into account|
| minval (optional)   | numeric     | Lowest accepted value of weight, defaults to numeric min_value |


### Returns

| Column Name | Type | Description |
|-------------|------|-------------|
| the_geom  | geometry | Geometries of the sources within the radius |
| source_id | bigint  | ID of the source |
| target_id | bigint  | Target ID from input |
| dist      | numeric | Distance in meters source to target (if not points, distance between centroids) |
| h         | numeric | Probability of patronage |
| hpop      | numeric | Patronaging population |


#### Example Usage

```sql
with t as (
SELECT
    array_agg(cartodb_id::bigint) as id,
    array_agg(the_geom) as g,
    array_agg(coalesce(gla, 0)::numeric) as w
FROM
    centros_comerciales_de_madrid
WHERE not no_cc
),
s as (
SELECT
    array_agg(cartodb_id::bigint) as id,
    array_agg(center) as g,
    array_agg(coalesce(t1_1, 0)::numeric) as p
FROM
    sscc_madrid
)
SELECT
    g.the_geom,
    trunc(g.h, 2) as h,
    round(g.hpop) as hpop,
    trunc(g.dist/1000, 2) as dist_km
FROM
    t,
    s,
    cdb_crankshaft.CDB_Gravity(t.id, t.g, t.w, s.id, s.g, s.p, newmall_ID, 100000, 5000) as g
```


