import plpy

def xyz():
    plpy.notice('XYZ...')
    r = plpy.execute("select * from pg_class where relname='pg_class'")
    return r[0]['reltype']
