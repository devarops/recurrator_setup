SHELL := /bin/bash

TF_DIR := terraform
STATE_DIR := /workdir/state
KNOWN_HOSTS := $(STATE_DIR)/known_hosts
PLAYBOOK := ansible/recurrator.yml
IP = $$(cd $(TF_DIR) && terraform output -raw ip)
DIGITALOCEAN_ENV = export DIGITALOCEAN_TOKEN=$${DIGITALOCEAN_RECURRATOR_TOKEN};

.PHONY: \
	all \
	check \
	clean \
	create_server \
	destroy_server \
	destroy_server_force \
	format \
	init \
	setup_server

all: create_server setup_server

init:
	mkdir --parents $(STATE_DIR)
	cd $(TF_DIR) && terraform init

create_server: init
	$(DIGITALOCEAN_ENV) cd $(TF_DIR) && terraform apply -auto-approve

setup_server: init
	IP=$(IP); \
	for attempt in $$(seq 1 60); do \
		ssh-keyscan "$$IP" > /tmp/recurrator_host_key 2>/dev/null && [ -s /tmp/recurrator_host_key ] && break; \
		sleep 5; \
	done; \
	test -s /tmp/recurrator_host_key; \
	ssh-keygen -R "$$IP" -f $(KNOWN_HOSTS) >/dev/null 2>&1 || true; \
	cat /tmp/recurrator_host_key >> $(KNOWN_HOSTS); \
	ANSIBLE_HOST_KEY_CHECKING=True \
	ANSIBLE_SSH_ARGS="-o UserKnownHostsFile=$(KNOWN_HOSTS)" \
	ansible-playbook -i "$$IP," -u root --tags setup $(PLAYBOOK)

destroy_server: init
	IP=$(IP); \
	ssh-keygen -R "$$IP" -f $(KNOWN_HOSTS) >/dev/null 2>&1 || true; \
	ssh-keyscan "$$IP" >> $(KNOWN_HOSTS); \
	ANSIBLE_HOST_KEY_CHECKING=True \
	ANSIBLE_SSH_ARGS="-o UserKnownHostsFile=$(KNOWN_HOSTS)" \
	ansible-playbook -i "$$IP," -u root --tags teardown $(PLAYBOOK)
	$(DIGITALOCEAN_ENV) cd $(TF_DIR) && terraform destroy -auto-approve

destroy_server_force: init
	$(DIGITALOCEAN_ENV) cd $(TF_DIR) && terraform destroy -auto-approve

check:
	cd $(TF_DIR) && terraform fmt -check
	cd $(TF_DIR) && terraform init -backend=false
	cd $(TF_DIR) && terraform validate
	ansible-lint $(PLAYBOOK)
	ansible-playbook --syntax-check -i localhost, $(PLAYBOOK)

format:
	cd $(TF_DIR) && terraform fmt

clean:
	rm --force --recursive $(TF_DIR)/.terraform
