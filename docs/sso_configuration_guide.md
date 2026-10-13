<!--
Licensed to the Apache Software Foundation (ASF) under one
or more contributor license agreements. See the NOTICE file
distributed with this work for additional information
regarding copyright ownership. The ASF licenses this file
to you under the Apache License, Version 2.0 (the
"License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing,
software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
KIND, either express or implied. See the License for the
specific language governing permissions and limitations
under the License.
-->

# Configuring SSO with `ops config sso`

This guide documents the public task command in the OpenServerless `0.9.0` checkout inspected on 13 October 2026 (task commit `7981be9`). The provider subcommand is `keycloak`; this command configures an existing identity provider and an OIDC-capable Admin API. It does not install Keycloak or replace the Admin API image.

Use `ops config sso`, with no leading hyphen on `config`. The legacy embedded `ops -config sso` has separate implementation and is not the command documented here.

## Before configuring SSO

- Install the SSO tasks, an OIDC-capable Admin API, and a CLI with the corresponding login support. Updating only one component is insufficient.
- Select the intended Kubernetes context and OPS configuration (`OPS_HOME`/`OPS_ROOT` where applicable). The command modifies that cluster and the local OPS configuration.
- Have permissions to manage the dedicated ConfigMap/Secret and patch the selected Admin API StatefulSet.
- Make the issuer and JWKS endpoints reachable from Admin API. For public-client device login, the CLI also contacts the identity provider.
- Configure the identity provider to issue RS256 access tokens with the expected issuer, audience, username and group claims. The required group is an exact string match, including any leading slash.
- Enable the device authorization grant for device login. If using password login, the identity provider must allow that grant (Keycloak Direct Access Grants); it does not provide the interactive browser/MFA experience.

The examples use HTTP for an isolated lab. Use HTTPS and trusted certificates for deployments carrying real credentials. Replace the sample host with an address reachable by the relevant clients and Pods; `localhost` inside an Admin API Pod is not the identity-provider host.

## Command reference

```text
ops config sso keycloak --enable --issuer-url=<issuer-url> --jwks-url=<jwks-url> (--audience=<audience>|--client-id=<client-id>) --required-group=<group> [--client-secret=<client-secret>] [--username-claim=<claim>] [--groups-claim=<claim>] [--namespace=<namespace>] [--configmap=<name>] [--secret=<name>] [--statefulset=<name>] [--container=<name>] [--no-rollout]
ops config sso show
ops config sso disable [--namespace=<namespace>] [--configmap=<name>] [--secret=<name>] [--statefulset=<name>] [--container=<name>] [--no-rollout]
```

| Option | Applies to | Default / requirement | Effect |
| --- | --- | --- | --- |
| `--enable` | `keycloak` | Required | Explicitly enables configuration |
| `--issuer-url` | `keycloak` | Required | Expected token `iss`; exact match, including URL spelling/trailing slash |
| `--jwks-url` | `keycloak` | Required | Endpoint containing public signing keys |
| `--audience` | `keycloak` | Alternative to `--client-id` | Expected token `aud`; also used as client ID when no client ID is supplied |
| `--client-id` | `keycloak` | Alternative to `--audience` | OIDC client ID; also used as expected audience |
| `--required-group` | `keycloak` | Required | Exact group required for access |
| `--client-secret` | `keycloak` | Omitted: public client | Stores `OIDC_CLIENT_SECRET` in the dedicated Kubernetes Secret; selects confidential-client mode locally |
| `--username-claim` | `keycloak` | `preferred_username` | Top-level token claim used as the username |
| `--groups-claim` | `keycloak` | `groups` | Top-level token claim containing the required group; list or single string |
| `--namespace` | `keycloak`, `disable` | `openserverless` | Kubernetes namespace containing the resources to manage |
| `--configmap` | `keycloak`, `disable` | `openserverless-sso-config` | Dedicated SSO ConfigMap name |
| `--secret` | `keycloak`, `disable` | `openserverless-sso-secret` | Dedicated SSO Secret name; this is a resource name, not the secret value |
| `--statefulset` | `keycloak`, `disable` | `openserverless-system-api` | Admin API StatefulSet to patch |
| `--container` | `keycloak`, `disable` | `openserverless-system-api` | Container within that StatefulSet |
| `--no-rollout` | `keycloak`, `disable` | False | Suppresses explicit restart/wait on enable, or waiting on disable; does not prevent Kubernetes rolling out a changed Pod template |

The public synopsis makes `--audience` and `--client-id` alternatives. Use one. The task consequently sets both `OIDC_AUDIENCE` and `OIDC_CLIENT_ID` to that value for this interface. A separate audience/client-ID pair is not a documented CLI combination.

Claim names are literal top-level keys; `--groups-claim=realm_access.roles` does not navigate a nested object. Configure an appropriate claim in the provider instead.

## Public-client example

Assume a lab realm `ops`, client `ops-cli`, a token audience containing `ops-cli`, and group claim containing `/ops-users`:

```bash
ops config sso keycloak --enable \
  --issuer-url=http://keycloak.lab:8080/realms/ops \
  --jwks-url=http://keycloak.lab:8080/realms/ops/protocol/openid-connect/certs \
  --client-id=ops-cli \
  --required-group=/ops-users
```

The JWKS endpoint must belong to that issuer. The command checks required values but does not prove the issuer, signing keys, grants or claim mapping are correct; verify an actual login afterwards.

## Confidential-client example

Use the same full command and supply the client secret. In Bash, prompt instead of placing a literal secret in shell history:

```bash
read -r -s -p 'OIDC client secret: ' oidc_client_secret
printf '\n'
ops config sso keycloak --enable \
  --issuer-url=http://keycloak.lab:8080/realms/ops \
  --jwks-url=http://keycloak.lab:8080/realms/ops/protocol/openid-connect/certs \
  --client-id=ops-cli \
  --required-group=/ops-users \
  --client-secret="$oidc_client_secret"
unset oidc_client_secret
```

The task stores the value in Kubernetes and only stores a configured/not-configured flag locally. The value still passes as a process argument; run the command from an appropriate administrative environment and avoid shell tracing.

To change claims, add, for example, `--username-claim=email --groups-claim=ops_groups` to the full enable command, after arranging those claims in the provider.

## Alternate Kubernetes resource names

Append these options to a complete enable command when the workload uses different names:

```text
--namespace=ops-lab
--configmap=ops-lab-sso-config
--secret=ops-lab-sso-secret
--statefulset=ops-lab-system-api
--container=system-api
```

These select the resources patched by this task; they do not reconfigure the Admin API's internal provisioning namespace or CRD API group. Verify those separately before deploying OPS outside its standard namespace.

Choose dedicated ConfigMap and Secret names. The task owns them and deletes them on disable. If changing names, clean up the old managed configuration explicitly first: selecting new names does not garbage-collect previous resources and references. The implementation can fall back to saved local resource names, but explicitly supplying custom names avoids ambiguity from CLI defaults and different workstations.

## What enable changes

1. Applies the dedicated ConfigMap with OIDC configuration and the provisioning defaults below.
2. Applies the dedicated Secret if `--client-secret` is supplied; otherwise deletes that Secret if present.
3. Adds exact, prefix-free `envFrom` references to the selected container.
4. Saves non-secret SSO settings locally, including `SSO_ENABLED=true`, provider, client mode and resource names.
5. Unless `--no-rollout` is used, restarts the StatefulSet and waits up to 180 seconds for rollout.

Re-running enable requires the complete required options. In particular, omitting `--client-secret` changes to public mode and removes the managed Secret; it does not preserve the previous secret. Use the complete command to rotate a client secret.

A ConfigMap-only update does not change an existing process's environment. With `--no-rollout`, arrange a later restart if the Pod template did not change:

```bash
kubectl -n openserverless rollout restart statefulset/openserverless-system-api
kubectl -n openserverless rollout status statefulset/openserverless-system-api --timeout=180s
```

## Provisioning defaults written by the task

These are generated settings, **not additional command-line options**:

| Setting | Value |
| --- | --- |
| `SSO_AUTOPROVISION_ON_LOGIN` | `true` |
| `SSO_AUTOPROVISION_TIMEOUT_SECONDS` | `120` |
| `SSO_AUTOPROVISION_POLL_SECONDS` | `2` |
| `SSO_AUTOPROVISION_DEFAULT_SERVICES` | `all` |
| `SSO_NAMESPACE_PRESERVE_VALID` | `true` |
| `SSO_NAMESPACE_HASH_LENGTH` | `8` |
| `SSO_NAMESPACE_MAX_LENGTH` | `61` |

These configure login-triggered provisioning and username-to-namespace mapping. Every enable invocation writes these values again. The command exposes no `--autoprovision`, `--timeout` or `--default-services` override. A successful IdP login can still fail OPS login if provisioning fails or exceeds its timeout.

## Inspect and test

```bash
ops config sso show
kubectl -n openserverless get configmap openserverless-sso-config -o yaml
kubectl -n openserverless get secret openserverless-sso-secret
kubectl -n openserverless rollout status statefulset/openserverless-system-api --timeout=180s
```

`show` prints local `SSO_*` settings; it does not read the live cluster or validate login. A missing Secret is expected for public mode. Do not export Secret contents into support logs.

On the configured client, use device login:

```bash
OPS_APIHOST=http://miniops.me ops -login
```

Confidential mode delegates device authorization to Admin API; public mode uses the CLI's direct device flow. Follow the displayed verification URL/code. On a headless client, add `OPS_SSO_DISABLE_BROWSER=true` to avoid opening a browser automatically.

For a provider configured to allow password grant:

```bash
OPS_APIHOST=http://miniops.me ops -login --sso-flow password --sso-username alice
```

The CLI prompts for the password unless `OPS_PASSWORD` is supplied. `OPS_SSO_LOGIN_FLOW=password` and `OPS_SSO_USERNAME` are the corresponding environment controls. These are login settings, not `ops config sso` flags.

For an application workspace, use `ops ide login` with its usual OPS API host and login profile. To select password flow through that task, use `OPS_SSO_LOGIN_FLOW=password ops ide login`. Keep provider identity and requested OPS namespace distinct when they differ. A positional namespace on backend-managed device login requests an explicit workspace binding; omit it when the server should resolve the user's namespace.

On a different workstation, configure its CLI for SSO as well: server-side configuration does not copy local `SSO_*` settings to other clients. Do not run the administrative configuration command from every developer machine merely to select a login mode, and never distribute the confidential client secret to developers.

## Disable

```bash
ops config sso disable
```

For custom resources, specify the same names used on enable:

```bash
ops config sso disable \
  --namespace=ops-lab \
  --configmap=ops-lab-sso-config \
  --secret=ops-lab-sso-secret \
  --statefulset=ops-lab-system-api \
  --container=system-api
```

Disable removes the task's exact `envFrom` references, deletes its dedicated ConfigMap/Secret, and removes its recognized local settings. Repeating disable is safe when the dedicated resources are already absent. It still requires the target StatefulSet/container to exist.

Other `envFrom` references, direct `env` entries, volumes and mounts are preserved. Therefore manually injected OIDC variables can remain active; inspect them if SSO still appears enabled. Disable does not delete the IdP, previously provisioned users, application data or revoke issued OPS API keys. By default it waits for rollout only if it changed the container references.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| `no command named sso found` | Active `OPS_ROOT` lacks the SSO tasks; inspect `ops -info` |
| `missing --enable` or another required value | Use the complete `keycloak --enable` form |
| StatefulSet/container not found | Kubernetes context and resource options |
| Login still uses legacy credentials | Local `SSO_ENABLED` and the active OPS configuration |
| Invalid issuer or audience | Exact `iss` and `aud` in the token and configured client/audience |
| Missing required group | Exact group value, group mapper and top-level claim name |
| Unsupported algorithm | This validator accepts RS256 |
| Device authorization unavailable | Provider device grant, endpoint reachability and client mode |
| Password grant rejected | Provider grant policy, identity-provider username/password and client configuration |
| Provisioning timeout | Admin API/operator logs and WhiskUser readiness; rollout success alone is not a login test |
| Settings appear unchanged after `--no-rollout` | Restart the selected StatefulSet after ConfigMap-only changes |

## Implementation references

- [Public CLI synopsis](../oplugins/config/sso/docopts.md)
- [Task option binding](../oplugins/config/sso/opsfile.yml)
- [Resource management and defaults](../oplugins/config/sso/sso.ts)
- [CLI login](../cli/auth/login.go)
- [Token validation](../admin-api/openserverless/common/oidc_validator.py)
- [Existing SSO integration test documentation](../testing/docs/SSO.md)
