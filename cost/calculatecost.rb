###################################
#
# This method returns the estimatecost of a VM to be used in a dynamic drop down list
#
# Victor Estival <vestival@redhat.com>
#
# Under the apache license
#
###################################

begin
  @method = 'estimatecost'
  $evm.log("info", "#{@method} - EVM Automate Method: <#{@method}> Started")

  #initialize variables
  #cost
  cost = {}
  #cpu of the VM
  cpu = {}
  #mem of the VM
  mem = {}
  #size of the disk
  disk = {}
  #extra disk
  extra = {}
  #total cost
  total = "0"

  #Initialize
  dialog_field={}

  # sort_by: value / description / none
  dialog_field["required"] = true

  # data_type: string / integer
  dialog_field["protected"] = false

  # required: true / false
  dialog_field["read_only"] = true
  #Populate variables with form content
  #disk = $evm.root['dialog_disksize']
  #size = $evm.root['dialog_size']
  #retirement = $evm.root['dialog_retirement'].to_i
  cpu = $evm.root['dialog_option_1_vcpu_count']
  mem = $evm.root['dialog_option_1_memory_']
  disk = $evm.root['dialog_sizebase_storage_gb']
  extra = $evm.root['dialog_option_1_add_disk1']
  cpu_price = $evm.object['cpu_price']                   # get os price per CPU from the instance
  mem_price = $evm.object['mem_price']                   # get size price per GB from the instance
  storage_price = $evm.object['storage_price']           # get storage price per GB from the instance

  cpu_price = $evm.object['cpu_price']                   # get os price per CPU from the instance
  mem_price = $evm.object['mem_price']                   # get size price per GB from the instance
  storage_price = $evm.object['storage_price']           # get storage price per GB from the instance

  total = 
  dialog_field["value"] = "Resource Group is #{rg}. Total cost is #{total}"
  $evm.log("info", "Resource Group is #{rg}. Total cost is #{total}")

  end
