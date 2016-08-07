# coding: utf-8
#
# Description:
#     helper for retrieving networknames from ESX Hosts (from DVS -distributed virtual switch-)
#
# Usage:
#   $evm.instantiate('/Helper/Methods/GetNetworkNamesFromDVS')
#
# Results:
#   Brings a list of lists with IP and VLAN.
#   $evm.root[:helper_results] = [  [Network-Name, IP_STRING, VLAN_NUMBER, ],
#                                   [Network-Name, IP_STRING, VLAN_NUMBER, ],
#                                ]


def get_networks()
  $evm.log(:info, "Running on Server Version: #{$evm.root['miq_server'].version}")
  provider      = $evm.vmdb('ems').find_by_type('ManageIQ::Providers::Vmware::InfraManager')
  all_dvs_names = []
  provider.hosts.each do |host|
    $evm.log(:info, "Get dvs_networks for host #{host.name}")
    next if host.tags.include?('exclusions/invisible')
    host.switches.each do |switch|
      switch.lans.each do |nw|
        $evm.log(:info, "Parsing results for host #{host.name} nw: '#{nw.name}'")
        if nw.name =~ /(\d+)_(\d+)_(\d+)_(\d+)_V(\d+).*/
          all_dvs_names << [ nw.name, "#{$1.to_i}.#{$2.to_i}.#{$3.to_i}.#{$4.to_i}", $5.to_i]
        end
      end
    end
  end
  all_dvs_names.uniq
end

# =============================================================================
# === MAIN ====================================================================
# =============================================================================
begin
  $evm.log(:info, "Helper get_network_names_from_dvs called from #{__callee__}.")
  $evm.root[:helper_results] = get_networks()
  $evm.set_state_var(:helper_results, $evm.root[:helper_results])
  $evm.log(:info, "Helper Result: #{$evm.root[:helper_results]}")
  exit MIQ_OK
rescue => err
  $evm.log(:error, "[#{err}]\n#{err.backtrace.join("\n")}")
  exit MIQ_STOP
end
