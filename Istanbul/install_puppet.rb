#
# Description:
#

begin
  require 'rbvmomi'
rescue LoadError
  `gem install rbvmomi`
  require 'rbvmomi'
end

# basic retry logic
def retry_method(retry_time=1.minute)
  $evm.log(:info, "Sleeping #{retry_time}")
  $evm.root['ae_result'] = 'retry'
  $evm.root['ae_retry_interval'] = retry_time
  exit MIQ_OK
end

def exec_command(vim, vm_ref, cmd, args)

  $evm.log(:info, "#{cmd} #{args}")

  guest_auth = RbVmomi::VIM::NamePasswordAuthentication({
    :username => @guest_username,
    :password => @guest_password,
    :interactiveSession => false
  })

  gom = vim.serviceContent.guestOperationsManager
  vm  = vim.searchIndex.FindByUuid(uuid: vm_ref, vmSearch: true)

  prog_spec = RbVmomi::VIM::GuestProgramSpec(
    :programPath      => cmd,
    :arguments        => args,
    :workingDirectory => '/tmp'
  )

  gom.processManager.StartProgramInGuest(
    :vm   => vm,
    :auth => guest_auth,
    :spec => prog_spec
  )
end

# Grab the VM object
$evm.log(:info, "vmdb_object_type: #{$evm.root['vmdb_object_type']}")
case $evm.root['vmdb_object_type']
when 'miq_provision'
  prov = $evm.root['miq_provision']
  vm   = prov.vm unless prov.nil?
else
  vm = $evm.root['vm']
end
raise 'VM object is empty' if vm.nil?

unless vm.vendor.downcase == 'vmware'
  $evm.log(:warn, "Only VMware supported currently, exiting gracefully")
  exit MIQ_OK
end

vm_ref          = vm.uid_ems
esx             = vm.ext_management_system.hostname
esx_userid      = vm.ext_management_system.authentication_userid
esx_password    = vm.ext_management_system.authentication_password
@guest_username = $evm.object['guest_username']
@guest_password = $evm.object.decrypt('guest_password')

$evm.log(:info, "VM: #{vm.name}")
$evm.log(:info, "Tags: #{vm.tags}")

if @guest_username.nil? || @guest_password.nil?
  # Catch provisioning without Chef
  10.times { $evm.log(:warn, "Required parameters missing, exiting gracefully") }
  exit MIQ_OK
end

$evm.log(:info, "VM power state: #{vm.power_state}")
if vm.power_state == 'off'
  $evm.log(:info, "Starting VM...")
  vm.start
end

###################################
# Wait until VM is on the network
###################################

unless vm.ipaddresses.empty?
  non_zeroconf = false
  vm.ipaddresses.each do |ipaddr|
    non_zeroconf = true unless ipaddr.match(/^(169.254|0)/)
    $evm.log(:info, "VM:<#{vm.name}> IP Address found #{ipaddr} (#{non_zeroconf})")
  end
  if non_zeroconf
    $evm.log(:info, "VM:<#{vm.name}> IP addresses:<#{vm.ipaddresses.inspect}> present.")
    $evm.root['ae_result'] = 'ok'
  else
    $evm.log(:warn, "VM:<#{vm.name}> IP addresses:<#{vm.ipaddresses.inspect}> not present.")
    retry_method("15.seconds")
  end
else
  $evm.log(:warn, "VM:<#{vm.name}> IP addresses:<#{vm.ipaddresses.inspect}> not present.")
  vm.refresh
  retry_method("15.seconds")
end

if vm.hostnames.empty? || vm.hostnames.first.blank?
  $evm.log(:info, "Waiting for vm hostname to populate")
  vm.refresh
  retry_method("15.seconds")
end

###################################
# Prepare and Bootstrap new VM
###################################

# http://www.rubydoc.info/github/rlane/rbvmomi/RbVmomi/VIM
vim = RbVmomi::VIM.connect(host: esx, user: esx_userid, password: esx_password, insecure: true)

domain = 'borsa.local'
hostname = vm.name

# if match = hostname.match(/^c(\d{1})(gop|icsi|gmds)(\d{2})$/i)
if match = hostname.match(/^c(\d{1})(.*)(\d{2})$/i)
  type = 'bistech'
  phase       = match[1]
  application = match[2]
  environment = match[3]
  $evm.log(:info, "phase:       #{phase}")
  $evm.log(:info, "application: #{application}")
  $evm.log(:info, "environment: #{environment}")

elsif match = hostname.match(/^y\d{1}.*(\d{2})$/i)
  type = 'non_bistech'
  environment = match[1]
end
$evm.log(:info, "type: #{type}")
raise 'regex failed' if match.nil?

$evm.log(:info, "Installing Puppet client")
cmd, args   = '/usr/bin/curl', "-k https://puppet:8140/packages/current/install.bash | bash -s agent:certname=#{hostname}.#{domain}"
exec_command(vim, vm_ref, cmd, args)

sleep 60

$evm.log(:info, "Configuring Puppet client")
cmd, args   = '/usr/local/bin/puppet', "config set environment #{environment} --section agent"
exec_command(vim, vm_ref, cmd, args)
cmd, args   = '/usr/local/bin/puppet', "config set environment #{environment} --section main"
exec_command(vim, vm_ref, cmd, args)
cmd, args   = '/sbin/service', "pe-puppet restart"
exec_command(vim, vm_ref, cmd, args)

$evm.log(:info, "Puppet Cert Accept")
cmd, args   = '/usr/local/bin/puppet', "cert sign #{hostname}.#{domain}"

if type == 'non_bistech'
  $evm.log(:info, "Non-BISTECH, we're done")
  exit MIQ_OK
end

$evm.log(:info, "Download and configure Puppet manifest")
if vm.tagged_with?('environment', 'prod')
  repo = "nomx" if phase == 1
  repo = "nomx_p2" if phase == 2
elsif vm.tagged_with?('environment', 'dev')
  repo = "p1_bistech_rc" if phase == 1
  repo = "p2_bistech_rc" if phase == 2
else
  raise 'expected tags missings'
end
$evm.log(:info, "repo: #{repo}")

cmd, args   = '/usr/bin/curl', "https://btrep/svn/smm/trunk/puppet_codes/#{application}/#{application}_install_single.pp -k -u svcpuppetdeploy:8vCpU8837 -o /admin/scripts/#{application}_install_single.pp"
exec_command(vim, vm_ref, cmd, args)
cmd, args   = '/bin/sed', "-i 's/_faz_/#{repo}/g' /admin/scripts/#{application}_install_single.pp"
exec_command(vim, vm_ref, cmd, args)

$evm.log(:info, "Install Puppet manifest")
cmd, args   = '/usr/local/bin/puppet', "apply /admin/scripts/#{application}_install_single.pp"

$evm.log(:info, "Poke DB script")
cmd, args   = '/usr/bin/ssh', "oracle@10.57.2.254 'bash /oracle/scripts/create_cdb_database.sh ET#{environment}CDB P16'"

$evm.log(:info, "Final steps #1")
cmd, args   = '/usr/bin/curl', "https://btrep/svn/smm/trunk/puppet_codes/ginet/multi_customer_override.yml -k -u svcpuppetdeploy:8vCpU8837 -o /opt/omex/bist/bist/config/manual/customer_override.yml"
exec_command(vim, vm_ref, cmd, args)
cmd, args   = '/usr/bin/curl', "https://btrep/svn/smm/trunk/puppet_codes/ginet/tnsnames.ora -k -u svcpuppetdeploy:8vCpU8837 -o /opt/omex/bist/bist/config/db/tnsnames.ora"
exec_command(vim, vm_ref, cmd, args)

if application.downcase == 'ginet'
  [ "-i 's/VAR_ORACLE_SID/#{environment}/g' /opt/omex/bist/bist/config/manual/customer_override.yml",
    "-i 's/VAR_DF_EXTERNAL_INTERFACE_ADDRESS_P1GENE32_IP/#{vm.ipaddresses[0]}/g' /opt/omex/bist/bist/config/manual/customer_override.yml",
    "-i 's/VAR_PRIMARY_NODE_DD_FEED/#{vm.name}/g' /opt/omex/bist/bist/config/manual/customer_override.yml",
    "-i 's/VAR_PRIMARY_NODE_GAL_REWIND/#{vm.name}/g' /opt/omex/bist/bist/config/manual/customer_override.yml",
    "-i 's/VAR_PRIMARY_NODE_GAL_ZREWIND/#{vm.name}/g' /opt/omex/bist/bist/config/manual/customer_override.yml",
    "-i 's/VAR_AL_PRIMARY_NODE_FG/#{vm.name}/g' /opt/omex/bist/bist/config/manual/customer_override.yml",
    "-i 's/VAR_GPC_NODE_CONFIGURATION/#{vm.name}/g' /opt/omex/bist/bist/config/manual/customer_override.yml",
    "-i 's/VAR_GAL_PRIMARY_NODE_RDS/#{vm.name}/g' /opt/omex/bist/bist/config/manual/customer_override.yml",
    "-i 's/VAR_MDS_OMNETCONNECTOR_INFO_R0/#{vm.ipaddresses[0]}/g' /opt/omex/bist/bist/config/manual/customer_override.yml",
    "-i 's/VAR_ORACLE_SID/#{vm.name}/g' /opt/omex/bist/bist/config/db/tnsnames.ora" ].each do |arg|
      cmd = '/bin/sed'
      exec_command(vim, vm_ref, cmd, arg)
      sleep 1
    end

  [ "- omex_sys_bist -c 'go_map_nodes.pl -j BOOTSTRAP-GO'",
    "- omex_sys_bist -c 'go_manual_operations.pl --rc --force'",
    "- omex_sys_bist -c 'go_map_nodes.pl -j RUN-UPGRADES'" ].each do |arg|
      cmd = '/bin/sed'
      exec_command(vim, vm_ref, cmd, arg)
      sleep 1
    end
end