\set ON_ERROR_STOP on

CREATE TABLE IF NOT EXISTS dr_cdc_probe (
  id BIGINT PRIMARY KEY,
  payload VARCHAR(128) NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO dr_cdc_probe (id, payload)
VALUES (1, 'initial-full-dump-row')
ON CONFLICT (id) DO UPDATE
SET payload = EXCLUDED.payload,
    updated_at = CURRENT_TIMESTAMP;
