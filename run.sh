#!/usr/bin/env bash

ansible-galaxy install -r requirements.yml
ansible-playbook -K --ask-vault-pass -i inventory.yml main.yml
