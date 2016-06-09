
- [ ] All declared geometries are `geometry(Geometry, 4326)` for general geoms, or `geometry(Point, 4326)`
- [ ] Include python is activated for new functions. Include this before importing modules: `plpy.execute('SELECT cdb_crankshaft._cdb_crankshaft_activate_py()')`
- [ ] Docs for public-facing functions are written
- [ ] New functions follow the naming conventions: `CDB_NameOfFunction`. Where internal functions begin with an underscore `_`.
- [ ] If appropriate, new functions accepts an arbitrary query as an input (see [Crankshaft Issue #6](https://github.com/CartoDB/crankshaft/issues/6) for more information)
 
