"""
gen_cert.py — TDS Sentinel
Genera un certificado SSL auto-firmado usando la librería Python `cryptography`.
No depende del binario `openssl` — funciona en cualquier entorno.

Uso:
  python gen_cert.py                          → genera en .certs/ por defecto
  python gen_cert.py /ruta/cert.pem /ruta/key.pem
  python gen_cert.py --check /ruta/cert.pem  → verifica si sigue siendo válido
"""
from __future__ import annotations

import datetime
import ipaddress
import os
import sys

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID

# ── Defaults ─────────────────────────────────────────────────────────────────
SCRIPT_DIR  = os.path.dirname(os.path.abspath(__file__))
ROOT_DIR    = os.path.dirname(SCRIPT_DIR)
DEFAULT_DIR = os.path.join(ROOT_DIR, ".certs")
DEFAULT_CRT = os.path.join(DEFAULT_DIR, "sentinel_cert.pem")
DEFAULT_KEY = os.path.join(DEFAULT_DIR, "sentinel_key.pem")
VALID_DAYS  = 3650  # 10 años


def generate_cert(cert_path: str, key_path: str) -> None:
    """Genera un certificado RSA-2048 auto-firmado para localhost."""
    os.makedirs(os.path.dirname(cert_path), exist_ok=True)

    # ── Clave privada ────────────────────────────────────────────────────────
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)

    # ── Certificado ──────────────────────────────────────────────────────────
    subject = issuer = x509.Name([
        x509.NameAttribute(NameOID.COMMON_NAME, "localhost"),
        x509.NameAttribute(NameOID.ORGANIZATION_NAME, "TDS Sentinel (dev)"),
    ])

    now = datetime.datetime.now(datetime.timezone.utc)
    cert = (
        x509.CertificateBuilder()
        .subject_name(subject)
        .issuer_name(issuer)
        .public_key(key.public_key())
        .serial_number(x509.random_serial_number())
        .not_valid_before(now)
        .not_valid_after(now + datetime.timedelta(days=VALID_DAYS))
        .add_extension(
            x509.SubjectAlternativeName([
                x509.DNSName("localhost"),
                x509.IPAddress(ipaddress.IPv4Address("127.0.0.1")),
            ]),
            critical=False,
        )
        .sign(key, hashes.SHA256())
    )

    # ── Guardar ──────────────────────────────────────────────────────────────
    with open(key_path, "wb") as f:
        f.write(key.private_bytes(
            serialization.Encoding.PEM,
            serialization.PrivateFormat.TraditionalOpenSSL,
            serialization.NoEncryption(),
        ))
    os.chmod(key_path, 0o600)

    with open(cert_path, "wb") as f:
        f.write(cert.public_bytes(serialization.Encoding.PEM))

    print(f"[gen_cert] ✅  Certificado generado ({VALID_DAYS // 365} años)")
    print(f"[gen_cert]    CERT → {cert_path}")
    print(f"[gen_cert]    KEY  → {key_path}")


def check_cert(cert_path: str, min_days: int = 30) -> bool:
    """Devuelve True si el certificado existe y le quedan > min_days días."""
    if not os.path.isfile(cert_path):
        return False
    from cryptography.hazmat.primitives.serialization import load_pem_public_key  # noqa
    with open(cert_path, "rb") as f:
        cert = x509.load_pem_x509_certificate(f.read())
    now = datetime.datetime.now(datetime.timezone.utc)
    remaining = (cert.not_valid_after_utc - now).days
    if remaining < min_days:
        print(f"[gen_cert] ⚠️  Certificado caduca en {remaining} días — regenerando")
        return False
    print(f"[gen_cert] ✅  Certificado válido ({remaining} días restantes)")
    return True


if __name__ == "__main__":
    args = sys.argv[1:]

    # Modo --check: solo verifica
    if args and args[0] == "--check":
        path = args[1] if len(args) > 1 else DEFAULT_CRT
        ok = check_cert(path)
        sys.exit(0 if ok else 1)

    # Modo generación (con o sin rutas explícitas)
    cert_path = args[0] if len(args) > 0 else DEFAULT_CRT
    key_path  = args[1] if len(args) > 1 else DEFAULT_KEY

    # Si ya existe y es válido, no regenerar
    if check_cert(cert_path):
        print("[gen_cert] ℹ️   Cert vigente, no se regenera.")
        sys.exit(0)

    generate_cert(cert_path, key_path)
