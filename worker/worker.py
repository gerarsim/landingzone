import redis, json, subprocess, os, time, pathlib, logging, sys, shutil

logging.basicConfig(
    stream=sys.stdout, level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
log = logging.getLogger(__name__)

REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379")
r = redis.from_url(REDIS_URL, decode_responses=True)

# ── Encryption — key auto-managed in Redis, no manual config needed ───
def _get_fernet():
    from cryptography.fernet import Fernet
    for attempt in range(30):
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
            log.warning(f"Waiting for Redis... (attempt {attempt + 1})")
            time.sleep(1)
    log.error("Cannot connect to Redis")
    sys.exit(1)

_fernet = _get_fernet()


def encrypt_payload(data: dict) -> str:
    return _fernet.encrypt(json.dumps(data).encode()).decode()


def decrypt_payload(token: str) -> dict:
    return json.loads(_fernet.decrypt(token.encode()))


def update_job(job_id, status, output="", step=""):
    raw = r.get(f"job:{job_id}")
    if not raw:
        return
    job = decrypt_payload(raw)
    job["status"] = status
    job["output"] = output
    if step:
        job["step"] = step
    r.set(f"job:{job_id}", encrypt_payload(job))
    log.info(f"[{job_id[:8]}] {status}" + (f" — {step}" if step else ""))


def run(cmd, cwd, extra_env=None):
    env = {**os.environ, **(extra_env or {})}
    return subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, env=env)


def try_import(job_tf_dir, var_file, resource_addr, resource_id, cred_env):
    res = run(
        ["terraform", "import",
         "-lock=false", f"-var-file={var_file}",
         "-input=false", "-no-color",
         resource_addr, resource_id],
        cwd=job_tf_dir, extra_env=cred_env,
    )
    if res.returncode == 0:
        log.info(f"  ✓ Imported: {resource_addr}")
        return

    err = (res.stderr + res.stdout).lower().replace("\n", " ").replace("\r", " ")

    not_found_signals = [
        "no object exists", "not found", "could not be found",
        "resourcenotfound", "404", "does not exist",
        "no match", "cannot be found", "was not found",
    ]
    already_managed_signals = [
        "already managed by terraform",
        "already exists in the state",
    ]

    if any(s in err for s in already_managed_signals):
        log.info(f"  ✓ Already in state: {resource_addr}")
    elif any(s in err for s in not_found_signals):
        log.info(f"  ○ Not found (will create): {resource_addr}")
    else:
        log.warning(f"  ✗ Import skipped for {resource_addr}: {res.stderr[-300:]}")


# ── Azure runner ─────────────────────────────────────────────────────
def run_terraform_azure(job, job_tf_dir):
    job_id  = job["job_id"]
    company = job["company"]
    env     = job["environment"]
    region  = job.get("region", "westeurope")
    email   = job.get("email", "ops@example.com")
    budget  = job.get("monthly_budget", 1000)
    sub_id  = job.get("arm_subscription_id", "")

    enable_firewall    = str(job.get("enable_firewall",    False)).lower()
    enable_vpn_gateway = str(job.get("enable_vpn_gateway", False)).lower()
    enable_bastion     = str(job.get("enable_bastion",     False)).lower()

    tfstate_sa = job.get("tfstate_storage_account", os.getenv("TFSTATE_STORAGE_ACCOUNT", ""))
    tfstate_rg = job.get("tfstate_resource_group",  os.getenv("TFSTATE_RESOURCE_GROUP", ""))
    state_key  = f"{company}-{env}.tfstate"

    cred_env = {
        "ARM_CLIENT_ID":       job.get("arm_client_id",     os.getenv("ARM_CLIENT_ID", "")),
        "ARM_CLIENT_SECRET":   job.get("arm_client_secret", os.getenv("ARM_CLIENT_SECRET", "")),
        "ARM_TENANT_ID":       job.get("arm_tenant_id",     os.getenv("ARM_TENANT_ID", "")),
        "ARM_SUBSCRIPTION_ID": sub_id,
    }

    var_file = f"{job_tf_dir}/terraform.tfvars"
    with open(var_file, "w") as f:
        f.write(f'company_name       = "{company}"\n')
        f.write(f'environment        = "{env}"\n')
        f.write(f'location           = "{region}"\n')
        f.write(f'alert_email        = "{email}"\n')
        f.write(f'monthly_budget     = {budget}\n')
        f.write(f'enable_firewall    = {enable_firewall}\n')
        f.write(f'enable_vpn_gateway = {enable_vpn_gateway}\n')
        f.write(f'enable_bastion     = {enable_bastion}\n')

    def _fail(msg):
        update_job(job_id, "failed", msg)
        log.error(f"[{job_id[:8]}] ❌ {msg.splitlines()[0]}")

    # ── Init ────────────────────────────────────────────────────────
    update_job(job_id, "provisioning", "Initializing...", "Init")
    res = run(["terraform", "init", "-lock=false",
               f"-backend-config=resource_group_name={tfstate_rg}",
               f"-backend-config=storage_account_name={tfstate_sa}",
               "-backend-config=container_name=tfstate",
               f"-backend-config=key={state_key}",
               "-reconfigure", "-input=false", "-no-color"],
              cwd=job_tf_dir, extra_env=cred_env)
    if res.returncode != 0:
        return _fail(f"Init failed:\n{res.stderr}")

    # ── Validate ─────────────────────────────────────────────────────
    update_job(job_id, "provisioning", "Validating...", "Validate")
    res = run(["terraform", "validate", "-no-color"], cwd=job_tf_dir, extra_env=cred_env)
    if res.returncode != 0:
        return _fail(f"Validate failed:\n{res.stderr}")

    # ── Pre-flight import ─────────────────────────────────────────────
    update_job(job_id, "provisioning", "Importing existing resources...", "Pre-flight")
    log.info(f"[{job_id[:8]}] Pre-flight: importing any existing Azure resources...")

    for rg_name, tf_addr in [
        (f"rg-{company}-network-{env}",  "module.networking.azurerm_resource_group.networking"),
        (f"rg-{company}-security-{env}", "module.networking.azurerm_resource_group.security"),
        (f"rg-{company}-ops-{env}",      "module.networking.azurerm_resource_group.ops"),
    ]:
        try_import(job_tf_dir, var_file, tf_addr,
                   f"/subscriptions/{sub_id}/resourceGroups/{rg_name}", cred_env)

    try_import(job_tf_dir, var_file,
               "module.security.azurerm_key_vault.main",
               f"/subscriptions/{sub_id}/resourceGroups/rg-{company}-security-{env}"
               f"/providers/Microsoft.KeyVault/vaults/kv-{company}-{env}", cred_env)

    res = run(["az", "role", "definition", "list", "--custom-role-only", "true",
               "--query", f"[?roleName=='LZ Operator - {company} {env}'].id",
               "-o", "tsv"], cwd="/tmp", extra_env=cred_env)
    role_id = res.stdout.strip()
    if role_id:
        try_import(job_tf_dir, var_file,
                   "module.identity.azurerm_role_definition.lz_operator",
                   f"{role_id}|/subscriptions/{sub_id}", cred_env)

    try_import(job_tf_dir, var_file,
               "module.budget.azurerm_consumption_budget_subscription.main",
               f"/subscriptions/{sub_id}/providers/Microsoft.Consumption/budgets/budget-{company}-{env}",
               cred_env)

    # ── Plan ─────────────────────────────────────────────────────────
    update_job(job_id, "provisioning", "Planning...", "Plan")
    res = run(["terraform", "plan", "-lock=false",
               f"-var-file={var_file}", "-input=false", "-no-color", "-detailed-exitcode"],
              cwd=job_tf_dir, extra_env=cred_env)
    if res.returncode == 1:
        return _fail(f"Plan failed:\n{res.stderr}\n{res.stdout[-1000:]}")

    # ── Apply ─────────────────────────────────────────────────────────
    update_job(job_id, "provisioning", "Applying...", "Apply")
    res = run(["terraform", "apply", "-lock=false", "-auto-approve",
               f"-var-file={var_file}", "-input=false", "-no-color"],
              cwd=job_tf_dir, extra_env=cred_env)

    if res.returncode == 0:
        update_job(job_id, "completed", res.stdout[-3000:], "Completed")
        log.info(f"[{job_id[:8]}] ✅ Completed successfully")
    else:
        _fail(f"Apply failed:\n{res.stderr[-2000:]}")


# ── AWS runner ───────────────────────────────────────────────────────
def run_terraform_aws(job, job_tf_dir):
    job_id             = job["job_id"]
    company            = job["company"]
    env                = job["environment"]
    region             = job.get("region", "us-east-1")
    email              = job.get("email", "ops@example.com")
    budget             = job.get("monthly_budget", 1000)
    vpc_cidr           = job.get("vpc_cidr", "10.0.0.0/16")
    log_retention_days = job.get("log_retention_days", 90)
    bucket             = job.get("tfstate_storage_account", os.getenv("TFSTATE_STORAGE_ACCOUNT", ""))
    state_key          = f"{company}-{env}.tfstate"

    enable_guardduty    = str(job.get("enable_guardduty",    True)).lower()
    enable_cloudtrail   = str(job.get("enable_cloudtrail",   True)).lower()
    enable_security_hub = str(job.get("enable_security_hub", False)).lower()

    cred_env = {
        "AWS_ACCESS_KEY_ID":     job.get("aws_access_key_id",     ""),
        "AWS_SECRET_ACCESS_KEY": job.get("aws_secret_access_key", ""),
        "AWS_DEFAULT_REGION":    region,
    }

    var_file = f"{job_tf_dir}/terraform.tfvars"
    with open(var_file, "w") as f:
        f.write(f'company_name        = "{company}"\n')
        f.write(f'environment         = "{env}"\n')
        f.write(f'region              = "{region}"\n')
        f.write(f'vpc_cidr            = "{vpc_cidr}"\n')
        f.write(f'log_retention_days  = {log_retention_days}\n')
        f.write(f'alert_email         = "{email}"\n')
        f.write(f'monthly_budget      = {budget}\n')
        f.write(f'enable_guardduty    = {enable_guardduty}\n')
        f.write(f'enable_cloudtrail   = {enable_cloudtrail}\n')
        f.write(f'enable_security_hub = {enable_security_hub}\n')

    def _fail(msg):
        update_job(job_id, "failed", msg)
        log.error(f"[{job_id[:8]}] ❌ {msg.splitlines()[0]}")

    update_job(job_id, "provisioning", "Initializing...", "Init")
    res = run(["terraform", "init", "-lock=false",
               f"-backend-config=bucket={bucket}",
               f"-backend-config=key={state_key}",
               f"-backend-config=region={region}",
               "-reconfigure", "-input=false", "-no-color"],
              cwd=job_tf_dir, extra_env=cred_env)
    if res.returncode != 0:
        return _fail(f"Init failed:\n{res.stderr}")

    update_job(job_id, "provisioning", "Validating...", "Validate")
    res = run(["terraform", "validate", "-no-color"], cwd=job_tf_dir, extra_env=cred_env)
    if res.returncode != 0:
        return _fail(f"Validate failed:\n{res.stderr}")

    update_job(job_id, "provisioning", "Planning...", "Plan")
    res = run(["terraform", "plan", "-lock=false",
               f"-var-file={var_file}", "-input=false", "-no-color", "-detailed-exitcode"],
              cwd=job_tf_dir, extra_env=cred_env)
    if res.returncode == 1:
        return _fail(f"Plan failed:\n{res.stderr}\n{res.stdout[-1000:]}")

    update_job(job_id, "provisioning", "Applying...", "Apply")
    res = run(["terraform", "apply", "-lock=false", "-auto-approve",
               f"-var-file={var_file}", "-input=false", "-no-color"],
              cwd=job_tf_dir, extra_env=cred_env)

    if res.returncode == 0:
        update_job(job_id, "completed", res.stdout[-3000:], "Completed")
        log.info(f"[{job_id[:8]}] ✅ Completed successfully")
    else:
        _fail(f"Apply failed:\n{res.stderr[-2000:]}")


# ── GCP runner ───────────────────────────────────────────────────────
def run_terraform_gcp(job, job_tf_dir):
    job_id             = job["job_id"]
    company            = job["company"]
    env                = job["environment"]
    region             = job.get("region", "europe-west1")
    email              = job.get("email", "ops@example.com")
    budget             = job.get("monthly_budget", 1000)
    project_id         = job.get("gcp_project_id", "")
    billing_account_id = job.get("gcp_billing_account_id", "")
    subnet_cidr        = job.get("subnet_cidr", "10.0.0.0/24")
    org_id             = job.get("gcp_org_id", "")
    bucket             = job.get("tfstate_storage_account", os.getenv("TFSTATE_STORAGE_ACCOUNT", ""))
    state_prefix       = f"{company}-{env}"

    enable_cloud_nat   = str(job.get("enable_cloud_nat",   True)).lower()
    enable_scc         = str(job.get("enable_scc",         False)).lower()
    enable_cloud_armor = str(job.get("enable_cloud_armor", False)).lower()

    cred_env = {
        "GOOGLE_CREDENTIALS": job.get("gcp_service_account_json", ""),
        "GOOGLE_PROJECT":     project_id,
    }

    var_file = f"{job_tf_dir}/terraform.tfvars"
    with open(var_file, "w") as f:
        f.write(f'company_name        = "{company}"\n')
        f.write(f'environment         = "{env}"\n')
        f.write(f'project_id          = "{project_id}"\n')
        f.write(f'region              = "{region}"\n')
        f.write(f'subnet_cidr         = "{subnet_cidr}"\n')
        f.write(f'org_id              = "{org_id}"\n')
        f.write(f'alert_email         = "{email}"\n')
        f.write(f'monthly_budget      = {budget}\n')
        f.write(f'billing_account_id  = "{billing_account_id}"\n')
        f.write(f'enable_cloud_nat    = {enable_cloud_nat}\n')
        f.write(f'enable_scc          = {enable_scc}\n')
        f.write(f'enable_cloud_armor  = {enable_cloud_armor}\n')

    def _fail(msg):
        update_job(job_id, "failed", msg)
        log.error(f"[{job_id[:8]}] ❌ {msg.splitlines()[0]}")

    update_job(job_id, "provisioning", "Initializing...", "Init")
    res = run(["terraform", "init", "-lock=false",
               f"-backend-config=bucket={bucket}",
               f"-backend-config=prefix={state_prefix}",
               "-reconfigure", "-input=false", "-no-color"],
              cwd=job_tf_dir, extra_env=cred_env)
    if res.returncode != 0:
        return _fail(f"Init failed:\n{res.stderr}")

    update_job(job_id, "provisioning", "Validating...", "Validate")
    res = run(["terraform", "validate", "-no-color"], cwd=job_tf_dir, extra_env=cred_env)
    if res.returncode != 0:
        return _fail(f"Validate failed:\n{res.stderr}")

    update_job(job_id, "provisioning", "Planning...", "Plan")
    res = run(["terraform", "plan", "-lock=false",
               f"-var-file={var_file}", "-input=false", "-no-color", "-detailed-exitcode"],
              cwd=job_tf_dir, extra_env=cred_env)
    if res.returncode == 1:
        return _fail(f"Plan failed:\n{res.stderr}\n{res.stdout[-1000:]}")

    update_job(job_id, "provisioning", "Applying...", "Apply")
    res = run(["terraform", "apply", "-lock=false", "-auto-approve",
               f"-var-file={var_file}", "-input=false", "-no-color"],
              cwd=job_tf_dir, extra_env=cred_env)

    if res.returncode == 0:
        update_job(job_id, "completed", res.stdout[-3000:], "Completed")
        log.info(f"[{job_id[:8]}] ✅ Completed successfully")
    else:
        _fail(f"Apply failed:\n{res.stderr[-2000:]}")


# ── Dispatch ─────────────────────────────────────────────────────────
def run_terraform(job):
    job_id   = job["job_id"]
    company  = job["company"].lower().replace(" ", "-")
    env      = job["environment"].lower()
    provider = job.get("cloud_provider", "azure")

    job_tf_dir = f"/tfwork/{job_id}"
    if pathlib.Path(job_tf_dir).exists():
        shutil.rmtree(job_tf_dir)
    shutil.copytree(f"/terraform/{provider}", job_tf_dir)

    log.info(f"[{job_id[:8]}] Provider: {provider} | {company} | {env}")

    if provider == "azure":
        run_terraform_azure(job, job_tf_dir)
    elif provider == "aws":
        run_terraform_aws(job, job_tf_dir)
    elif provider == "gcp":
        run_terraform_gcp(job, job_tf_dir)
    else:
        update_job(job_id, "failed", f"Unknown cloud provider: {provider}")


# ── Main loop ────────────────────────────────────────────────────────
log.info("✅ LZForge Worker started — waiting for jobs...")
pathlib.Path("/tfwork/.plugin-cache").mkdir(parents=True, exist_ok=True)

_backoff = 2  # seconds, doubles on repeated failures up to _backoff_max
_backoff_max = 60

while True:
    try:
        item = r.blpop("provision_queue", timeout=5)
        if not item:
            _backoff = 2  # reset on successful poll
            continue
        _, payload = item
        job = decrypt_payload(payload)
        provider = job.get("cloud_provider", "azure")
        log.info(f"📦 New job: {job['job_id'][:8]} | [{provider.upper()}] {job['company']} | {job['environment']}")
        run_terraform(job)
        _backoff = 2  # reset after successful job
    except redis.exceptions.ConnectionError:
        log.warning("Redis disconnected, retrying in 3s...")
        time.sleep(3)
    except Exception as e:
        log.error(f"Worker error: {e}")
        log.info(f"Retrying in {_backoff}s...")
        time.sleep(_backoff)
        _backoff = min(_backoff * 2, _backoff_max)
