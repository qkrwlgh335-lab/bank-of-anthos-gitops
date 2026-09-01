#!/usr/bin/env python3
"""Create least-privilege RDS app users and publish runtime secrets without printing them."""

from __future__ import annotations

import json
import secrets
import subprocess
import tempfile
from pathlib import Path
from urllib.parse import quote

import psycopg
from psycopg import sql


REGION = "ap-northeast-2"
DB_INSTANCE = "phase1-dms-poc-source"
RUNTIME_SECRET = "phase1/bank-app/runtime"
JWT_SECRET = "phase1/bank-app/jwt"
OPENSSL = Path(r"C:\Program Files\Git\mingw64\bin\openssl.exe")


def aws_json(*args: str) -> object:
    result = subprocess.run(
        ["aws", *args, "--region", REGION, "--output", "json"],
        check=True,
        text=True,
        capture_output=True,
    )
    return json.loads(result.stdout)


def put_secret(secret_id: str, value: dict[str, str]) -> None:
    with tempfile.TemporaryDirectory() as directory:
        path = Path(directory) / "secret.json"
        path.write_text(json.dumps(value), encoding="utf-8")
        subprocess.run(
            [
                "aws",
                "secretsmanager",
                "put-secret-value",
                "--region",
                REGION,
                "--secret-id",
                secret_id,
                "--secret-string",
                f"file://{path}",
                "--output",
                "json",
            ],
            check=True,
            stdout=subprocess.DEVNULL,
        )


def connect(host: str, database: str, user: str, password: str) -> psycopg.Connection:
    return psycopg.connect(
        host=host,
        port=5432,
        dbname=database,
        user=user,
        password=password,
        sslmode="require",
        autocommit=True,
        connect_timeout=15,
    )


def ensure_role(
    host: str,
    master_user: str,
    master_password: str,
    database: str,
    role: str,
    password: str,
) -> None:
    with connect(host, "postgres", master_user, master_password) as connection:
        exists = connection.execute(
            "SELECT 1 FROM pg_roles WHERE rolname = %s", (role,)
        ).fetchone()
        statement = "ALTER ROLE {} LOGIN PASSWORD {}" if exists else "CREATE ROLE {} LOGIN PASSWORD {}"
        connection.execute(
            sql.SQL(statement).format(sql.Identifier(role), sql.Literal(password))
        )
        connection.execute(
            sql.SQL("GRANT CONNECT ON DATABASE {} TO {}").format(
                sql.Identifier(database), sql.Identifier(role)
            )
        )

    with connect(host, database, master_user, master_password) as connection:
        connection.execute(
            sql.SQL("GRANT USAGE ON SCHEMA public TO {}").format(sql.Identifier(role))
        )
        connection.execute(
            sql.SQL(
                "GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO {}"
            ).format(sql.Identifier(role))
        )
        connection.execute(
            sql.SQL("GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO {}").format(
                sql.Identifier(role)
            )
        )
        connection.execute(
            sql.SQL(
                "ALTER DEFAULT PRIVILEGES IN SCHEMA public "
                "GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO {}"
            ).format(sql.Identifier(role))
        )
        connection.execute(
            sql.SQL(
                "ALTER DEFAULT PRIVILEGES IN SCHEMA public "
                "GRANT USAGE, SELECT ON SEQUENCES TO {}"
            ).format(sql.Identifier(role))
        )


def generate_rsa_pair() -> tuple[str, str]:
    if not OPENSSL.exists():
        raise SystemExit(f"OpenSSL not found: {OPENSSL}")
    with tempfile.TemporaryDirectory() as directory:
        private_path = Path(directory) / "jwtRS256.key"
        public_path = Path(directory) / "jwtRS256.key.pub"
        subprocess.run(
            [str(OPENSSL), "genpkey", "-algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:2048", "-out", str(private_path)],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        subprocess.run(
            [str(OPENSSL), "pkey", "-in", str(private_path), "-pubout", "-out", str(public_path)],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        return (
            private_path.read_text(encoding="utf-8"),
            public_path.read_text(encoding="utf-8"),
        )


def main() -> None:
    instance = aws_json("rds", "describe-db-instances", "--db-instance-identifier", DB_INSTANCE)
    db = instance["DBInstances"][0]  # type: ignore[index]
    host = db["Endpoint"]["Address"]
    master_user = db["MasterUsername"]
    master_secret_arn = db["MasterUserSecret"]["SecretArn"]

    master = aws_json("secretsmanager", "get-secret-value", "--secret-id", master_secret_arn)
    master_password = json.loads(master["SecretString"])["password"]  # type: ignore[index]

    accounts_password = secrets.token_urlsafe(32)
    ledger_password = secrets.token_urlsafe(32)
    ensure_role(host, master_user, master_password, "accounts", "accounts_app", accounts_password)
    ensure_role(host, master_user, master_password, "ledger", "ledger_app", ledger_password)

    with connect(host, "accounts", "accounts_app", accounts_password) as connection:
        connection.execute("SELECT 1 FROM users LIMIT 1").fetchone()
    with connect(host, "ledger", "ledger_app", ledger_password) as connection:
        connection.execute("SELECT 1 FROM transactions LIMIT 1").fetchone()

    put_secret(
        RUNTIME_SECRET,
        {
            "ACCOUNTS_DB_URI": (
                f"postgresql://accounts_app:{quote(accounts_password, safe='')}"
                f"@{host}:5432/accounts?sslmode=require"
            ),
            "SPRING_DATASOURCE_URL": f"jdbc:postgresql://{host}:5432/ledger?sslmode=require",
            "SPRING_DATASOURCE_USERNAME": "ledger_app",
            "SPRING_DATASOURCE_PASSWORD": ledger_password,
            "REDIS_URL": "redis://redis:6379/0",
        },
    )

    private_key, public_key = generate_rsa_pair()
    put_secret(
        JWT_SECRET,
        {"jwtRS256.key": private_key, "jwtRS256.key.pub": public_key},
    )
    print("APP_RUNTIME_READY accounts_app=verified ledger_app=verified secrets=2")


if __name__ == "__main__":
    main()
