#
# Victor Estival vestival@redhat.com
#
# Apache License
#

begin
  $evm.log("info", "EVM Automate Method Started")
  # Dump all of root's attributes to the log
  $evm.root.attributes.sort.each { |k, v| $evm.log("info", "Root:<$evm.root> Attribute - #{k}: #{v}")}
  # Using miq_provision
  prov=$evm.root["miq_provision"]
  # Dump all attributes to the log
  prov.attributes.sort.each { |k, v| $evm.log("info", "#{@method} Provision: Attribute - #{k}: #{v}")}
  # Populate amount of disks per typr
  disk_20_quantity = prov.get_option(:disk_size_1).to_i
  disk_50_quantity = prov.get_option(:disk_size_2).to_i
  $evm.log("info","Amount of disks: #{disk_20_quantity} x 20GB and #{disk_50_quantity} x 50GB")
  # Get vm object
  vm = prov.vm
  $evm.log("info","VM is #{vm}")
  # Adding disks
  i = 0
  while i < disk_20_quantity do
    size = 20
    $evm.log("info", "Creating a new #{size}GB disk on Storage:<#{vm.storage_name}>")
    vm.add_disk("[#{vm.storage_name}]", size * 1024, :sync => true)
    i += 1
  end
  i = 0
  while i < disk_50_quantity do
    size = 50
    $evm.log("info", "Creating a new #{size}GB disk on Storage:<#{vm.storage_name}>")
    vm.add_disk("[#{vm.storage_name}]", size * 1024, :sync => true)
    i += 1
  end
  #
  # Exit method
  #
  $evm.log("info", "EVM Automate Method Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end
