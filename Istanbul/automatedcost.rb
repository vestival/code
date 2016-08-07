###################################
#
# This method returns the list of data stores to be used in a dynamic drop down list
#
# install xmlsimple with "gem install xml-simple"
#
###################################

begin
  @method = 'estimatecost'
  $evm.log("info", "#{@method} - EVM Automate Method: <#{@method}> Started")

  #initialize variables
  #cost for size
  cost = {}
  #cost for disk
  cost2 = {}
  #size of the VM
  size = {}
  #size of the disk
  disk = {}
  #total cost
  total = {} 
  #Populate variables with form content
  disk = $evm.root['dialog_disksize']
  size = $evm.root['dialog_size']
  retirement = $evm.root['dialog_retirement'].to_i
  
  #Evaluate cost based on the size of the VM
  case size
   when "small"
    cost = "10"
    $evm.log("info", "Size #{size}, cost #{cost}")
   when "medium"
    cost = "20"
    $evm.log("info", "Size #{size}, cost #{cost}")
   when "large"
    cost = "50"
    $evm.log("info", "Size #{size}, cost #{cost}")
  end
    
  #Evaluate cost based on the size of the disk
  case disk
   when "0"
    cost2 = "0"
    total = cost.to_i + cost2.to_i    
    $evm.log("info", "Disk Size #{cost2} no extra cost")
   when "10"
    cost2 = "10"
    total = cost.to_i + cost2.to_i
    $evm.log("info", "Size #{size}, extra cost #{cost2}, total cost is #{total}")
   when "50"
    cost2 = "50"
    total = cost.to_i + cost2.to_i
    $evm.log("info", "Size #{size}, extra cost #{cost2}, total cost is #{total}")
   when "200"
    cost2 = "200"
    total = cost.to_i + cost2.to_i
    $evm.log("info", "Size #{size}, extra cost #{cost2}, total cost is #{total}")
  end
  
    $evm.log("info", "retirement is #{retirement}")
  
  dialog_field={}

  # sort_by: value / description / none
  dialog_field["required"] = true

  # data_type: string / integer
  dialog_field["protected"] = false

  # required: true / false
  dialog_field["read_only"] = true

  #Specify the criteria for approvals
  
 if retirement == 0
   dialog_field["value"] = "No retirement date was specified, approval is required. Total cost is #{total}"
   $evm.log("info", "No retirement date was specified, approval is required. Total cost is #{total}")
 else
   if total <= 150
   dialog_field["value"] = "The cost doesn't exceed 150, approval is not required. Total cost is #{total}"
     $evm.log("info", "The cost doesn't exceed 150, approval is not required. Total cost is #{total}")
   else
    dialog_field["value"] = "The cost exceeds 150, approval is required. Total cost is #{total}"
    $evm.log("info", "The cost exceeds 150, approval is required. Total cost is #{total}")
    end
 end

  dialog_field.each do |key, value|
    $evm.object[key] = value
  end

  #
  # Exit method
  #
  $evm.log("info", "#{@method} - EVM Automate Method: <#{@method}> Ended")
  exit MIQ_OK

  #
  # Set Ruby rescue behavior
  #
rescue => err
  $evm.log("error", "#{@method} - [#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_ABORT
end