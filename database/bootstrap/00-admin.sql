\set ON_ERROR_STOP on

SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'accounts_user', :'accounts_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'accounts_user')\gexec
SELECT format('ALTER ROLE %I LOGIN PASSWORD %L', :'accounts_user', :'accounts_password')\gexec

SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'ledger_user', :'ledger_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'ledger_user')\gexec
SELECT format('ALTER ROLE %I LOGIN PASSWORD %L', :'ledger_user', :'ledger_password')\gexec

SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'dms_user', :'dms_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'dms_user')\gexec
SELECT format('ALTER ROLE %I LOGIN PASSWORD %L', :'dms_user', :'dms_password')\gexec

SELECT format('CREATE DATABASE %I OWNER %I', :'accounts_db', :'accounts_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'accounts_db')\gexec
SELECT format('ALTER DATABASE %I OWNER TO %I', :'accounts_db', :'accounts_user')\gexec

SELECT format('CREATE DATABASE %I OWNER %I', :'ledger_db', :'ledger_user')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'ledger_db')\gexec
SELECT format('ALTER DATABASE %I OWNER TO %I', :'ledger_db', :'ledger_user')\gexec

SELECT format('GRANT CONNECT ON DATABASE %I TO %I', :'accounts_db', :'dms_user')\gexec
SELECT format('GRANT CONNECT ON DATABASE %I TO %I', :'ledger_db', :'dms_user')\gexec
SELECT format('GRANT %I TO %I', 'rds_replication', :'dms_user')\gexec
