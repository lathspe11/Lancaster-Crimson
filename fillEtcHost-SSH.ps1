<#
.SYNOPSIS
    Script to Generate /etc/host inputs and ssh commands to build out the keys for the network for the gateway machine.
.DESCRIPTION
    This script opens the Azure subscriptions the script is logged into and collects all 
    the status results for each vm. This data is stored in a csv file in a folder specified by the user. 
.EXAMPLE
    C:\>fillEtcHost-SSH.ps1 
    <Description of example>
    Select the Azure Subscription to use


Name             : ARRIS Delivery Test Environment - 436bc258-b732-4601-8cd3-98529ca72f38
Account          : Daniel.Williams@arris.com
SubscriptionName : ARRIS Delivery Test Environment
TenantId         : f27929ad-e554-4d55-837a-c561519c3091
Environment      : AzureCloud

#Add to the /etc/host file 
# Private IP  VM Name # Allocation
192.168.10.4     Bastion   # Dynamic
10.0.1.4     ad68test   # Dynamic
10.0.1.5     ad73test   # Dynamic
10.0.0.32     arris-ces-cassandra-02   # Static
10.0.0.33     arris-ces-cassandra-03   # Static
10.0.0.31     arris-ces-cassandra-01   # Static
10.0.0.30     arris-ces-collect   # Static
...
#Run the following
ssh-keygen
ssh-copy-id arris@192.168.10.4 
ssh-copy-id arris@10.0.1.4 
ssh-copy-id arris@10.0.1.5 
ssh-copy-id arris@10.0.0.32 
ssh-copy-id arris@10.0.0.33 
ssh-copy-id arris@10.0.0.31 
ssh-copy-id arris@10.0.0.30 
...

.NOTES
    Author: Dan Williams 
    Date:   August 8, 2018
#>


<#
$azureAccountName = "dwilliams3" #Read-Host "What's your Azure Account name?"
$azurePassword = Read-host "What's your password?" -AsSecureString

Clear

$psCred = New-Object System.Management.Automation.PSCredential($azureAccountName, $azurePassword)

Login-AzureRmAccount -Credential $psCred | out-null
#>

Write-Host "Select the Azure Subscription to use"
$subscriptionId = (Get-AzureRmSubscription | Out-GridView -Title 'Select Azure Subscription:' -PassThru).SubscriptionId
Select-AzureRmSubscription -SubscriptionId $subscriptionId

$vms = get-azurermvm
$nics = get-azurermnetworkinterface | where VirtualMachine -NE $null #skip Nics with no VM
 

Write-Output "#Add to the /etc/host file "
write-output "# Private IP  VM Name # Allocation"
$saveIPs = @()
foreach($nic in $nics)
{
    $vm = $vms | where-object -Property Id -EQ $nic.VirtualMachine.id
    $prv =  $nic.IpConfigurations | select-object -ExpandProperty PrivateIpAddress
    $saveIPs += $prv
    $alloc =  $nic.IpConfigurations | select-object -ExpandProperty PrivateIpAllocationMethod
    Write-Output "$prv     $($vm.Name)   # $alloc"
}
Write-Output "#Run the following"
Write-Output "ssh-keygen"
foreach ($sIP in $saveIPs){
    Write-Output "ssh-copy-id arris@$sIP "
}
