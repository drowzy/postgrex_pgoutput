ALTER SYSTEM SET wal_level=logical;
ALTER SYSTEM SET max_wal_senders='16';
ALTER SYSTEM SET max_replication_slots='10';
--
CREATE TABLE IF NOT EXISTS articles (
    id serial PRIMARY KEY,
    title text,
    description text,
    body text
);
--
CREATE PUBLICATION articles_pub FOR TABLE articles;
