## PyAgg Helper Function 

### CDB_pyAgg (columns Numeric[])

Currently it's not possible to pass a multidiemensional array between plpsql and plpythonu. This function aims to
help fix that by aggergating the columns provided in the argument across rows in to a rows * columns + 1 length 1D array. The first element of the array is the array\_length of the columns argument so that python can reconstruct 
the 2D array. 

#### Arguments

| Name | Type | Description |
|------|------|-------------|
| columns | NUMERIC[] | The columns to aggregate across rows|

#### Returns

A table with the following columns.

| Column Name | Type | Description |
|-------------|------|-------------|
| result | NUMERIC[] | An columns * rows + 1 array where the first entry is the no of columns|


