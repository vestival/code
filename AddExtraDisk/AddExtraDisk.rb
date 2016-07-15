#
# Victor Estival vestival@redhat.com
#
# Apache License
#

# Get vm object

begin
  @method = 'estimatecost'
  $evm.log("info", "#{@method} - EVM Automate Method: <#{@method}> Started")


vm = $evm.root['vm']
raise "Missing $evm.root['vm'] object" unless vm

# Get the size for the new disk from the root object
#size = $evm.root['size'].to_i
#$evm.log("info", "Detected size:<#{size}>")

# Add disk to a VM
#if size.zero?
#  $evm.log("error", "Size:<#{size}> invalid")
#else
#  $evm.log("info", "Creating a new #{size}GB disk on Storage:<#{vm.storage_name}>")
#  vm.add_disk("[#{vm.storage_name}]", size * 1024, :sync => true)
#end

rescue => err
  $evm.log("error", "#{@method} - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT

end
