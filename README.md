# recurrator_setup

A private home for recurrator on DigitalOcean.

## What it does

Creates and configures the server that runs recurrator, deploys the application
image, and keeps the task list in a private git repository. The server is
destroyed for thirty minutes each night and rebuilt, so every day starts from the
same code. Only devices on your Tailscale network can reach the app; there is no
application login, so that network is the protection.

## How to use it

1. The provisioner runs the setup image, which creates the server and provisions
   it.
2. The setup image pulls the latest recurrator application and starts it.
3. On a phone or laptop in the tailnet, open the static frontend once as
   `public/index.html?api=http://recurrator:8000`.
4. Use the app normally; task changes sync to the data repository every 15
   minutes.

## Before you start

- A DigitalOcean account token.
- A Tailscale tailnet with MagicDNS and an OAuth client tagged `tag:recurrator`;
  the ACL must allow that tag and grant auth-key and device management.
- A write deploy key for the private task-data repository.
- Docker Hub credentials allowed to publish the setup image.
- An SSH key on the provisioner.

The exact secret locations and verification commands are in `AGENTS.md`.

## Run the project

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

The default command provisions the server. Append `make destroy_server` to remove
it; `make destroy_server_force` removes it without the final data sync. Run the
destroy form at 02:00 and the default form at 02:30 on the provisioner.

The setup image is rebuilt and published by CI on every push to `develop`.
