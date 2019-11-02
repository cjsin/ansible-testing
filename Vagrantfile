# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'
settings = YAML.load_file 'playbooks/vagrant.yml'

ENV['VAGRANT_DEFAULT_PROVIDER'] = 'libvirt'

REQUIRED_PLUGINS_LIBVIRT = %w(vagrant-libvirt)

exit unless REQUIRED_PLUGINS_LIBVIRT.all? do |plugin|
    Vagrant.has_plugin?(plugin) || (
        puts "The #{plugin} plugin is required."
        false
    )
end

Vagrant.require_version ">= 2.0.2"

Vagrant.configure("2") do |config|
    config.vm.define settings['VM_NAME']
    config.vm.hostname = settings['VM_NAME']
    config.vm.box      = settings['BOX']
    config.vm.box_check_update = false
    #config.vm.network       :private_network, ip: settings['IPADDR']
    config.vm.synced_folder './',             '/vagrant',               type: 'nfs', disabled: true
    config.vm.synced_folder settings['SRCS'], settings['VAGRANT_SRCS'], type: '9p',  disabled: false, accessmode: "mapped"

    config.vm.provider "libvirt" do |v|
        v.nic_model_type = 'e1000'
        v.memory         = 1024
        v.graphics_port  = 5901
        v.graphics_ip    = '0.0.0.0'
        v.video_type     = 'qxl'
        v.input          :type => "tablet", :bus => "usb"
        v.cpus           = 1
        v.random         :model => 'random'
        v.boot           'hd'
        v.channel        :type => 'unix', :target_name => 'org.qemu.guest_agent.0', :target_type => 'virtio'
        v.channel        :type => 'spicevmc', :target_name => 'com.redhat.spice.0', :target_type => 'virtio'
    end

    #config.vm.provision "shell", privileged: true, inline: settings['VAGRANT_SRCS'] + "/provision.sh"

    config.vm.provision :ansible do |ansible|
        ansible.verbose = "v"
        ansible.playbook = "playbooks/site.yml"
        ansible.compatibility_mode = "2.0"
        ansible.become = true
        ansible.groups = {
            "testservers" => ["ans-node"],
            "testservers:vars" => {
                "APT_PROXY" => "http://192.168.121.1:3142",
                "ansible_python_interpreter" => "/usr/bin/python3"
            }
        }
        ansible.host_vars = {
            "host1" => {"blah" => 'def'},
            "comments" => "text with spaces",
            "host2" => {"blah" => 'abc'}
        }
    end
end
