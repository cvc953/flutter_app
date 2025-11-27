import sqlite3, json, os

DB='backend.db'
if not os.path.exists(DB):
    print('DB not found', DB)
else:
    conn=sqlite3.connect(DB)
    rows=conn.execute('SELECT id,course_id,student_id FROM course_students').fetchall()
    print(rows)
    conn.close()
