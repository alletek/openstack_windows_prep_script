# What's this script ?

This is a powershell script that is used to prepare an On-Premise Windows Server to be transformed into an Openstack's Glance Image that can be used to create any number of Windows Server Instance.

# What does it do ?

## Network Configuration

This script will allow RDP through the Windows Firewall on any network (public, private or domain).
It will also change the networking to DHCP (to allow the instance to be assigned an IP through the VPC DHCP Service).


## Driver Installation

The Openstack Cloud we are using is running XEN and KVM hypervisors, depending on the flavor you choose for you instance.
To be able to start Windows from a private image without getting a bluescreen, we need to install XEN and KVM drivers.

## Cloud-init installation

The Cloud we use is using CloudBase-init (A Windows version of the CloudInit software) to configure instances, it allows the injection of powershell script when the instance start using metadata injection, this is very usefull to be able to customize ever instance we start.


## Sysprep

Finally, this script will perform a Sysprep of the image once everything is configured, to remove it's unique SID and allow us to join any number of instance started from this image to a Windows Domain.
