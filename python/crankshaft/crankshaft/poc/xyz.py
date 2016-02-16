import plpy

def xyz():
    plpy.notice('XYZ...')
    r = plpy.execute("SELECT * FROM table")
    return r[0]['x']
