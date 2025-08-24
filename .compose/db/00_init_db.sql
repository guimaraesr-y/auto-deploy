CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD 'replicator_password';
GRANT pg_read_all_data TO replicator;
SELECT pg_create_physical_replication_slot('replication_slot');