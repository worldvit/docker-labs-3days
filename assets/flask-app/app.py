import os, socket
from flask import Flask
import psycopg2

app = Flask(__name__)

def db_conn():
    return psycopg2.connect(
        host=os.getenv("DB_HOST", "db"),
        dbname=os.getenv("DB_NAME", "labdb"),
        user=os.getenv("DB_USER", "lab"),
        password=os.getenv("DB_PASSWORD", "labpass"),
        connect_timeout=3,
    )

@app.route("/")
def index():
    return f"served-by: {socket.gethostname()}\n"

@app.route("/health")
def health():
    return "ok\n", 200

@app.route("/db")
def db():
    try:
        with db_conn() as c, c.cursor() as cur:
            cur.execute("SELECT count(*) FROM students")
            return f"students: {cur.fetchone()[0]}\n"
    except Exception as e:
        return f"db error: {e}\n", 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
