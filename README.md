# recurrator_setup

Infrastructure as Code for [recurrator](https://github.com/devarops/recurrator)
on DigitalOcean. One $4 droplet in `sfo2`, recreated daily at 02:30 and destroyed
at 02:00, reachable only through Tailscale.

## Pairing

| Purpose | Repository | Image |
| --- | --- | --- |
| Application | `devarops/recurrator` | `evaristor/recurrator:latest` |
| Infrastructure | `devarops/recurrator_setup` (this repo) | `evaristor/recurrator_setup:latest` |

The provisioner runs this repo's image; the image provisions the droplet and
deploys the application image.

## What it manages

**Terraform**

- Droplet `recurrator`: `sfo2`, `s-1vcpu-512mb-10gb`, `ubuntu-26-04-x64`.
- Two SSH keys: `evaro@laptop-msi` (interactive) and the provisioner key.
- Firewall: inbound TCP 22 and UDP 41641, all outbound. Port 8000 is **not**
  public; it is reachable over `tailscale0`.
- No backups, IPv6, monitoring, reserved IP, or DNS. Data lives in git and the
  name comes from Tailscale MagicDNS.

**Ansible** (`ansible/recurrator.yml`)

1. Time zone `America/Los_Angeles`.
2. 1 GiB swapfile and `vm.swappiness=10`.
3. `docker.io` + `docker-compose-v2`, Docker log rotation.
4. Tailscale: OAuth client mints a 1-hour ephemeral key, node joins as
   `recurrator`.
5. Data repo `devarops/recurrator.config` cloned to
   `/root/.config/recurrator` with a write deploy key; its `src/Cronfile` is
   installed as root's crontab.
6. `compose.prod.yml` installed at `/root/recurrator/compose.yml`;
   `docker compose pull`, `up -d`, then `make init` in the `cli` container.
7. `/openapi.json` must answer before the play succeeds.
8. Daily `docker image prune`.

**Teardown** (`--tags teardown`)

1. Final `sync.sh` (commits and pushes task changes).
2. `tailscale logout` so the node name is freed before the next recreate.

Teardown failures abort `make destroy_server` before Terraform runs, so a failed
final sync does not silently discard the day's changes. Use
`make destroy_server_force` to skip teardown.

## Layout

```
terraform/            provider, variables, droplet, firewall, outputs
ansible/recurrator.yml
compose.prod.yml      production definition copied to the droplet
Dockerfile            setup image (Terraform + Ansible)
Makefile
```

Terraform state is a local file at `/workdir/state/terraform.tfstate`; mount a
named volume at `/workdir/state` when running the image.

## Requirements

- `DIGITALOCEAN_RECURRATOR_TOKEN` in the provisioner vault (Terraform reads it
  as `DIGITALOCEAN_TOKEN`, mapped in the Makefile).
- Write-enabled deploy key for `devarops/recurrator.config` at
  `/home/geci/.vault/deploy_keys/recurrator_config`.
- Tailscale OAuth client (`auth_keys:write`, `devices:write`) and ACL tag
  `tag:recurrator`; `TAILSCALE_OAUTH_CLIENT_ID` and
  `TAILSCALE_OAUTH_CLIENT_SECRET` in the vault.
- Provisioner public key at `/home/geci/.ssh/id_rsa.pub` (or
  `id_ed25519.pub`).
- Docker Hub secrets `docker_username` and `docker_password` in this repo.

## One-time Tailscale setup

1. Admin console → Settings → OAuth clients → Generate.
2. Scopes: `auth_keys` (write) and `devices` (write).
3. Tag: `tag:recurrator`.
4. ACL tag owner:

   ```json
   "tagOwners": {
     "tag:recurrator": ["autogroup:admin"]
   }
   ```

5. Add the client ID and secret to the vault as
   `TAILSCALE_OAUTH_CLIENT_ID` and `TAILSCALE_OAUTH_CLIENT_SECRET`.

The client secret does not expire; the auth keys it mints do (1 hour). No
90-day rotation is required.

## Provisioner command

```bash
docker pull evaristor/recurrator_setup:latest
source /home/geci/.vault/.secrets
docker run --rm \
  --env DIGITALOCEAN_RECURRATOR_TOKEN \
  --env TAILSCALE_OAUTH_CLIENT_ID \
  --env TAILSCALE_OAUTH_CLIENT_SECRET \
  --volume /home/geci/.ssh:/root/.ssh \
  --volume /home/geci/.vault:/root/.vault \
  --volume recurrator_setup:/workdir/state \
  evaristor/recurrator_setup:latest
```

The default command is `make` (`create_server` + `setup_server`). For teardown,
append `make destroy_server`; to skip the final sync and logout, use
`make destroy_server_force`.

Suggested crontab entries in the provisioner (add manually):

```cron
0 2 * * * docker pull evaristor/recurrator_setup:latest && source /home/geci/.vault/.secrets && docker run --rm --env DIGITALOCEAN_RECURRATOR_TOKEN --env TAILSCALE_OAUTH_CLIENT_ID --env TAILSCALE_OAUTH_CLIENT_SECRET --volume /home/geci/.ssh:/root/.ssh --volume /home/geci/.vault:/root/.vault --volume recurrator_setup:/workdir/state evaristor/recurrator_setup:latest make destroy_server
30 2 * * * docker pull evaristor/recurrator_setup:latest && source /home/geci/.vault/.secrets && docker run --rm --env DIGITALOCEAN_RECURRATOR_TOKEN --env TAILSCALE_OAUTH_CLIENT_ID --env TAILSCALE_OAUTH_CLIENT_SECRET --volume /home/geci/.ssh:/root/.ssh --volume /home/geci/.vault:/root/.vault --volume recurrator_setup:/workdir/state evaristor/recurrator_setup:latest
```

## Make targets

| Target | Description |
| --- | --- |
| `make` | Create the droplet and provision it |
| `make create_server` | Terraform apply |
| `make setup_server` | Run the setup playbook |
| `make destroy_server` | Final sync, logout, Terraform destroy |
| `make destroy_server_force` | Terraform destroy without teardown |
| `make check` | terraform fmt/validate, ansible-lint, syntax-check |
| `make format` | `terraform fmt` |
| `make clean` | Remove `.terraform` and the lock file (not state) |

## Data repository expectations

The droplet uses the same data repo as the laptop, with these changes:

- `src/Cronfile`: no hardcoded `HOME`; schedule `*/15`; command
  `"$HOME/.config/recurrator/src/sync.sh"`.
- `src/sync.sh`: derive the repo directory from the script path, do not hardcode
  the SSH key (the `github-recurrator` SSH alias selected it), commit before
  pulling, and ping healthchecks on **every** successful run, including runs
  with no changes.

The laptop's cron should be disabled after cutover; the droplet is the only
writer in production.

## Access from the phone

The static frontend stays on the phone. Open it once as:

```
index.html?api=http://recurrator:8000
```

`public/main.js` stores that value in `localStorage`; later pages and links keep
working. The laptop continues to use `http://localhost:8000` with no Tailscale.
The static page talks to the API through the tailnet; the public interface never
sees port 8000.

## Operational notes

- **No application authentication**: access control is the tailnet and the
  firewall. Any device or user in the tailnet can read and modify
  `tasks.csv`; keep tailnet membership tight.
- **Daily downtime**: 02:00–02:30. Data made after the last 15-minute sync is
  preserved by the teardown sync, provided teardown completes.
- **Memory**: 512 MiB is enough for uvicorn and the idle `cli` container. Never
  build the application image on the droplet; CI publishes it and Ansible pulls
  it. `mutmut` belongs in CI.
- **State**: losing the `recurrator_setup` volume loses Terraform state; the
  droplet and the provisioner SSH key then need to be imported or recreated.
  The deploy key lives in the vault, not in state.
- **Known hosts**: the Makefile keeps a per-state `known_hosts` and removes the
  entry for the current IP before scanning, because DigitalOcean reuses IPs with
  new host keys.
- **Tailscale name**: teardown logs the node out. If the node is destroyed
  without logout, the ephemeral node lingers up to 48 hours and the next node
  may become `recurrator-1`.
