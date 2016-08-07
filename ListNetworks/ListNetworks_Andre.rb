$evm.log("info", "Vlan_list Automate Method Started")

# The provider has been hardcoded here, needs to update it to use a input from user
dialog_field = $evm.object
dialog_field = Hash.new "values"
provider_input="soc-vcenter"

# List all providers... don't know why, maybe remove it
$evm.vmdb("ext_management_system").all.each do |e|
    $evm.log("info","Provider: #{e.name}")
end

# def to extract DVS from Provider
def dvs_names(provider)
 provider.object_send('instance_eval',
<<-THE_SCRIPT
def dvs_names
  dvs_list = []
  begin
    vim = provider.connect
    hosts.each do |dest_host|
      dvs = vim.queryDvsConfigTarget(vim.sic.dvSwitchManager, dest_host.ems_ref_obj, nil) rescue nil
      # List the names of the non-uplink portgroups.
      unless dvs.nil? || dvs.distributedVirtualPortgroup.nil?
        nupga = vim.applyFilter(dvs.distributedVirtualPortgroup, 'uplinkPortgroup' => 'false')
        nupga.each { |nupg| dvs_list << nupg.portgroupName }
      end
    end
  rescue
  ensure
    vim.disconnect if vim
  end
  dvs_list.uniq
end
THE_SCRIPT
)
provider.object_send('dvs_names')
end

#retrieving Provider information
$evm.log("info","Provider input:#{provider_input}")
provider = $evm.vmdb('ext_management_system').find_by_name(provider_input)

#drop provider info in the logs
$evm.log("info",provider.inspect)

#retrieve DVS
dvs = dvs_names(provider)
$evm.log("info", "Return DVS: #{dvs.inspect}")

#retrieve vLans from VMDB
vlans = []
provider.hosts.each do |host|
  host.lans.each {|lan| vlans << lan.name}
end

vlans.uniq!
vlans.delete_if { |v| v.include?('Service Console') || v.include?('VMkernel') }
$evm.log("info", "Return VLans 2: #{vlans.inspect}")

#Populate dynamice drop list
vlans.each do |e|
  dialog_field.store(e,e)
 #$evm.log("info",e.inspect)
end

dvs.each do |e|
  dialog_field.store(e,e)
#$evm.log("info",e.inspect)
end

$evm.object["sort_by"] = "value"
$evm.object["sort_order"] = "ascending"
$evm.object["data_type"] = "string"
$evm.object['values'] = dialog_field
$evm.log("info", "Automate Method Ended")
exit MIQ_OK
