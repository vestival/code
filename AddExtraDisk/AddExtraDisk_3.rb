#
# Victor Estival vestival@redhat.com
#
# Apache License
#

begin
  $evm.log("info", "EVM Automate Method Started")

  # Dump all of root's attributes to the log
  $evm.root.attributes.sort.each { |k, v| $evm.log("info", "Root:<$evm.root> Attribute - #{k}: #{v}")}

  prov=$evm.root["miq_provision"]

  disk_20_quantity = prov.get_option(:disk_size_1)_to.i
  disk_50_quantity = prov.get_option(:disk_size_2)_to.i

  $evm.log("info","Amount of disks: #{disk_20_quantity} x 20GB and #{disk_50_quantity} x 50GB")

  # Get vm object
  vm = $evm.root['vm']
  raise "Missing $evm.root['vm'] object" unless vm
  $evm.log("info","VM is #{vm} "
  
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