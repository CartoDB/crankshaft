## Gravity Model 

### CDB_Gravity()

The Gravity Model is derived from newtons law of gravity and is used to estimate the degree of interaction between two places 

#### Arguments 

| Name | Type | Description | 
|------|------|-------------|
| t_id     | bigint[]    |     |
| t_geom   | geometry[]  |     |
| t_weight | numeric[]   |     |
| s_id     | bigint[]    |     |
| s_geom   | geometry[]  |     |
| s_pop    | numeric[]   |     |
| target   | bigint      |     |
| radius   | integer     |     |
| minval   | numeric     |     |


#### Returns 

| Column Name | Type | Description |
|-------------|------|-------------|
| the_geom  | Numeric | |
| source_id | bigint  | |
| target_id | bigint  | |
| dist      | Numeric | |
| n         | Numeric | |
| hpop      | NUMERIC | |


#### Example Usage

```sql
SELECT CDB_GRAVITY ();
```


