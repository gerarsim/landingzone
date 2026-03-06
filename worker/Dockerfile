# Base: official Terraform image (Alpine)
FROM hashicorp/terraform:1.7

# Install Python3, pip, curl, bash
RUN apk add --no-cache python3 py3-pip curl bash

# Install Azure CLI (Python-based, works on Alpine)
RUN pip3 install azure-cli redis --break-system-packages

# Azure auth via environment variables (set in docker-compose / .env)
ENV ARM_CLIENT_ID=""
ENV ARM_CLIENT_SECRET=""
ENV ARM_TENANT_ID=""
ENV ARM_SUBSCRIPTION_ID=""

WORKDIR /app
COPY requirements.txt .
RUN pip3 install -r requirements.txt --break-system-packages

COPY worker.py .

CMD ["python3", "worker.py"]
