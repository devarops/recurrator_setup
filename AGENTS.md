# Developer Guidelines & Project Standards

This repository provisions the DigitalOcean droplet that runs recurrator. The API lives in devarops/recurrator, the browser client in devarops/recurrator.web, and the images are evaristor/recurrator, evaristor/recurrator.web and evaristor/recurrator_setup. Do not clone either app or build their images on the droplet.

## Layout

- `terraform/` owns the droplet, firewall, and SSH keys.
- `ansible/recurrator.yml` has two tagged plays: `setup` and `teardown`.
- `compose.prod.yml` is copied to `/root/recurrator/compose.yml` on the droplet, and `gateway.conf` sits beside it.
- `Dockerfile` builds the setup image (Terraform and Ansible) and defaults to `make`.
- `README.md` is the operator guide and holds the provisioner command.

## Commands

- `make` = `make create_server` + `make setup_server`.
- `make check` runs `terraform fmt -check`, `terraform init -backend=false`, `terraform validate`, `ansible-lint`, and `ansible-playbook --syntax-check`. CI runs it inside the setup image.
- `make destroy_server` runs the teardown play (final data sync, `tailscale logout`) and then `terraform destroy`. It stops before destroy if teardown fails; `make destroy_server_force` skips teardown.
- `make format` runs `terraform fmt`.
- There are no unit tests; `make check` and a real `terraform plan` are the verification.

## State and credentials

- `DIGITALOCEAN_RECURRATOR_TOKEN` is mapped to `DIGITALOCEAN_TOKEN` by the Makefile.
- Terraform state is local to the setup image and must be mounted from outside, or every run starts blind; the volume name is in the README command.
- Tailscale uses an OAuth client (`TAILSCALE_OAUTH_CLIENT_ID` and `TAILSCALE_OAUTH_CLIENT_SECRET`) with `auth_keys` and `devices` write scopes to mint a one-hour ephemeral key. The ACL tag is `tag:recurrator`, and the ACL must declare a tag owner for it; the client can only mint keys for tags it is permitted to grant ([Tailscale OAuth clients](https://tailscale.com/kb/1215/oauth-clients)). Do not replace this with a 90-day auth key.
- The data repository deploy key is read from `/root/.vault/deploy_keys/recurrator_config`; the provisioner mounts `/home/geci/.vault` at `/root/.vault`.
- The provisioner SSH key is `/root/.ssh/id_rsa.pub`, falling back to `/root/.ssh/id_ed25519.pub`.

## Deployment constraints

- Image-only: Ansible pulls `evaristor/recurrator:latest` and `evaristor/recurrator.web:latest` and starts them; the API generates its gitignored modules at container start and the editable install is baked into the image, so deployment runs no `make` step. Never add an app checkout or bind mount.
- Persistence is the private data repo `devarops/recurrator.config` at `/root/.config/recurrator`. Do not introduce a DigitalOcean block-storage volume.
- The API has no authentication. The firewall allows only TCP 22 and UDP 41641; port 80 is reachable only through Tailscale. Never add 80 to the firewall.
- Three services: `gateway` (stock nginx, owns host `:80`), `web` (the static client image), and `api` (internal `:8000`, never published). The gateway sends `/api/` straight to `api` and everything else to `web`, so the browser and the API share one origin and the frontend carries no API address.
- The gateway resolves its upstreams through Docker DNS with variables, so it starts even when `web` is absent. With `web` stopped, `/api/*` still answers and `/` returns 502; the terminal client depends on `gateway` and `api` only. Never publish the API on a host port.
- Only `api` mounts `/root/.config/recurrator`; `web` and `gateway` mount nothing but their configuration.
- The droplet is 512 MiB. Swap is required, `mutmut` is out, and image builds belong in CI.
- The sync `Cronfile` and `sync.sh` are shared with the laptop. Keep them free of hardcoded `HOME`, repository paths, and SSH key paths.
- Teardown logs the Tailscale node out so the name `recurrator` is free for the next create. Do not remove that task.
- DigitalOcean reuses IPs with new host keys; the Makefile keeps a per-state `known_hosts` and removes the current IP before scanning.
- The readiness checks in the setup play request the host address on port 80 through the gateway (`/api/openapi.json` and `/`), while the container healthcheck probes `127.0.0.1:8000/api/openapi.json` inside the API container; changing either path means changing both.

## CI and commits

- `.github/workflows/actions.yml` builds the setup image, runs `make check` inside it, and pushes `latest` plus a short SHA to Docker Hub on pushes to `develop`.
- Commits use a gitmoji followed by an imperative summary.
- Cross-repo deploy blockers are listed in the app repository's `TODO.md`.
