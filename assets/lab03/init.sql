CREATE TABLE IF NOT EXISTS students (
    id   SERIAL PRIMARY KEY,
    name TEXT NOT NULL
);
INSERT INTO students (name) VALUES ('sample-1'), ('sample-2');
