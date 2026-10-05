# Test cases for ../rules/python.yml. This file is insecure on purpose and is never run.
# "ruleid" marks a line the rule must report; "ok" marks a line it must leave alone.
import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()
internal = FastAPI()

# ruleid: quantum-python-secret-env-fallback
SECRET_KEY = os.getenv("SECRET_KEY", "changeme")
# ruleid: quantum-python-secret-env-fallback
DB_PASSWORD = os.environ.get("DB_PASSWORD", "dev")
# ok: quantum-python-secret-env-fallback
PORT = os.getenv("PORT", "8000")
# ok: quantum-python-secret-env-fallback
API_KEY = os.environ["API_KEY"]

# ruleid: quantum-fastapi-cors-allow-all
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_credentials=True)
# ok: quantum-fastapi-cors-allow-all
internal.add_middleware(CORSMiddleware, allow_origins=["https://app.example.com"], allow_credentials=True)
