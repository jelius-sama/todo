CREATE TABLE todo (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    title         TEXT NOT NULL,
    description   TEXT,
    completed     INTEGER NOT NULL DEFAULT 0 CHECK (completed IN (0, 1)),
    priority      INTEGER NOT NULL DEFAULT 0,
    created_at    INTEGER NOT NULL,
    updated_at    INTEGER NOT NULL
);

CREATE TABLE tag (
    id   INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL UNIQUE
);

CREATE TABLE todo_tag (
    todo_id INTEGER NOT NULL,
    tag_id  INTEGER NOT NULL,
    PRIMARY KEY (todo_id, tag_id),
    FOREIGN KEY (todo_id) REFERENCES todo(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id)  REFERENCES tag(id)  ON DELETE CASCADE
);

CREATE INDEX idx_todo_completed ON todo(completed);
CREATE INDEX idx_todo_updated_at ON todo(updated_at);
