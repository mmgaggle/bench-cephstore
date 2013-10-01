# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure('2') do |config|

  config.vm.box = "precise64"
  config.ssh.forward_agent = true

  file_to_disk = './tmp/bench_disk.vdi'
  config.vm.provider :virtualbox do |vb|
    vb.customize ['modifyvm', :id, '--memory', '1024']
    vb.customize ['createhd', '--filename', file_to_disk, '--size', 4096]
    vb.customize ['storageattach', :id, '--storagectl', 'SATA Controller', '--port', 1, '--device', 0, '--type', 'hdd', '--medium', file_to_disk]
  end

end
