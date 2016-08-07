#
# Description: Microsoft Invoke-VMScript
#

require 'winrm'

# Method for logging
def log(level, message)
  @method = '----- Microsoft Invoke-VMScript -----'
  $evm.log(level, "#{@method} - #{message}")
end

@debug = true

# prov = $evm.root['miq_provision'] || $evm.root['service_template_provision_task']
# prov.options.each {|k,v| log(:info, "options #{k}: #{v}")}
# raise 'Prov object not found' if prov.nil?
# vm = prov.vm

# hostname = prov.options[:vm_target_hostname]
# log(:info, "Hostname: #{hostname}")

# Get vm object from root
vm = $evm.root['vm']
raise 'VM object not found' if vm.nil?
$evm.log(:info, "Instance: #{vm.name}, #{vm.uid_ems}")

if vm.vendor.downcase != 'vmware'
  # $evm.object['read_only'] = true
  # dialog_hash['value'] = "Invalid for #{vm.vendor}"
  # $evm.object['values'] = dialog_hash
  exit MIQ_OK
end

# ems_microsoft = $evm.vmdb('ext_management_system').find_by_id(prov.options[:src_ems_id])
# log(:info, ems_microsoft.inspect) if @debug

# winrm_host      = ems_microsoft.hostname
# winrm_user      = ems_microsoft.authentication_userid
# winrm_password  = ems_microsoft.authentication_password

winrm_host      = ''
winrm_user      = ''
winrm_password  = ''

port ||= 5985
endpoint = "http://#{winrm_host}:#{port}/wsman"
log(:info, "endpoint => #{endpoint}")

transport = 'ssl' # ssl/kerberos/plaintext
opts = {
  :user         => winrm_user,
  :pass         => winrm_password,
  :disable_sspi => true
}
if transport == 'kerberos'
  opts.merge!(
    :realm            => winrm_realm,
    :basic_auth_only  => false,
    :disable_sspi     => false
  )
end
log(:info, "opts => #{opts}") if @debug

script_text = ''
vm_name   = vm.ComputerName
host_usr  = vm.host.authentication_userid
host_pwd  = vm.host.authentication_password
guest_usr = ''
guest_pwd = ''

script = <<SCRIPT
Add-PSSnapin VMware.VimAutomation.Core | Out-Null
Connect-VIServer -Server $vc -User $vcUsr -Password $vcPwd
Invoke-VMScript -ScriptText '#{script_text}' -VM #{vm_name} -HostUser #{host_usr} -HostPassword #{host_pwd} \
  -GuestUser #{guest_usr} -GuestPassword #{guest_pwd} -ToolsWaitSecs 60
SCRIPT
log(:info, "script => #{script}") if @debug

log(:info, 'Establishing WinRM connection')
connect_winrm = WinRM::WinRMWebService.new(endpoint, transport.to_sym, opts)

log(:info, 'Executing PowerShell')
powershell_return = connect_winrm.powershell(script)

# Process the winrm output
log(:info, "powershell_return => #{powershell_return}") if @debug

Add-PSSnapin VMware.VimAutomation.Core
