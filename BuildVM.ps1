<#
.SYNOPSIS
    Script to build a new vm in the NSGTest resource group.
.DESCRIPTION
    This script Creates a new vm in the NSGTest resource group 
.PARAMETER vName
    The name to use for the VM
.EXAMPLE
    C:\>BuildVM.ps1 -vmName myName 
    <Description of example>
    Create a VM named myName
.NOTES
    Author: Dan Williams 
    Date:   Aug 6, 2018
#>
#New-AzureRmVm -ResourceGroupName NSGTest -Name DansnsgVM -Location westus -VirtualNetworkName NSGTest-vnet -SecurityGroupName NSGTest01-nsg 
#-Credential $cred -PublicIpAddressName "DansnsgVMPublicIP" -
#Connect-AzureRmAccount
Param([string]$vName)

if($vName) {
 $vmName = $vName
}else {
  $vmName        = Read-Host -Prompt "Enter unique VM Name"  
}

# Variables for common values
$resourceGroup = "NSGTest"
$location      = "westus"
$nsgGroup      = "DansnsgVM-nsg"
$pipname       = $vmName + "_pip"
$vnetName      = "NSGTest-vnet"
$nicName       = $vmName + "_nic"

# bcedf4a8-a81e-4688-b08b-dd35889a4a56 is NSGTest01
$subscriptionId="bcedf4a8-a81e-4688-b08b-dd35889a4a56"
Select-AzureRmSubscription $subscriptionId

# Definer user name and blank password
#$securePassword = ConvertTo-SecureString ' ' -AsPlainText -Force
#$cred = New-Object System.Management.Automation.PSCredential ("azureuser", $securePassword)

# Create a resource group
#New-AzureRmResourceGroup -Name $resourceGroup -Location $location

# Create or select a virtual network
$vnet = Get-AzureRmVirtualNetwork -Name $vnetName -ResourceGroupName $resourceGroup # -Subnet $subnetConfig 

# Grab a subnet configuration
#$subnetConfig = Get-AzureRmVirtualNetworkSubnetConfig -Name DansnsgSubnet -VirtualNetwork $vnet #-AddressPrefix 10.0.0.0/24

# Create a public IP address and specify a DNS name
$pip = New-AzureRmPublicIpAddress -ResourceGroupName $resourceGroup -Location $location `
  -Name $pipname -AllocationMethod Static -IdleTimeoutInMinutes 4

# Create an inbound network security group rule for port 22
#$nsgRuleSSH = New-AzureRmNetworkSecurityRuleConfig -Name myNetworkSecurityGroupRuleSSH  -Protocol Tcp `
#  -Direction Inbound -Priority 1000 -SourceAddressPrefix * -SourcePortRange * -DestinationAddressPrefix * `
#  -DestinationPortRange 22 -Access Allow

# Create a network security group
$nsg = Get-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Name $nsgGroup
 #New-AzureRmNetworkSecurityGroup -ResourceGroupName $resourceGroup -Location $location `
 # -Name myNetworkSecurityGroup -SecurityRules $nsgRuleSSH

# Create a virtual network card and associate with public IP address and NSG
$nic = New-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $resourceGroup -Location $location `
  -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $pip.Id -NetworkSecurityGroupId $nsg.Id

# Create a virtual machine configuration
$cred = Get-Credential -Credential arris -InformationAction Continue -ErrorAction SilentlyContinue -ErrorVariable $CredError
if ($CredError){
  Write-Host "The Password must be provided for the configuration"
  exit
}
$vmConfig = New-AzureRmVMConfig -VMName $vmName -VMSize Standard_D1 | `
Set-AzureRmVMOperatingSystem -Linux -ComputerName $vmName -Credential $cred | `
Set-AzureRmVMSourceImage -PublisherName "OpenLogic" -Offer "CentOS" -Skus 7.5 -Version latest | `
Add-AzureRmVMNetworkInterface -Id $nic.Id

# Configure SSH Keys
$sshPublicKey = Get-Content "$env:USERPROFILE\ssh\nsgvm.pub"
#Add-AzureRmVMSshPublicKey -VM $vmconfig -KeyData $sshPublicKey -Path "/home/azureuser/.ssh/authorized_keys"

# Create a virtual machine
New-AzureRmVM -ResourceGroupName $resourceGroup -Location $location -VM $vmConfig