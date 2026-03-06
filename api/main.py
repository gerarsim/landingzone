from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, EmailStr
import redis, json, uuid, os

app = FastAPI(title="Velox Provisioning API")

r = redis.from_url(os.getenv("REDIS_URL", "redis://redis:6379"), decode_responses=True)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

class ProvisionRequest(BaseModel):
    company:     str
    environment: str
    region:      str = "westeurope"
    email:       str

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/provision")
def provision(req: ProvisionRequest):
    job_id = str(uuid.uuid4())
    payload = {
        "job_id":      job_id,
        "status":      "queued",
        "company":     req.company,
        "environment": req.environment,
        "region":      req.region,
        "email":       req.email,
        "output":      "",
    }
    # Persist job state
    r.set(f"job:{job_id}", json.dumps(payload))
    # Push to worker queue
    r.rpush("provision_queue", json.dumps(payload))
    return {"job_id": job_id, "status": "queued"}

@app.get("/status/{job_id}")
def status(job_id: str):
    raw = r.get(f"job:{job_id}")
    if not raw:
        raise HTTPException(status_code=404, detail="Job not found")
    return json.loads(raw)

@app.get("/jobs")
def list_jobs():
    keys = r.keys("job:*")
    jobs = []
    for k in keys:
        raw = r.get(k)
        if raw:
            jobs.append(json.loads(raw))
    jobs.sort(key=lambda x: x.get("job_id", ""), reverse=True)
    return jobs
