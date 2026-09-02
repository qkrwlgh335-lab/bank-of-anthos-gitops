\set ON_ERROR_STOP on

SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'accounts_user', :'accounts_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'accounts_user')\gexec
SELECT format('ALTER ROLE %I LOGIN PASSWORD %L', :'accounts_user', :'accounts_password')\gexec

SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'ledger_user', :'ledger_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'ledger_user')\gexec
SELECT format('ALTER ROLE %I LOGIN PASSWORD %L', :'ledger_user', :'ledger_password')\gexec
