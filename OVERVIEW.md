# System Architecture - Kubectl-Ops Cli Guide

## Table of Contents
1. [Introduction](#introduction)
2. [System Architecture](#architecture)
3. [Components and Tools](#components)
4. [Installation and Setup](#installation)
5. [User Management](#user-management)
6. [Daily Operations](#operations)
7. [Troubleshooting](#troubleshooting)

---

## 1. Introduction {#introduction}

**OpenServerless** is an open source platform for serverless computing that offers a flexible and portable alternative to proprietary cloud provider solutions (AWS Lambda, Azure Functions, Google Cloud Functions).

### Key Features
- **Fully Open Source**: Completely open and modifiable code
- **Portability**: Avoids vendor lock-in, deploy anywhere
- **Kubernetes-Based**: Leverages the cloud-native ecosystem
- **Self-Hosted**: Complete control over data and infrastructure
- **Multi-Runtime Compatibility**: Supports multiple programming languages

---

## 2. System Architecture {#architecture}

### Technology Stack

```
┌─────────────────────────────────────────┐
│         CLI Tools (ops, kubectl)        │
│         User Interface                  │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│         Docker Desktop                  │
│    (Container Runtime + Kubernetes)     │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│      Kubernetes Cluster                 │
│   • Container Orchestration             │
│   • Resource Management                 │
│   • Networking and Storage              │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│      OpenServerless Platform            │
│   • Controller                          │
│   • API Gateway                         │
│   • Function Runtime                    │
│   • Database (CouchDB)                  │
│   • Optional: Redis, MongoDB, MinIO     │
└─────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────┐
│      Exposed Services                   │
│   • REST API                            │
│   • Web UI                              │
│   • Authentication                      │
└─────────────────────────────────────────┘
```

### Dependency Flow

**Without Docker Desktop:**
- ❌ Kubernetes unavailable
- ❌ OpenServerless cannot start
- ❌ REST APIs inaccessible
- ❌ Web UI not working
- ✅ Only CLI tools available (local commands)

**With Docker Desktop Active:**
- ✅ Kubernetes operational
- ✅ OpenServerless deployed
- ✅ REST APIs available
- ✅ Web UI accessible
- ✅ Authentication working

---

## 3. Components and Tools {#components}

### kubectl

**What it does:**
- Command-line client for Kubernetes
- Manages native K8s resources (pods, services, secrets, namespaces)
- Operates at **low infrastructure level**

**Essential Commands:**

```bash
# Check cluster status
kubectl get nodes

# List namespaces
kubectl get namespaces

# View all pods
kubectl get pods --all-namespaces

# View resources in a specific namespace
kubectl get all -n <namespace>

# View secrets
kubectl get secrets -n <namespace>

# View pod logs
kubectl logs <pod-name> -n <namespace>

# Edit a resource
kubectl edit secret <secret-name> -n <namespace>

# kubectl configuration
kubectl config view
kubectl config current-context
kubectl config get-contexts
```

### ops CLI

**What it does:**
- OpenServerless-specific CLI
- Simplifies complex operations
- Operates at **high application level**
- Uses kubectl behind the scenes

**Essential Commands:**

```bash
# CLI information
ops -version
ops -info
ops -help
ops -tasks

# Setup and configuration
ops setup prereq          # Validate prerequisites
ops setup cluster         # Deploy on existing cluster
ops setup devcluster      # Create local dev cluster
ops setup mini            # Deploy slim version
ops setup status          # Check status
ops setup uninstall       # Uninstall

# Configuration
ops -config               # Manage configuration

# Authentication
ops -login <apihost> <username>

# User management (admin)
ops admin adduser <username> <email> <password> [options]
ops admin deleteuser <username>
ops admin listuser [<username>]
ops admin usage

# Action management (serverless functions)
ops action list
ops action create <n> <file>
ops action update <n> <file>
ops action delete <n>
ops action invoke <n>

# Packages and triggers
ops package list
ops trigger list
ops rule list

# Logs and debugging
ops activations list
ops logs <activation-id>
ops result <activation-id>
```

### Relationship between kubectl and ops

```
ops admin adduser mario email@test.com Pass123 --all
           ↓
    (internally executes)
           ↓
kubectl create namespace mario
kubectl create secret generic mario-auth ...
kubectl apply -f mario-redis-deployment.yaml
kubectl apply -f mario-mongodb-deployment.yaml
kubectl apply -f mario-storage-pvc.yaml
...
```

**When to use what:**
- **ops**: Standard and simplified operations on OpenServerless
- **kubectl**: Debug, manual modifications, operations not supported by ops (e.g., password change)

---

## 4. Installation and Setup {#installation}

### Prerequisites

**System:**
- Docker Desktop with at least 6GB RAM
- 20GB+ available disk space

**Verify installations:**

```bash
# Verify Docker
docker --version
docker ps

# Verify Kubernetes
kubectl version --client
kubectl get nodes

# Verify ops
ops -version
ops -info
```

### OpenServerless Setup

#### Option 1: Mini Setup (Lightweight Local)

```bash
# Deploy slim version
ops setup mini

# Access: http://devel.miniops.me
```

#### Option 2: Cluster Setup (Docker Desktop)

```bash
# 1. Start Docker Desktop and wait for Kubernetes to be ready
kubectl get nodes
# Must show: docker-desktop   Ready

# 2. Validate prerequisites
ops setup prereq

# 3. Deploy OpenServerless
ops setup cluster

# 4. Verify installation
ops setup status

# 5. Check active pods
kubectl get pods --all-namespaces
```

#### Option 3: Dev Cluster

```bash
# Create and configure a local dev cluster
ops setup devcluster
```

### Verify Installation

```bash
# View created namespaces
kubectl get namespaces
# Should show: nuvolaris or similar

# View OpenServerless pods
kubectl get pods -n nuvolaris

# Verify services
kubectl get services -n nuvolaris

# Test ops configuration
ops -config
```

---

## 5. User Management {#user-management}

### Basic Concept

**In OpenServerless: Users = Namespaces**
- Each user has their own isolated Kubernetes namespace
- User services run in their namespace
- Complete isolation between users

### Creating a User

```bash
# Basic syntax
ops admin adduser <username> <email> <password>

# With all services
ops admin adduser mario mario@example.com Pass123! --all --storagequota=auto

# With specific services
ops admin adduser luigi luigi@example.com Pass456! --redis --mongodb --minio

# With specific storage quota
ops admin adduser peach peach@example.com Pass789! --all --storagequota=10G
```

**Available service options:**
- `--all`: Enable all services
- `--redis`: In-memory key-value database
- `--mongodb`: NoSQL document-oriented database
- `--minio`: S3-compatible object storage
- `--postgres`: Relational database
- `--milvus`: Vector database for AI/ML
- `--storagequota=<size>`: Storage quota (e.g., 10G) or `auto`

### Listing Users

```bash
# List all users
ops admin listuser

# Specific user details
ops admin listuser mario

# With kubectl
kubectl get namespaces
```

### Deleting a User

```bash
# Warning: deletes all user data!
ops admin deleteuser mario

# Verify deletion
kubectl get namespace mario
# Should error: "not found"
```

### Changing User Password

**Problem**: `ops` has no direct command to change password.

**Solution 1: Via kubectl (Recommended)**

```bash
# 1. Find user's secret
kubectl get secrets -n mario

# 2. View secrets
kubectl get secrets -n mario -o yaml

# 3. Identify the credentials secret (e.g., "mario-auth")
kubectl get secret mario-auth -n mario -o yaml

# 4. Encode new password in base64
echo -n "NewPassword123!" | base64
# Output: TmV3UGFzc3dvcmQxMjMh

# 5. Edit the secret
kubectl edit secret mario-auth -n mario
# Replace password field with new base64 value

# 6. Save and exit
```

**Solution 2: Recreate user (Data Loss!)**

```bash
# Save important configurations first!

# Delete user
ops admin deleteuser mario

# Recreate with new password
ops admin adduser mario mario@example.com NewPass! --all --storagequota=auto
```

### Monitoring User Resources

```bash
# View storage usage
ops admin usage

# Detailed debug
ops admin usage --debug

# View all user resources
kubectl get all -n mario

# View specific pods
kubectl get pods -n mario

# User service logs
kubectl logs <pod-name> -n mario
```

---

## 6. Daily Operations {#operations}

### Login and Authentication

```bash
# Standard login
ops -login http://miniops.me mario
# Enter password when prompted

# Login with custom URL
ops -login https://my-openserverless.com mario

# With environment variables (for scripts)
export OPS_APIHOST=http://miniops.me
export OPS_USER=mario
export OPS_PASSWORD=Pass123!
ops -login
```

### Managing Actions (Serverless Functions)

#### Creating an Action

```bash
# Inline JavaScript action
ops action create hello <(echo 'function main() { return {body: "Hello World!"}; }') --kind nodejs:default

# Action from file
echo 'function main(params) { 
  return {greeting: "Hello " + params.name}; 
}' > hello.js

ops action create hello hello.js --kind nodejs:default

# Python action
echo 'def main(args):
    name = args.get("name", "stranger")
    return {"greeting": f"Hello {name}"}
' > hello.py

ops action create hello-py hello.py --kind python:default
```

#### Invoking an Action

```bash
# Simple invocation
ops invoke hello

# With parameters
ops invoke hello name=Mario

# Blocking invocation (wait for result)
ops invoke hello --result

# Async invocation
ops invoke hello --async
```

#### Managing Actions

```bash
# List all actions
ops action list

# Action details
ops action get hello

# Update action
ops action update hello hello-v2.js

# Delete action
ops action delete hello

# Get public URL
ops url hello
```

### Logs and Debugging

```bash
# List recent activations
ops activations list

# Logs for a specific activation
ops logs <activation-id>

# Result of an activation
ops result <activation-id>

# Real-time logs (if available)
ops activations poll
```

### Packages (Action Grouping)

```bash
# Create package
ops package create mypackage

# List packages
ops package list

# Create action in a package
ops action create mypackage/hello hello.js

# Invoke action in package
ops invoke mypackage/hello

# Delete package
ops package delete mypackage
```

### Triggers and Rules

```bash
# Create trigger
ops trigger create mytrigger

# Create rule (connect trigger to action)
ops rule create myrule mytrigger hello

# List triggers and rules
ops trigger list
ops rule list

# Fire trigger
ops trigger fire mytrigger name=Mario

# Delete
ops rule delete myrule
ops trigger delete mytrigger
```

---

## 7. Troubleshooting {#troubleshooting}

### Common Problems

#### 1. Connection Refused

**Symptom:**
```
error: dial tcp 127.0.0.1:6443: connect: connection refused
```

**Cause:** Docker Desktop / Kubernetes not started

**Solution:**
```bash
# Start Docker Desktop
# Wait for the icon to turn green
# Verify Kubernetes
kubectl get nodes
```

#### 2. OpenServerless Not Responding

**Symptom:**
```
error: Post "http://miniops.me/api/v1/...": connection refused
```

**Cause:** OpenServerless not deployed or not active

**Solution:**
```bash
# Verify OpenServerless pods
kubectl get pods --all-namespaces

# If no OpenServerless pods
ops setup cluster

# Verify status
ops setup status
```

#### 3. User Cannot Log In

**Possible causes:**
- Wrong password
- User not created correctly
- User services not active

**Solution:**
```bash
# Verify user exists
ops admin listuser mario

# Verify namespace
kubectl get namespace mario

# Verify user pods
kubectl get pods -n mario

# Verify secrets
kubectl get secrets -n mario

# Recreate user if necessary
ops admin deleteuser mario
ops admin adduser mario mario@example.com NewPass! --all
```

#### 4. Action Won't Start

**Debug:**
```bash
# Verify action exists
ops action list

# View details
ops action get <action-name>

# Check logs for recent errors
ops activations list
ops logs <last-activation-id>

# Verify pods in namespace
kubectl get pods -n <username>
kubectl logs <pod-name> -n <username>
```

#### 5. Storage Quota Exceeded

**Check:**
```bash
# View storage usage
ops admin usage

# Detailed debug
ops admin usage --debug
```

**Solution:**
- Increase user quota (recreate user with higher quota)
- Clean old data
- Compact database: `ops admin compact`

### Complete Reset

**If nothing works:**

```bash
# 1. Reset ops
ops -reset

# 2. Uninstall OpenServerless
ops setup uninstall

# 3. Stop Docker Desktop
# 4. Clear Docker data (optional but effective)
#    Settings → Troubleshoot → Clean/Purge data

# 5. Restart Docker Desktop

# 6. Reinstall
ops setup prereq
ops setup cluster
```

### Useful Diagnostic Commands

```bash
# System info
ops -info
kubectl version
docker version

# Cluster status
kubectl get nodes
kubectl get namespaces
kubectl get pods --all-namespaces
kubectl get services --all-namespaces

# OpenServerless status
ops setup status
ops -config

# System logs
kubectl logs <pod-name> -n nuvolaris
kubectl describe pod <pod-name> -n nuvolaris

# Recent events
kubectl get events --all-namespaces --sort-by='.lastTimestamp'

# Cluster resources
kubectl top nodes
kubectl top pods --all-namespaces
```

---

## Quick Command Reference

### Initial Setup
```bash
ops setup prereq          # Validate prerequisites
ops setup cluster         # Install OpenServerless
ops setup status          # Verify installation
```

### User Management
```bash
ops admin adduser <user> <email> <pass> --all
ops admin listuser
ops admin deleteuser <user>
```

### Login and Usage
```bash
ops -login http://miniops.me <username>
ops action create <n> <file>
ops invoke <n>
ops action list
```

### Debug
```bash
kubectl get pods --all-namespaces
kubectl logs <pod> -n <namespace>
ops activations list
ops logs <activation-id>
```

---

## Resources

- **Official Documentation**: https://openserverless.apache.org
- **GitHub Repository**: https://github.com/apache/openserverless
- **Task Repository**: https://github.com/apache/openserverless-task
- **Community Support**: GitHub Issues

---

*Guide created based on practical experience with OpenServerless 0.1.0*