# Velox — Azure Landing Zone Demo

## Folder Structure

```
lz/
├── docker-compose.yml       ← orchestrates all services
├── .env                     ← your Azure credentials (never commit!)
├── .env.example             ← template
├── frontend/
│   ├── Dockerfile
│   └── index.html           ← landing page with provision form
├── api/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── main.py              ← FastAPI (job queue + status)
├── worker/
│   ├── Dockerfile
│   ├── requirements.txt
│   └── worker.py            ← Terraform runner
└── terraform/
    ├── main.tf              ← Azure Landing Zone resources
    ├── variables.tf
    └── outputs.tf
```

## Prerequisites

- Docker Desktop running
- Azure subscription
- Azure CLI installed locally

## Setup

### 1. Create Azure Service Principal

```powershell
az login
az ad sp create-for-rbac --name "velox-demo-sp" --role Owner `
  --scopes /subscriptions/<YOUR_SUBSCRIPTION_ID>
```

Copy the output into your `.env` file.

### 2. Create Terraform Remote State Storage (one-time)

```powershell
az group create --name rg-velox-tfstate --location westeurope
az storage account create --name veloxtfstate --resource-group rg-velox-tfstate `
  --location westeurope --sku Standard_LRS
az storage container create --name tfstate --account-name veloxtfstate
```

### 3. Fill in .env

```
AZURE_CLIENT_ID=<app-id>
AZURE_CLIENT_SECRET=<secret>
AZURE_TENANT_ID=<tenant-id>
AZURE_SUBSCRIPTION_ID=<subscription-id>
```

### 4. Run

```powershell
docker compose up --build
```

Open http://localhost — fill in the form — watch Azure provision live.

## Watch Logs During Demo

```powershell
# All services
docker compose logs -f

# Worker only (shows Terraform output)
docker compose logs -f worker

# Check all jobs
curl http://localhost:8000/jobs
```

## What Gets Provisioned in Azure

| Resource | Name Pattern |
|---|---|
| Management Group | `mg-<company>-<env>` |
| Resource Group (Network) | `rg-<company>-network-<env>` |
| Resource Group (Security) | `rg-<company>-security-<env>` |
| Resource Group (Ops) | `rg-<company>-ops-<env>` |
| Hub VNet | `vnet-hub-<env>` |
| Subnets | GatewaySubnet, snet-management, snet-app |
| NSG | `nsg-management-<env>` |
| Key Vault | `kv-<company>-<env>` |
| Log Analytics | `law-<company>-<env>` |
| Storage Account | `st<company>diag<env>` |
| Azure Policy | Require environment tag |

thank you
