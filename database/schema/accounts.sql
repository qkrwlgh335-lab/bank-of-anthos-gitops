/*
 * Bank of Anthos accounts schema.
 * Source: googlecloudplatform/bank-of-anthos
 * src/accounts/accounts-db/initdb/0-accounts-schema.sql
 */

CREATE TABLE IF NOT EXISTS users (
  accountid CHAR(10) PRIMARY KEY,
  username VARCHAR(64) UNIQUE NOT NULL,
  passhash BYTEA NOT NULL,
  firstname VARCHAR(64) NOT NULL,
  lastname VARCHAR(64) NOT NULL,
  birthday DATE NOT NULL,
  timezone VARCHAR(8) NOT NULL,
  address VARCHAR(64) NOT NULL,
  state CHAR(2) NOT NULL,
  zip VARCHAR(5) NOT NULL,
  ssn CHAR(11) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_users_accountid ON users (accountid);
CREATE INDEX IF NOT EXISTS idx_users_username ON users (username);

CREATE TABLE IF NOT EXISTS contacts (
  username VARCHAR(64) NOT NULL,
  label VARCHAR(128) NOT NULL,
  account_num CHAR(10) NOT NULL,
  routing_num CHAR(9) NOT NULL,
  is_external BOOLEAN NOT NULL,
  FOREIGN KEY (username) REFERENCES users(username)
);

CREATE INDEX IF NOT EXISTS idx_contacts_username ON contacts (username);
