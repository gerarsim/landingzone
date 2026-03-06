import redis, json, subprocess, os, time, pathlib

REDIS_URL = os.getenv("REDIS_URL", "redis://redis:6379")
TF_DIR    = "/terraform"
STATE_DIR = "/tfstate"

r = redis.from_url(REDIS_URL, decode_responses=True)

pathlib.Path(STATE_DIR).mkdir(parents=True, exist_ok=True)


def update_job(job_id: str, status: str, output: str = ""):
    raw = r.get(f"job:{job_id}")
    if not raw:
        return
    job = json.loads(raw)
    job["status"] = status
    job["output"] = output
    r.set(f"job:{job_id}", json.dumps(job))
    print(f"[{job_id[:8]}] {status}", flush=True)


def run(cmd: list, cwd: str, env: dict = None) -> subprocess.CompletedProcess:
    merged_env = {**os.environ, **(env or {})}
    return subprocess.run(
        cmd, cwd=cwd,
        capture_output=True, text=True,
        env=merged_env
    )


def run_terraform(job: dict):
    job_id   = job["job_id"]
    company  = job["company"].lower().replace(" ", "-")
    env      = job["environment"].lower()
    region   = job["region"]

    var_file  = f"{STATE_DIR}/{job_id}.tfvars"
    state_key = f"{job_id}.tfstate"

    # Write per-job tfvars
    with open(var_file, "w") as f:
        f.write(f'company_name = "{company}"\n')
        f.write(f'environment  = "{env}"\n')
        f.write(f'location     = "{region}"\n')

    update_job(job_id, "provisioning", "Initializing Terraform...")

    # terraform init
    res = run(
        ["terraform", "init",
         f"-backend-config=key={state_key}",
         "-reconfigure", "-input=false"],
        cwd=TF_DIR
    )
    print(res.stdout, flush=True)
    if res.returncode != 0:
        update_job(job_id, "failed", res.stderr)
        return

    # terraform plan (optional, good for demos)
    res = run(
        ["terraform", "plan",
         f"-var-file={var_file}",
         "-input=false", "-no-color"],
        cwd=TF_DIR
    )
    update_job(job_id, "provisioning", "Plan complete. Applying...")

    # terraform apply
    res = run(
        ["terraform", "apply",
         "-auto-approve",
         f"-var-file={var_file}",
         "-input=false", "-no-color"],
        cwd=TF_DIR
    )

    if res.returncode == 0:
        update_job(job_id, "completed", res.stdout[-2000:])  # last 2k chars
    else:
        update_job(job_id, "failed", res.stderr[-2000:])


# ── Main loop ──────────────────────────────────────────────────────
print("✅ Velox Worker started — waiting for jobs...", flush=True)

while True:
    try:
        # blpop blocks until a job arrives (timeout=5 for health checks)
        item = r.blpop("provision_queue", timeout=5)
        if item is None:
            continue
        _, payload = item
        job = json.loads(payload)
        print(f"\n📦 New job: {job['job_id'][:8]} | {job['company']} | {job['environment']}", flush=True)
        run_terraform(job)
    except redis.exceptions.ConnectionError:
        print("Redis disconnected, retrying in 3s...", flush=True)
        time.sleep(3)
    except Exception as e:
        print(f"Worker error: {e}", flush=True)
        time.sleep(2)
