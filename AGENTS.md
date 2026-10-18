# Developer Guidelines & Project Standards

This repository provisions the DigitalOcean droplet that runs recurrator. The application lives in devarops/recurrator; the images are evaristor/recurrator and evaristor/recurrator_setup. Do not clone the app or build its image on the droplet.

## Layout

- `terraform/` owns the droplet, firewall, and SSH keys.
- `ansible/recurrator.yml` has two tagged plays: `setup` and `teardown`.
- `compose.prod.yml` is copied to `/root/recurrator/compose.yml` on the droplet.
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
- Tailscale uses an OAuth client (`TAILSCALE_OAUTH_CLIENT_ID` and `TAILSCALE_OAUTH_CLIENT_SECRET`) with `auth_keys` and `devices` write scopes to mint a one-hour ephemeral key. The ACL tag is `tag:recurrator`, and the ACL must declare a tag owner for it; the client can only mint keys for tags it owns. Do not replace this with a 90-day auth key.
- The data repository deploy key is read from `/root/.vault/deploy_keys/recurrator_config`; the provisioner mounts `/home/geci/.vault` at `/root/.vault`.
- The provisioner SSH key is `/root/.ssh/id_rsa.pub`, falling back to `/root/.ssh/id_ed25519.pub`.

## Deployment constraints

- Image-only: Ansible pulls `evaristor/recurrator:latest`; the app generates its gitignored modules at container start. Never add an app checkout or bind mount.
- Persistence is the private data repo `devarops/recurrator.config` at `/root/.config/recurrator`. Do not introduce a DigitalOcean block-storage volume.
- The API has no authentication. The firewall allows only TCP 22 and UDP 41641; port 8000 is reachable only through Tailscale. Never add 8000 to the firewall.
- The droplet is 512 MiB. Swap is required, `mutmut` is out, and image builds belong in CI.
- The sync `Cronfile` and `sync.sh` are shared with the laptop. Keep them free of hardcoded `HOME`, repository paths, and SSH key paths.
- Teardown logs the Tailscale node out so the name `recurrator` is free for the next create. Do not remove that task.
- DigitalOcean reuses IPs with new host keys; the Makefile keeps a per-state `known_hosts` and removes the current IP before scanning.

## CI and commits

- `.github/workflows/actions.yml` builds the setup image, runs `make check` inside it, and pushes `latest` plus a short SHA to Docker Hub on pushes to `develop`.
- Commits use a gitmoji followed by an imperative summary.
- Cross-repo deploy blockers are listed in the app repository's `TODO.md`.
