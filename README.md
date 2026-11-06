# PostgreSQL Backup, Point-in-Time Recovery (PITR), and Streaming Replication

## Project Overview

This project demonstrates PostgreSQL database backup, recovery, and replication techniques. It covers creating a logical backup, configuring Write-Ahead Log (WAL) archiving, recovering a database to a specific point in time, and setting up a streaming standby replica.

The objective is to understand how database administrators protect data, recover from accidental data loss, and maintain database availability.

## Objectives

- Create and verify a logical database backup.
- Configure WAL archiving and create a physical base backup.
- Perform point-in-time recovery after simulated data loss.
- Configure streaming replication using a standby server.
- Monitor replication status and estimate replication lag.

## Technologies Used

- **Database:** PostgreSQL
- **Command-line tools:** `pg_dump`, `pg_restore`, `pg_basebackup`, `createdb`, and `psql`
- **Operating system:** Linux
- **Configuration files:** `postgresql.conf` and `pg_hba.conf`

## Project Structure

```text
postgresql-backup-recovery/
├── README.md
└── backups/
    ├── bootcamp.dump
    ├── base/
    └── wal/
```

*Note: The backup files and directories are created when the lab commands are executed. They do not need to be committed to GitHub.*

## Step 1: Create and Verify a Logical Backup

Create a directory for backups:

```bash
mkdir -p ~/backups
```

Back up the `bootcamp` database using PostgreSQL's custom archive format:

```bash
pg_dump -Fc -f ~/backups/bootcamp.dump bootcamp
```

List the contents of the backup:

```bash
pg_restore --list ~/backups/bootcamp.dump | head
```

Create a temporary database and restore the backup into it:

```bash
createdb bootcamp_check
pg_restore -d bootcamp_check ~/backups/bootcamp.dump
```

**Expected outcome:** The backup archive is created, its contents can be listed, and the database can be restored into the test database.

## Step 2: Enable WAL Archiving

WAL archiving preserves transaction log files needed for point-in-time recovery.

Update `postgresql.conf` with settings similar to the following:

```conf
wal_level = replica
archive_mode = on
archive_command = 'test ! -f /home/your_user/backups/wal/%f && cp %p /home/your_user/backups/wal/%f'
```

Replace `/home/your_user` with the correct absolute path for your Linux account. Ensure the PostgreSQL service account can write to the archive directory.

Create the directory:

```bash
mkdir -p ~/backups/wal
```

Restart PostgreSQL after changing the configuration:

```bash
sudo systemctl restart postgresql
```

Create a physical base backup:

```bash
pg_basebackup -D ~/backups/base -Ft -z -Xs -P
```

**Expected outcome:** PostgreSQL is configured for WAL archiving, and a compressed physical base backup is created.

## Step 3: Simulate a Disaster and Perform PITR

Record a recovery target time before simulating the data loss:

```sql
SELECT clock_timestamp();
```

Record the returned timestamp. Then, in a test environment, simulate accidental deletion:

```sql
DELETE FROM students;
```

### Recovery procedure

1. Stop PostgreSQL.
2. Preserve the existing data directory before making changes.
3. Restore the base backup into a suitable data directory.
4. Configure recovery settings for the PostgreSQL version in use.
5. Make the archived WAL files available.
6. Start PostgreSQL and allow it to recover to the selected target.
7. Verify the recovered data.

For PostgreSQL 12 and later, recovery settings are typically configured in `postgresql.conf`, and a `recovery.signal` file is required to initiate archive recovery.

Example recovery settings:

```conf
restore_command = 'cp /home/your_user/backups/wal/%f %p'
recovery_target_time = 'YYYY-MM-DD HH:MM:SS'
recovery_target_action = 'pause'
```

Replace the example timestamp with the recorded recovery target and use the actual archive path. Create an empty `recovery.signal` file in the restored data directory before starting PostgreSQL.

Verify the recovered data:

```sql
SELECT COUNT(*) FROM students;
```

**Expected outcome:** PostgreSQL replays the available WAL records and stops at the configured recovery target.

**Important:** PITR requires a valid base backup and a continuous, usable WAL archive covering the target time. A timestamp recorded after a destructive operation may be too late to recover the deleted rows. Practice this procedure on a disposable database, not a production server.

## Step 4: Configure Streaming Replication

Streaming replication maintains a standby server that receives and replays WAL records from the primary server.

### Create a replication role

Run on the primary PostgreSQL server:

```sql
CREATE ROLE replicator
WITH REPLICATION LOGIN PASSWORD 'replace_with_a_strong_password';
```

Use a strong password and avoid committing credentials to GitHub.

### Configure client authentication

Add an appropriate entry to `pg_hba.conf` on the primary server:

```conf
host replication replicator 127.0.0.1/32 scram-sha-256
```

Reload PostgreSQL's configuration:

```sql
SELECT pg_reload_conf();
```

Ensure the primary server is listening on the required interface and that the replication connection is permitted.

### Create the standby

On the machine that will host the standby, run:

```bash
pg_basebackup -h 127.0.0.1 -U replicator -D ~/standby -R -P
```

Supply the replication password when prompted. If the standby is on another machine, replace `127.0.0.1` with the primary server's reachable address.

The `-R` option creates the standby configuration needed to connect to the primary.

**Expected outcome:** The standby data directory is initialized from the primary, and the configuration for streaming replication is created.

## Step 5: Monitor Replication Health

On the primary server, inspect connected standbys:

```sql
SELECT
    application_name,
    state,
    sent_lsn,
    write_lsn,
    flush_lsn,
    replay_lsn,
    pg_wal_lsn_diff(sent_lsn, replay_lsn) AS lag_bytes
FROM pg_stat_replication;
```

The query shows the standby's connection state and the difference between the WAL sent and replayed positions.

**Important:** `lag_bytes` is an estimate of the difference between those WAL positions, not a direct measurement of replication delay in seconds. No rows may indicate that no standby is currently connected.

## Safety and Best Practices

- Verify backups by restoring them into a separate test database.
- Store backups and WAL archives on reliable storage with appropriate permissions.
- Test recovery procedures before relying on them during a real incident.
- Use strong credentials and restrict replication access to trusted hosts.
- Monitor archive failures, standby connectivity, and replication lag.
- Keep production data and credentials out of public repositories.
- Confirm PostgreSQL version-specific recovery requirements before replacing a data directory.

## Conclusion

This lab demonstrates three important PostgreSQL disaster-recovery techniques: logical backups, point-in-time recovery using WAL archives, and streaming replication. Together, these techniques help protect against accidental data deletion, support disaster recovery, and improve database availability.

## Author

**Name:** [Your Name]
