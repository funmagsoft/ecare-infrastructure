#cloud-config

# Cloud-init script for Bastion VM
# Installs essential tools for managing Azure infrastructure and Kubernetes

package_update: true
package_upgrade: true

# Create users with SSH keys and sudo access
# Note: When 'users' section is defined, it replaces default users, so we must include admin user
users:
  # Admin user (created by Azure, but we need to preserve it)
  - name: ${admin_username}
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ${admin_ssh_key}
%{ if length(additional_users) > 0 ~}
%{ for username, ssh_keys in additional_users ~}
  - name: ${username}
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
%{ for key in ssh_keys ~}
      - ${key}
%{ endfor ~}
%{ endfor ~}
%{ endif ~}

packages:
  - curl
  - wget
  - git
  - jq
  - unzip
  - ca-certificates
  - apt-transport-https
  - lsb-release
  - gnupg

runcmd:
  # Install Azure CLI
  - curl -sL https://aka.ms/InstallAzureCLIDeb | bash

  # Install kubectl
  - curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  - install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
  - rm kubectl

  # Install Helm
  - curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

  # Install PostgreSQL client
  - sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
  - wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
  - apt-get update
  - apt-get install -y postgresql-client

  # Configure bash completion
  - kubectl completion bash > /etc/bash_completion.d/kubectl
  - helm completion bash > /etc/bash_completion.d/helm

  # Create useful aliases in /etc/profile.d
  - |
    cat > /etc/profile.d/k8s-aliases.sh << 'EOF'
    # Kubernetes aliases
    alias k='kubectl'
    alias kgp='kubectl get pods'
    alias kgs='kubectl get services'
    alias kgn='kubectl get nodes'
    alias kd='kubectl describe'
    alias kl='kubectl logs'

    # Azure aliases
    alias azls='az account show'
    alias azrg='az group list -o table'

    # Useful functions
    kexec() {
      kubectl exec -it "$1" -- /bin/bash
    }

    kport() {
      kubectl port-forward "$1" "$2:$2"
    }
    EOF

  # Set permissions
  - chmod +x /etc/profile.d/k8s-aliases.sh

  # Login with managed identity (will work after VM is fully provisioned)
  - |
    cat > /usr/local/bin/azure-login-identity.sh << 'EOF'
    #!/bin/bash
    # Script to login to Azure using managed identity
    echo "Logging in to Azure with managed identity..."
    az login --identity
    echo "Successfully logged in to Azure"
    EOF
  - chmod +x /usr/local/bin/azure-login-identity.sh

write_files:
  - path: /etc/motd
    content: |
      ========================================
      Bastion VM - ${environment} Environment
      ========================================

      Available tools:
        - Azure CLI (az)
        - kubectl
        - Helm
        - PostgreSQL client (psql)
        - jq, git, curl, wget

      Useful aliases:
        k, kgp, kgs, kgn, kd, kl

      To login to Azure:
        az login --identity

      To get AKS credentials:
        az aks get-credentials --resource-group <rg-name> --name <aks-name>

      ========================================
    permissions: '0644'

final_message: "Bastion VM provisioning completed. All tools installed successfully."
