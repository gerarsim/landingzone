from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, field_validator, model_validator
import redis, json, uuid, os, re, logging, time

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
log = logging.getLogger(__name__)

app = FastAPI(title="LZForge Provisioning API")

r = redis.from_url(os.getenv("REDIS_URL", "redis://redis:6379"), decode_responses=True)

# ── Encryption — key auto-managed in Redis, no manual config needed ───
def _get_fernet():
    from cryptography.fernet import Fernet
    for attempt in range(10):
        try:
            key = r.get("_encrypt_key")
            if key:
                return Fernet(key.encode())
            new_key = Fernet.generate_key().decode()
            if r.setnx("_encrypt_key", new_key):
                log.info("Encryption key created and stored in Redis")
                return Fernet(new_key.encode())
            key = r.get("_encrypt_key")
            return Fernet(key.encode())
        except Exception:
            time.sleep(1)
    raise RuntimeError("Cannot connect to Redis to retrieve encryption key")

_fernet = _get_fernet()


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
    # ── Cloud provider ────────────────────────────────────────────────
    cloud_provider: str = "azure"   # "azure" | "aws" | "gcp"

    # ── Landing zone parameters ───────────────────────────────────────
    company:        str
    environment:    str
    region:         str = "westeurope"
    email:          str
    monthly_budget: int = 1000

    # ── Azure Service Principal (required when cloud_provider == "azure") ──
    arm_client_id:       str = ""
    arm_client_secret:   str = ""
    arm_tenant_id:       str = ""
    arm_subscription_id: str = ""

    # ── AWS credentials (required when cloud_provider == "aws") ──────
    aws_access_key_id:     str = ""
    aws_secret_access_key: str = ""
    aws_account_id:        str = ""

    # ── GCP credentials (required when cloud_provider == "gcp") ──────
    gcp_service_account_json: str = ""
    gcp_project_id:           str = ""
    gcp_billing_account_id:   str = ""

    # ── Optional: Terraform remote-state storage ──────────────────────
    # Azure: storage account name / resource group
    # AWS:   S3 bucket name (tfstate_storage_account is reused)
    # GCP:   GCS bucket name (tfstate_storage_account is reused)
    tfstate_storage_account: str = ""
    tfstate_resource_group:  str = ""
    tfstate_container:       str = "tfstate"

    # ── Optional networking overrides ─────────────────────────────────
    # AWS
    vpc_cidr:           str = "10.0.0.0/16"   # VPC CIDR block
    log_retention_days: int = 90               # CloudWatch log retention (days)
    # GCP
    subnet_cidr: str = "10.0.0.0/24"          # Hub subnet CIDR
    gcp_org_id:  str = ""                      # GCP Org ID (enables org-level policies)

    # ── Optional feature flags ────────────────────────────────────────
    # Azure
    enable_firewall:     bool = True
    enable_vpn_gateway:  bool = False
    enable_bastion:      bool = True
    # AWS
    enable_guardduty:    bool = True
    enable_cloudtrail:   bool = True
    enable_security_hub: bool = False
    # GCP
    enable_cloud_nat:    bool = True
    enable_scc:          bool = False
    enable_cloud_armor:  bool = False

    @field_validator("cloud_provider")
    @classmethod
    def validate_provider(cls, v: str) -> str:
        v = v.strip().lower()
        if v not in {"azure", "aws", "gcp"}:
            raise ValueError("cloud_provider must be one of: azure, aws, gcp")
        return v

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

    @model_validator(mode="after")
    def validate_provider_credentials(self) -> "ProvisionRequest":
        provider = self.cloud_provider
        guid_re = re.compile(
            r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
            re.IGNORECASE,
        )

        if provider == "azure":
            for field in ("arm_client_id", "arm_tenant_id", "arm_subscription_id"):
                val = getattr(self, field, "").strip()
                if not val:
                    raise ValueError(f"{field} is required for Azure")
                if not guid_re.match(val):
                    raise ValueError(f"{field} must be a valid UUID / GUID")
            if not self.arm_client_secret.strip():
                raise ValueError("arm_client_secret is required for Azure")

        elif provider == "aws":
            if not self.aws_access_key_id.strip():
                raise ValueError("aws_access_key_id is required for AWS")
            if not self.aws_secret_access_key.strip():
                raise ValueError("aws_secret_access_key is required for AWS")
            if not self.aws_account_id.strip():
                raise ValueError("aws_account_id is required for AWS")

        elif provider == "gcp":
            if not self.gcp_service_account_json.strip():
                raise ValueError("gcp_service_account_json is required for GCP")
            if not self.gcp_project_id.strip():
                raise ValueError("gcp_project_id is required for GCP")

        return self


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

        # Provider
        "cloud_provider": req.cloud_provider,

        # LZ params
        "company":          req.company,
        "environment":      req.environment,
        "region":           req.region,
        "email":            req.email,
        "monthly_budget":   req.monthly_budget,

        # Azure feature flags
        "enable_firewall":     req.enable_firewall,
        "enable_vpn_gateway":  req.enable_vpn_gateway,
        "enable_bastion":      req.enable_bastion,

        # AWS networking + feature flags
        "vpc_cidr":            req.vpc_cidr,
        "log_retention_days":  req.log_retention_days,
        "enable_guardduty":    req.enable_guardduty,
        "enable_cloudtrail":   req.enable_cloudtrail,
        "enable_security_hub": req.enable_security_hub,

        # GCP networking + feature flags
        "subnet_cidr":        req.subnet_cidr,
        "gcp_org_id":         req.gcp_org_id,
        "enable_cloud_nat":   req.enable_cloud_nat,
        "enable_scc":         req.enable_scc,
        "enable_cloud_armor": req.enable_cloud_armor,

        # Azure SP
        "arm_client_id":       req.arm_client_id,
        "arm_client_secret":   req.arm_client_secret,
        "arm_tenant_id":       req.arm_tenant_id,
        "arm_subscription_id": req.arm_subscription_id,

        # AWS credentials
        "aws_access_key_id":     req.aws_access_key_id,
        "aws_secret_access_key": req.aws_secret_access_key,
        "aws_account_id":        req.aws_account_id,

        # GCP credentials
        "gcp_service_account_json": req.gcp_service_account_json,
        "gcp_project_id":           req.gcp_project_id,
        "gcp_billing_account_id":   req.gcp_billing_account_id,

        # Remote state
        "tfstate_storage_account": req.tfstate_storage_account
            or os.getenv("TFSTATE_STORAGE_ACCOUNT", "lzforgetfstate"),
        "tfstate_resource_group": req.tfstate_resource_group
            or os.getenv("TFSTATE_RESOURCE_GROUP", "rg-lzforge-tfstate"),
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

_SECRET_FIELDS = {"arm_client_secret", "aws_secret_access_key", "gcp_service_account_json"}

def _sanitize(job: dict) -> dict:
    """Remove sensitive fields before sending to client."""
    return {k: v for k, v in job.items() if k not in _SECRET_FIELDS}
