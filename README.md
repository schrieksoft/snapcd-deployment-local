# snapcd-deployment-local

Reference local-binary deployment for [Snap CD](https://snapcd.io). Runs the Snap CD **Server**, **Runner** and **Agent** as native processes on your machine — no Docker, no Kubernetes — by downloading the published release zips from GitHub and pointing them at the configs in this repo.

This is the right deployment shape when:

- You want a **Runner** or **Agent** on a workstation, VM or jump host connected to Snap CD Cloud at <https://snapcd.io>.
- You want to spin up a quick **all-in-one Self-Hosted** stack for evaluation on a single machine without container tooling.
- You're developing against a Self-Hosted Server and want to attach a real Runner / Agent without bringing Docker into the loop.

For long-running production deployments, prefer [snapcd-deployment-docker](https://github.com/schrieksoft/snapcd-deployment-docker) or [snapcd-deployment-kubernetes](https://github.com/schrieksoft/snapcd-deployment-kubernetes).

| You want…                                                                  | What to run                                                    |
|----------------------------------------------------------------------------|----------------------------------------------------------------|
| **All three components** on this machine                                    | `./install-all.sh && ./run-all.sh`                              |
| **Just the Server**                                                         | `./components/server/install.sh && ./components/server/run.sh`  |
| **Just a Runner** (you use Snap CD Cloud)                                   | `./components/runner/install.sh && ./components/runner/run.sh`  |
| **Just an Agent** (you use Snap CD Cloud)                                   | `./components/agent/install.sh && ./components/agent/run.sh`    |

## What lives where

```
snapcd-deployment-local/
├── versions.env                    # SNAPCD_VERSION=1.3.1 — pinned release tag
├── install-all.sh                  # Calls each component's install.sh
├── run-all.sh                      # Runs all three with logs under .logs/
├── components/
│   ├── server/
│   │   ├── install.sh             # Downloads snapcd-server-<version>.zip into bin/
│   │   ├── run.sh                 # Links config, execs SnapCd.Server.Host
│   │   └── config/appsettings.json
│   ├── runner/
│   │   ├── install.sh
│   │   ├── run.sh                 # Same pattern; also sets working-directory env vars
│   │   ├── preapproved-hooks/sample.sh
│   │   └── config/appsettings.json
│   └── agent/
│       ├── install.sh             # Installs orchestrator + Claude sidecar
│       ├── run.sh                 # Brings up both with cleanup on Ctrl-C
│       └── config/appsettings.json
```

Each `install.sh` reads the pinned version from `versions.env`, downloads `snapcd-<component>-<version>.zip` from <https://github.com/schrieksoft/snapcd/releases>, unzips into `components/<component>/bin/`, and chmods the entry-point binary. To pin a different version for a one-off install, set `VERSION=<x.y.z>` in the environment:

```bash
VERSION=0.1.13 ./components/runner/install.sh
```

## Bringing up the full stack

The Server needs **SQL Server** and **Redis**. The simplest local quickstart is to run both as one-shot Docker containers (this repo doesn't manage them — you can also install them natively):

```bash
docker run -d --name sqlserver \
  -e "ACCEPT_EULA=Y" -e "SA_PASSWORD=myPassw0rd" -e "MSSQL_PID=Express" \
  -p 1433:1433 mcr.microsoft.com/mssql/server:2022-latest

docker run -d --name redis -p 6379:6379 redis:7-alpine
```

> The shipped `components/server/config/appsettings.json` references `localhost:1433` and `localhost:6379` with the password `myPassw0rd`. If you install SQL Server / Redis natively or change the credentials, update the `ConnectionString` and `Caching.ConnectionString` to match.

Then install and run:

```bash
./install-all.sh
./run-all.sh
```

`run-all.sh` writes per-component logs into `.logs/` and waits for `http://localhost:5000/healthz` before bringing up the Runner and Agent. Stop with Ctrl-C — all three processes shut down cleanly.

Once the Server is up, sign in at <http://localhost:5000> with the pre-seeded credentials:

- **Email:** `admin@preseeded.io`
- **Password:** `Admin#123`

> Change this password before you put the deployment in front of anything that matters.

The Runner and Agent both register automatically using the `default` / `defaultAgent` Service Principals pre-seeded by the Server on first start.

## Bringing up a single component

### Server (only)

```bash
./components/server/install.sh
./components/server/run.sh
```

You need SQL Server and Redis reachable at the addresses configured in `components/server/config/appsettings.json` (defaults: `localhost:1433` and `localhost:6379`). Edit the JSON to:

- Replace the dev RSA / AES keys with your own (`OpenIdConnect.TokenSigning.RsaPrivateKey` / `RsaPublicKey`, `OpenIdConnect.TokenEncryption.SymmetricKey`, `SecretStore.SqlServer.SymmetricKey`) — see the [Server settings docs](https://docs.snapcd.io/components/server/#settings).
- Configure an `EmailSender` so users can self-serve password resets and invitations.
- Configure `OpenIdConnect.ExternalLoginProviders` for SSO sign-in.

#### Generate fresh signing keys

```bash
openssl genrsa -out token-signing.key 2048
openssl rsa -in token-signing.key -pubout -out token-signing.pub
openssl rand -base64 32   # AES-256 key (run twice — once for token encryption, once for SecretStore)
```

Paste the PEM contents into the JSON as a single string with literal `\n` separators (the shipped file shows the exact shape).

### Runner (only) — pointed at Snap CD Cloud

```bash
./components/runner/install.sh
./components/runner/run.sh
```

Equivalent to running the binary directly:

```bash
VERSION=$(. versions.env; echo "$SNAPCD_VERSION")
curl -L -o snapcd-runner.zip \
  https://github.com/schrieksoft/snapcd/releases/download/$VERSION/snapcd-runner-$VERSION.zip
unzip snapcd-runner.zip -d snapcd-runner
chmod +x snapcd-runner/SnapCd.Runner
(cd snapcd-runner && ./SnapCd.Runner)
```

Edit `components/runner/config/appsettings.json`:

- Set `Server.Url` to `https://snapcd.io` (or your Self-Hosted Server's URL).
- Set `Runner.Id`, `Runner.OrganizationId`, `Runner.Credentials.ClientId` and `Runner.Credentials.ClientSecret` to the values shown when you registered the Runner in the Dashboard.

`run.sh` overrides the runner's working-directory paths to point at `components/runner/runnerdata/` (created on first run, gitignored) and points the pre-approved-hooks directory at `components/runner/preapproved-hooks/`.

#### SSH for private Git repos

The Runner runs as your user, so it picks up `~/.ssh/id_rsa` and `~/.ssh/known_hosts` automatically. Make sure your SSH agent / key file is reachable, and that the relevant hosts are in `known_hosts`:

```bash
ssh-keyscan github.com gitlab.com >> ~/.ssh/known_hosts
```

#### Pre-approved hooks

Drop approved hook scripts into `components/runner/preapproved-hooks/` and flip `HooksPreapproval.Enabled` to `true` in `components/runner/config/appsettings.json`.

#### Engine binaries

The Runner shells out to `terraform` / `tofu` / `pulumi` from your `PATH`. Install whichever you use:

```bash
# OpenTofu
curl -L -o /tmp/tofu.zip https://github.com/opentofu/opentofu/releases/download/v1.8.8/tofu_1.8.8_linux_amd64.zip
sudo unzip /tmp/tofu.zip -d /usr/local/bin

# Terraform
curl -L -o /tmp/terraform.zip https://releases.hashicorp.com/terraform/1.5.7/terraform_1.5.7_linux_amd64.zip
sudo unzip /tmp/terraform.zip -d /usr/local/bin
```

> Snap CD strives to support the latest available version of `tofu`. For `terraform` we design for binaries up to release [1.5.7](https://github.com/hashicorp/terraform/releases/tag/v1.5.7), the final release under the [Mozilla Public License 2.0](https://github.com/hashicorp/terraform/blob/v1.5.7/LICENSE).

### Agent (only) — pointed at Snap CD Cloud

```bash
./components/agent/install.sh
./components/agent/run.sh
```

`install.sh` downloads two artifacts: the orchestrator (`snapcd-agent-<version>.zip`) and the Claude sidecar (`snapcd-agent-sidecar-claude-<version>.zip`). The sidecar artifact **is not yet published by the upstream Snap CD release pipeline** (tracked as TODO §27.2 in `ai-agent-plan.md`); until that lands, the sidecar install step prints a warning and `run.sh` will start the orchestrator without it. The orchestrator will fail any mission that needs the Claude sidecar in that state.

Edit `components/agent/config/appsettings.json`:

- Set `Server.Url` to `https://snapcd.io` (or your Self-Hosted Server's URL).
- Set `Agent.AgentId`, `Agent.OrganizationId`, `Agent.ClientId` and `Agent.ClientSecret` to the values shown when you registered the Agent.

The sidecar needs exactly one Anthropic credential, exported before launching:

```bash
# A Claude subscription token…
export CLAUDE_CODE_OAUTH_TOKEN=sk-ant-oat01-…
# …or an Anthropic API key instead. Set one, not both.
export ANTHROPIC_API_KEY=sk-ant-api03-…
# Optional: a GitHub PAT, used by the sidecar's git/gh for the AutoFix path.
export GITHUB_TOKEN=ghp_…

./components/agent/run.sh
```

`run.sh` passes all three through to the sidecar. With neither credential set the sidecar still starts and only fails when a mission calls for inference, so a running process is not evidence that the credential landed.

`run.sh` also sets `SNAPCD_BASE_URL` (defaulting to `http://localhost:5000`, `/mcp` is appended), which the sidecar uses to reach the Server for MCP. Override it if your Server is elsewhere — it must match `Server.Url` in `appsettings.json`. The sidecar refuses to start without it, which surfaces as the orchestrator failing to connect on port 7001.

The sidecar listens on port `7001` by default (override with `SIDECAR_PORT=… ./components/agent/run.sh`); the orchestrator finds it via `Agent.Sidecars[0].BaseUrl=http://localhost:7001` in `appsettings.json`.

## Running as a long-lived service

The supplied scripts are foreground processes — convenient for evaluation, but not for production. For a long-running deploy on a single machine, wrap each `run.sh` in a systemd unit:

```ini
# /etc/systemd/system/snapcd-runner.service
[Unit]
Description=Snap CD Runner
After=network.target

[Service]
Type=simple
User=snapcd
WorkingDirectory=/opt/snapcd-deployment-local/components/runner
ExecStart=/opt/snapcd-deployment-local/components/runner/run.sh
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now snapcd-runner
journalctl -u snapcd-runner -f
```

Repeat for `snapcd-server.service` and `snapcd-agent.service` as needed.

## Updating to a new release

1. Edit `versions.env` and bump `SNAPCD_VERSION`.
2. Re-run the relevant install script (or `./install-all.sh` for everything).
3. Restart the component (Ctrl-C on `run.sh`, or `systemctl restart snapcd-<component>`).

Old binaries are wiped from `bin/` on each install — there's no in-place upgrade.

## Licensing

Snap CD Self-Hosted is distributed under the [Snap CD Source-Available License](https://github.com/schrieksoft/snapcd/blob/main/applications/snapcd/LICENSE.md). This deployment repository is published separately under its own license — see the upstream Snap CD documentation for tier comparisons and how to obtain a license token.
