###############################   Openstack Image Creation Script  ###############################
#### Author : Etienne ALLEGRE                                                                 ####
#### Company : Nuabee                                                                         ####
#### Date : 26/01/2021                                                                        ####
#### Description : This script automate the installation of XEN and KVM Drivers               ####
####               for a Windows Host as well as the installation of                          ####
####               of CloudBase-Init and perform a sysprep of the server                      ####
####               to turn it into an Openstack instance image                                ####
##################################################################################################

$ProgressPreference = 'SilentlyContinue'


Write-Host "Starting the server preparation script";

#######################   FIREWALL  ####################### 

Write-Host "Adding rules to allow RDP in the windows firewall";

# Activating advanced firewall configuration
Set-NetFirewallProfile -Profile Domain, Public, Private -Enabled True
# Activating remote connections
Set-ItemProperty ‘HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\‘ -Name “fDenyTSConnections” -Value 0
# Activating NLA
Set-ItemProperty ‘HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp\‘ -Name “UserAuthentication” -Value 1
# Activating inbound firewall rules for RDP
Enable-NetFirewallRule -DisplayGroup “Remote Desktop”



Write-Host "Creating drivers folder"
$cloud_driver_folder = New-Item -Path "C:\" -Name "CloudDrivers" -ItemType "directory"

Write-Host "Creating CloudInit folder"
$cloud_init_folder = New-Item -Path "C:\" -Name "CloudInit" -ItemType "directory"



#######################   XEN Drivers   #######################

Write-Host "Downloading XEN Drivers for XEN Virtualization";

$xen_driver_url = "https://oss.prod-cloud-ocb.orange-business.com/download/osdriver/windows/PVDriver/pvdriver-windows.iso"
$xen_driver_path = Join-Path -Path $cloud_driver_folder -ChildPath "pvdriver-windows.iso"
Invoke-WebRequest -UseBasicParsing $xen_driver_url -OutFile $xen_driver_path

Write-Host "Mounting XEN ISO Image";
Mount-DiskImage -ImagePath $xen_driver_path


Write-Host "Installing XEN Drivers for XEN Virtualization";
Set-Location E:\
Start-Process -FilePath 'E:\Setup.exe' -ArgumentList '/quiet', '/norestart'
Start-Sleep -s 60

Write-Host "Unmounting XEN ISO Image";
Dismount-DiskImage -ImagePath $xen_driver_path




#######################   KVM Drivers   #######################

Write-Host "Downloading KVM Drivers for KVM Virtualization";

$kvm_driver_url = "https://oss.prod-cloud-ocb.orange-business.com/download/osdriver/windows/vmtools/vmtools-windows.iso"
$kvm_driver_path = Join-Path -Path $cloud_driver_folder -ChildPath "vmtools-windows.iso"
Invoke-WebRequest -UseBasicParsing $kvm_driver_url -OutFile $kvm_driver_path


Write-Host "Mounting KVM ISO Image";
Mount-DiskImage -ImagePath $kvm_driver_path

Write-Host "Installing KVM Drivers for KVM Virtualization";
Set-Location E:\
Start-Process -FilePath 'E:\Setup.exe' -ArgumentList '/S', '/NORESTART'
Start-Sleep -s 60

Write-Host "Unmounting KVM ISO Image";
Dismount-DiskImage -ImagePath $kvm_driver_path




#######################   Cloud-Init  #######################

Write-Host "Downloading CloudInit";

$cloud_init_url = "https://www.cloudbase.it/downloads/CloudbaseInitSetup_Stable_x64.msi"
$cloud_init_path = Join-Path -Path $cloud_init_folder -ChildPath "CloudInitInstaller.msi"
Invoke-WebRequest -UseBasicParsing $cloud_init_url -OutFile $cloud_init_path

Write-Host "CloudInit Installation";

Set-Location C:\
Start-Process -FilePath $cloud_init_path -ArgumentList "/qn", "USERNAME=Administrator INJECTMETADATAPASSWORD=1"
Start-Sleep -s 60

Add-Content "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init.conf" "netbios_host_name_compatibility=false"
Add-Content "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init.conf"  "metadata_services=cloudbaseinit.metadata.services.httpservice.HttpService"
Add-Content "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init.conf" "retry_count=40"
Add-Content "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init.conf"  "retry_count_interval=5"
Add-Content "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init.conf"  "[openstack]"
Add-Content "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init.conf"  "add_metadata_private_ip_route=False"


#######################   SAN Policy #######################

Set-StorageSetting -NewDiskPolicy OnlineAll

#######################   Configuration DHCP   #######################

Write-Host "Modifying existing network interface with DHCP";

$IPType = "IPv4"
$adapter = Get-NetAdapter | Where-Object { $_.Status -eq "up" }
$interface = $adapter | Get-NetIPInterface -AddressFamily $IPType
If ($interface.Dhcp -eq "Disabled") {
    # Removing existing gateway
    If (($interface | Get-NetIPConfiguration).Ipv4DefaultGateway) {
        $interface | Remove-NetRoute -Confirm:$false
    }
    # Activating DHCP
    $interface | Set-NetIPInterface -DHCP Enabled
    # DNS Server automatic configuration
    $interface | Set-DnsClientServerAddress -ResetServerAddresses
}

# Releasing the IP Address
ipconfig /release


#######################   Sysprep  #######################

Write-Host "Starting the Sysprep process...";

Set-Location "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf"
C:\Windows\System32\sysprep\sysprep.exe /generalize /oobe /unattend:Unattend.xml