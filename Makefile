PLAYBOOKS := playbooks
PLAYBOOK  := $(PLAYBOOKS)/site.yml
INVENTORY   :=  $(PWD)/.vagrant/provisioners/ansible/inventory
ANS_VERBOSE ?=
ANS_CONN    := --connection=ssh --timeout=30
ANS_REMOTE  := ansible-playbook $(ANS_CONN)  $(ANS_VERBOSE) --become --inventory-file=$(INVENTORY)
TEST_NODE   := ans-node
export ANSIBLE_SSH_ARGS = '-o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ControlMaster=auto -o ControlPersist=60s'
export PYTHONUNBUFFERED = 1
export ANSIBLE_NOCOLOR  = false
export ANSIBLE_HOST_KEY_CHECKING = false

facts:
	ansible -m setup ans-node

provision:
	vagrant provision

lint:
	ansible-lint $(PLAYBOOK)
	#ansible-playbook --syntax-check $(PLAYBOOK) -i all

play:
	 $(ANS_REMOTE) --limit="$(TEST_NODE)" $(PLAYBOOK) $(TAGS)

