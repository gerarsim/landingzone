# Use Python as base — install Terraform into it (avoids terraform entrypoint conflict)
FROM python:3.12-slim

# Install system deps
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl unzip gnupg lsb-release ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Terraform 1.7
RUN curl -fsSL https://releases.hashicorp.com/terraform/1.7.5/terraform_1.7.5_linux_amd64.zip \
    -o /tmp/terraform.zip \
    && unzip /tmp/terraform.zip -d /usr/local/bin/ \
    && rm /tmp/terraform.zip \
    && terraform version

# Install Azure CLI
RUN curl -sL https://aka.ms/InstallAzureCLIDeb | bash

# Python dependencies
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY worker.py .

# Azure auth env vars (injected from docker-compose / .env)
ENV ARM_CLIENT_ID=""
ENV ARM_CLIENT_SECRET=""
ENV ARM_TENANT_ID=""
ENV ARM_SUBSCRIPTION_ID=""

CMD ["python3", "worker.py"]
