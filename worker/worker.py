"""
Velox Worker — Terraform runner
Picks jobs from Redis queue, provisions Azure Landing Zones per-job.
Credentials are taken from the job payload (collected on the form),
never from static environment variables.
"""

import redis, json, subprocess, os, time, pathlib, shutil, logging

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
log = logging.getLogger("velox-worker")

REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379")
TF_DIR    = "/terraform"
WORK_DIR  = "/tfwork"      # per-job working copies of terraform source
STATE_DIR = "/tfstate"     # per-job .tfvars + state refs

r = redis.from_url(REDIS_URL, decode_responses=True)

pathlib.Path(STATE_DIR).mkdir(parents=True, exist_ok=True)
pathlib.Path(WORK_DIR).mkdir(parents=True, exist_ok=True)


# ── Redis helpers ────────────────────────────────────────────────────

def get_job(job_id: str) -> dict | None:
    raw = r.get(f"job:{job_id}")
    return json.loads(raw) if raw else None


def update_job(job_id: str, status: str, output: str = "", step: str = ""):
    job = get_job(job_id)
    if not job:
        return
    job["status"] = status
    job["output"] = output
    if step:
        steps = job.get("steps", [])
        steps.append(step)
        job["steps"] = steps
    r.setex(f"job:{job_id}", 86400, json.dumps(job))
    log.info("[%s] %s — %s", job_id[:8], status, step or output[:80])


# ── Subprocess helper ────────────────────────────────────────────────

def run(cmd: list, cwd: str, extra_env: dict = None) -> subprocess.CompletedProcess:
    """Run a command, merging extra_env on top of the current environment."""
    env = {**os.environ, **(extra_env or {})}
    return subprocess.run(
        cmd,
        cwd=cwd,
        capture_output=True,
        text=True,
        env=env,
    )


# ── Terraform state bootstrap ────────────────────────────────────────

def ensure_tfstate_backend(job: dict, arm_env: dict) -> bool:
    """
    Ensure the Azure Storage Account for Terraform remote state exists.
    Uses Azure CLI with the job's SP credentials.
    """
    sa   = job["tfstate_storage_account"]
    rg   = job["tfstate_resource_group"]
    cont = job["tfstate_container"]
    loc  = job.get("region", "westeurope")

    log.info("Ensuring Terraform backend: %s/%s/%s", rg, sa, cont)

    # Login with SP
    res = run(
        ["az", "login", "--service-principal",
         "--username",  arm_env["ARM_CLIENT_ID"],
         "--password",  arm_env["ARM_CLIENT_SECRET"],
         "--tenant",    arm_env["ARM_TENANT_ID"]],
        cwd="/tmp",
    )
    if res.returncode != 0:
        log.error("az login failed: %s", res.stderr)
        return False

    # Set subscription
    run(["az", "account", "set",
         "--subscription", arm_env["ARM_SUBSCRIPTION_ID"]], cwd="/tmp")

    # Create RG if missing
    run(["az", "group", "create",
         "--name", rg, "--location", loc,
         "--output", "none"], cwd="/tmp", extra_env=arm_env)

    # Create storage account if missing
    run(["az", "storage", "account", "create",
         "--name", sa, "--resource-group", rg,
         "--location", loc, "--sku", "Standard_LRS",
         "--output", "none"], cwd="/tmp", extra_env=arm_env)

    # Create container if missing
    run(["az", "storage", "container", "create",
         "--name", cont,
         "--account-name", sa,
         "--output", "none"], cwd="/tmp", extra_env=arm_env)

    return True


# ── Main Terraform runner ────────────────────────────────────────────

def run_terraform(job: dict):
    job_id  = job["job_id"]
    company = job["company"]
    env     = job["environment"]
    region  = job.get("region", "westeurope")

    # Per-job ARM credentials injected as env vars for all Terraform calls
    arm_env = {
        "ARM_CLIENT_ID":       job["arm_client_id"],
        "ARM_CLIENT_SECRET":   job["arm_client_secret"],
        "ARM_TENANT_ID":       job["arm_tenant_id"],
        "ARM_SUBSCRIPTION_ID": job["arm_subscription_id"],
    }

    # Per-job isolated working directory (avoids state conflicts)
    job_tf_dir = f"{WORK_DIR}/{job_id}"
    shutil.copytree(TF_DIR, job_tf_dir, dirs_exist_ok=True)

    var_file  = f"{STATE_DIR}/{job_id}.tfvars"
    state_key = f"lz/{company}-{env}/{job_id}.tfstate"

    sa   = job["tfstate_storage_account"]
    rg   = job["tfstate_resource_group"]
    cont = job["tfstate_container"]

    # ── Write per-job tfvars ──────────────────────────────────────────
    with open(var_file, "w") as f:
        f.write(f'company_name         = "{company}"\n')
        f.write(f'environment          = "{env}"\n')
        f.write(f'location             = "{region}"\n')
        f.write(f'alert_email          = "{job["email"]}"\n')
        f.write(f'monthly_budget       = {job.get("monthly_budget", 1000)}\n')
        f.write(f'enable_firewall      = {str(job.get("enable_firewall", True)).lower()}\n')
        f.write(f'enable_vpn_gateway   = {str(job.get("enable_vpn_gateway", False)).lower()}\n')
        f.write(f'enable_bastion       = {str(job.get("enable_bastion", True)).lower()}\n')
        f.write(f'arm_subscription_id  = "{job["arm_subscription_id"]}"\n')
        f.write(f'arm_tenant_id        = "{job["arm_tenant_id"]}"\n')

    # ── Step 1: Ensure remote state backend ──────────────────────────
    update_job(job_id, "provisioning",
               "Bootstrapping Terraform remote state storage...",
               "Bootstrap: remote state")
    if not ensure_tfstate_backend(job, arm_env):
        update_job(job_id, "failed", "Failed to bootstrap Terraform backend storage.")
        return

    # ── Step 2: terraform init ────────────────────────────────────────
    update_job(job_id, "provisioning",
               "Running terraform init...", "Init")
    res = run(
        ["terraform", "init",
         f"-backend-config=resource_group_name={rg}",
         f"-backend-config=storage_account_name={sa}",
         f"-backend-config=container_name={cont}",
         f"-backend-config=key={state_key}",
         "-reconfigure", "-input=false"],
        cwd=job_tf_dir,
        extra_env=arm_env,
    )
    if res.returncode != 0:
        update_job(job_id, "failed", f"Init failed:\n{res.stderr}", "Init failed")
        _cleanup(job_tf_dir, var_file)
        return

    # ── Step 3: terraform validate ────────────────────────────────────
    update_job(job_id, "provisioning",
               "Validating Terraform configuration...", "Validate")
    res = run(
        ["terraform", "validate", "-no-color"],
        cwd=job_tf_dir, extra_env=arm_env,
    )
    if res.returncode != 0:
        update_job(job_id, "failed", f"Validate failed:\n{res.stderr}", "Validate failed")
        _cleanup(job_tf_dir, var_file)
        return

    # ── Step 4: terraform plan ────────────────────────────────────────
    update_job(job_id, "provisioning",
               "Generating execution plan...", "Plan")
    res = run(
        ["terraform", "plan",
         f"-var-file={var_file}",
         "-input=false", "-no-color",
         "-out=/tmp/tfplan"],
        cwd=job_tf_dir, extra_env=arm_env,
    )
    plan_summary = _tail(res.stdout, 30)
    if res.returncode != 0:
        update_job(job_id, "failed",
                   f"Plan failed:\n{res.stderr[-2000:]}", "Plan failed")
        _cleanup(job_tf_dir, var_file)
        return
    update_job(job_id, "provisioning", plan_summary, "Plan complete — applying")

    # ── Step 5: terraform apply ───────────────────────────────────────
    update_job(job_id, "provisioning",
               "Applying Terraform plan — this takes 3-8 minutes...", "Apply")
    res = run(
        ["terraform", "apply",
         "-auto-approve",
         "/tmp/tfplan",
         "-no-color"],
        cwd=job_tf_dir, extra_env=arm_env,
    )

    if res.returncode == 0:
        # Collect outputs
        out_res = run(
            ["terraform", "output", "-json"],
            cwd=job_tf_dir, extra_env=arm_env,
        )
        outputs = out_res.stdout if out_res.returncode == 0 else ""
        final_msg = _tail(res.stdout, 40) + ("\n\nOutputs:\n" + outputs if outputs else "")
        update_job(job_id, "completed", final_msg, "Completed")
        log.info("[%s] ✅ Landing zone provisioned successfully.", job_id[:8])
    else:
        update_job(job_id, "failed",
                   f"Apply failed:\n{res.stderr[-2000:]}", "Apply failed")
        log.error("[%s] ❌ Apply failed.", job_id[:8])

    _cleanup(job_tf_dir, var_file)


# ── Utilities ────────────────────────────────────────────────────────

def _tail(text: str, lines: int) -> str:
    return "\n".join(text.splitlines()[-lines:])


def _cleanup(tf_dir: str, var_file: str):
    """Remove per-job working directory and tfvars (contains sensitive values)."""
    try:
        shutil.rmtree(tf_dir, ignore_errors=True)
        pathlib.Path(var_file).unlink(missing_ok=True)
    except Exception as e:
        log.warning("Cleanup error: %s", e)


# ── Main loop ────────────────────────────────────────────────────────

log.info("✅ Velox Worker started — waiting for jobs...")

while True:
    try:
        item = r.blpop("provision_queue", timeout=5)
        if item is None:
            continue
        _, payload = item
        job = json.loads(payload)
        log.info("📦 New job: %s | %s | %s",
                 job["job_id"][:8], job["company"], job["environment"])
        run_terraform(job)

    except redis.exceptions.ConnectionError:
        log.warning("Redis disconnected — retrying in 3s...")
        time.sleep(3)
    except Exception as e:
        log.error("Worker error: %s", e, exc_info=True)
        time.sleep(2)
