from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from cryptography.fernet import Fernet
from pydantic import BaseModel, EmailStr, field_validator
import redis, json, uuid, os, re, logging, base64

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
log = logging.getLogger(__name__)

app = FastAPI(title="Velox Provisioning API")

r = redis.from_url(os.getenv("REDIS_URL", "redis://redis:6379"), decode_responses=True)

# ── Encryption (Fernet symmetric) ────────────────────────────────────
_raw_key = os.getenv("REDIS_ENCRYPT_KEY", "")
if _raw_key:
    _fernet = Fernet(_raw_key.encode())
else:
    # Generate ephemeral key at startup (jobs survive only while container runs)
    log.warning("REDIS_ENCRYPT_KEY not set — using ephemeral key; set it for persistence")
    _fernet = Fernet(Fernet.generate_key())


def encrypt_payload(data: dict) -> str:
    return _fernet.encrypt(json.dumps(data).encode()).decode()


def decrypt_payload(token: str) -> dict:
    return json.loads(_fernet.decrypt(token.encode()))


app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://devopserver.ddns.net",
        "http://devopserver.ddns.net",
        "http://localhost",
        "http://localhost:8000",
    ],
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
)


@app.middleware("http")
async def log_requests(request: Request, call_next):
    response = await call_next(request)
    log.info("%s %s %s", request.method, request.url.path, response.status_code)
    return response
# ── Request / Response models ────────────────────────────────────────

class ProvisionRequest(BaseModel):
    # Landing zone parameters
    company:        str
    environment:    str
    region:         str = "westeurope"
    email:          str
    monthly_budget: int = 1000

    # Azure Service Principal – collected per-job, never stored in .env
    arm_client_id:       str
    arm_client_secret:   str
    arm_tenant_id:       str
    arm_subscription_id: str

    # Optional: Terraform remote-state storage (defaults to env vars)
    tfstate_storage_account: str = ""
    tfstate_resource_group:  str = ""
    tfstate_container:       str = "tfstate"

    # Optional feature flags
    enable_firewall:     bool = True
    enable_vpn_gateway:  bool = False
    enable_bastion:      bool = True

    @field_validator("company")
    @classmethod
    def slugify_company(cls, v: str) -> str:
        slug = re.sub(r"[^a-z0-9\-]", "-", v.strip().lower())
        slug = re.sub(r"-+", "-", slug).strip("-")
        if not slug:
            raise ValueError("company name must contain at least one alphanumeric character")
        return slug

    @field_validator("environment")
    @classmethod
    def validate_env(cls, v: str) -> str:
        v = v.strip().lower()
        allowed = {"prod", "dev", "staging", "test", "uat"}
        if v not in allowed:
            raise ValueError(f"environment must be one of: {', '.join(sorted(allowed))}")
        return v

    @field_validator("arm_client_id", "arm_tenant_id", "arm_subscription_id")
    @classmethod
    def validate_guid(cls, v: str) -> str:
        v = v.strip()
        guid_re = re.compile(
            r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
            re.IGNORECASE,
        )
        if not guid_re.match(v):
            raise ValueError("must be a valid UUID / GUID")
        return v


class ProvisionResponse(BaseModel):
    job_id: str
    status: str


# ── Endpoints ────────────────────────────────────────────────────────

@app.get("/health")
def health():
    try:
        r.ping()
        return {"status": "ok", "redis": "connected"}
    except Exception as e:
        return {"status": "degraded", "redis": str(e)}


@app.post("/provision", response_model=ProvisionResponse)
def provision(req: ProvisionRequest):
    job_id = str(uuid.uuid4())

    payload = {
        # Identity
        "job_id":      job_id,
        "status":      "queued",
        "output":      "",
        "steps":       [],

        # LZ params
        "company":          req.company,
        "environment":      req.environment,
        "region":           req.region,
        "email":            req.email,
        "monthly_budget":   req.monthly_budget,

        # Feature flags
        "enable_firewall":     req.enable_firewall,
        "enable_vpn_gateway":  req.enable_vpn_gateway,
        "enable_bastion":      req.enable_bastion,

        # Azure SP – passed to worker, used only at runtime
        "arm_client_id":       req.arm_client_id,
        "arm_client_secret":   req.arm_client_secret,   # stored transiently in Redis
        "arm_tenant_id":       req.arm_tenant_id,
        "arm_subscription_id": req.arm_subscription_id,

        # Remote state config
        "tfstate_storage_account": req.tfstate_storage_account
            or os.getenv("TFSTATE_STORAGE_ACCOUNT", "veloxtfstate"),
        "tfstate_resource_group": req.tfstate_resource_group
            or os.getenv("TFSTATE_RESOURCE_GROUP", "rg-velox-tfstate"),
        "tfstate_container": req.tfstate_container,
    }

    # Persist job state (TTL 24 h – credentials auto-expire, encrypted at rest)
    r.setex(f"job:{job_id}", 86400, encrypt_payload(payload))
    # Push to worker queue (encrypted)
    r.rpush("provision_queue", encrypt_payload(payload))

    return ProvisionResponse(job_id=job_id, status="queued")


@app.get("/status/{job_id}")
def status(job_id: str):
    raw = r.get(f"job:{job_id}")
    if not raw:
        raise HTTPException(status_code=404, detail="Job not found")
    job = decrypt_payload(raw)
    # Strip secrets before returning to client
    return _sanitize(job)


@app.get("/jobs")
def list_jobs():
    keys = r.keys("job:*")
    jobs = []
    for k in keys:
        raw = r.get(k)
        if raw:
            jobs.append(_sanitize(decrypt_payload(raw)))
    jobs.sort(key=lambda x: x.get("job_id", ""), reverse=True)
    return jobs


# ── Helpers ──────────────────────────────────────────────────────────

_SECRET_FIELDS = {"arm_client_secret"}

def _sanitize(job: dict) -> dict:
    """Remove sensitive fields before sending to client."""
    return {k: v for k, v in job.items() if k not in _SECRET_FIELDS}
