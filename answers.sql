
-- =========================================================
-- Assignment: PostgreSQL Backup, PITR, and Streaming Replication
-- File: answers.sql
-- =========================================================


-- STEP 1: VERIFY THE LOGICAL BACKUP
-- Note: pg_dump and pg_restore are shell commands, not SQL.
-- Run them in the Linux terminal.

-- Create a logical backup:
-- pg_dump -Fc -f ~/backups/bootcamp.dump bootcamp

-- Verify the backup:
-- pg_restore --list ~/backups/bootcamp.dump

-- Restore into a test database:
-- createdb bootcamp_check
-- pg_restore -d bootcamp_check ~/backups/bootcamp.dump


-- STEP 2: CONFIGURE WAL ARCHIVING
-- These settings belong in postgresql.conf, not answers.sql.
--
-- wal_level = replica
-- archive_mode = on
-- archive_command = 'cp %p /absolute/path/to/backups/wal/%f'
--
-- Create a physical base backup from the terminal:
-- pg_basebackup -D ~/backups/base -Ft -z -Xs -P


-- STEP 3: SIMULATE DATA LOSS AND VERIFY RECOVERY
-- WARNING: Run DELETE only in a disposable test database.
-- Record the recovery target time before deleting data.

-- Record the current time:
SELECT clock_timestamp() AS recovery_reference_time;

-- Simulate accidental deletion only when ready:
-- DELETE FROM students;

-- After completing PITR, verify the recovered records:
SELECT COUNT(*) AS recovered_student_count
FROM students;


-- STEP 4: CREATE A STREAMING REPLICATION ROLE
-- Run on the primary PostgreSQL server.
-- Replace the password with a strong, unique password.

CREATE ROLE replicator
WITH REPLICATION LOGIN PASSWORD 'replace_with_a_strong_password';


-- STEP 5: CHECK STREAMING REPLICATION HEALTH
-- Run on the primary PostgreSQL server.

SELECT
    application_name,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
FROM pg_stat_replication;
