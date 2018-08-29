<#
.SYNOPSIS
    Script to Generate a list of VMs with public and private ips and their ResourceGroupName
.DESCRIPTION
    This script opens the Azure subscriptions accessible to the user's login and
    when you select a subscription will return a list of VMs with their ResourceGroupName and 
    public and private ips 
.EXAMPLE
    C:\>VMIPs.ps1 
    <Description of example>
    Select the Azure Subscription to use

    
Name             : Test Environment - 4WWWWWWW-XXXX-YYYY-KKKK-RRRRRRRRRRRR
Account          : <Your Name Here>@<Company>.com
SubscriptionName : Test Environment
TenantId         : XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
Environment      : AzureCloud



Name                             ResourceGroup     PublicIP       PrivateIP   
----                             -------------     --------       ---------   
Bastion                          ADMIN_RG          137.117.16.41  192.168.10.4
ad68test                         ADTEST            40.85.159.142  10.0.1.4    
ad73test                         ADTEST            104.42.124.57  10.0.1.5    
arris-ces-cassandra-01           ARRIS-CAP-CES     none           10.0.0.31   
arris-ces-cassandra-02           ARRIS-CAP-CES     none           10.0.0.32   
arris-ces-cassandra-03           ARRIS-CAP-CES     none           10.0.0.33   
arris-ces-collect                ARRIS-CAP-CES     none           10.0.0.30   
...


.NOTES
    Author: Dan Williams 
    Date:   August 28, 2018
#>

#Assume you are logged into Azure
#Pick the subcription to read
Write-Host "Select the Azure Subscription to use"
$subscriptionId = (Get-AzureRmSubscription | Out-GridView -Title 'Select Azure Subscription:' -PassThru).SubscriptionId
Select-AzureRmSubscription -SubscriptionId $subscriptionId

 $VMStatus = Get-AzureRmVM -Status
 $VMFields = @()
foreach ($VMStat in $VMStatus) {
    #See https://stackoverflow.com/questions/38054573/get-current-ip-addresses-associated-with-an-azure-arm-vms-set-of-nics-via-power
    
    $Resourcegroup=$VMStat.ResourceGroupName
    $VmName=$VMStat.Name

    $vm = Get-AzureRmVM -ResourceGroupName $Resourcegroup -Name $VmName

    #$VmNetworkdetails= (((Get-AzureRmVM -ResourceGroupName $Resourcegroup -Name $VmName).NetworkProfile).NetworkInterfaces).Id
    $VmNetworkdetails= $vm.NetworkProfile.NetworkInterfaces.Id

    #$nicname = $VmNetworkdetails.substring($VmNetworkdetails.LastIndexOf("/")+1)

    $nic = Get-AzureRmNetworkInterface -ResourceGroupName $ResourceGroup -Name $(Split-Path -Leaf $vm.NetworkProfile.NetworkInterfaces[0].Id)
    $saveval = $nic | Get-AzureRmNetworkInterfaceIpConfig | Select-Object Name,PrivateIpAddress,@{'label'='PublicIpAddress';Expression={Set-Variable -name pip -scope Global -value $(Split-Path -leaf $_.PublicIpAddress.Id);$pip}}

    $pub = (Get-AzureRmPublicIpAddress -ResourceGroupName $ResourceGroup -Name $pip -ErrorAction SilentlyContinue -ErrorVariable NSGError).IpAddress
    
    if($NSGError){
        $pub = "none"
    }

    $VMFields += [pscustomobject]@{
        Name   = $VMStat.Name
        ResourceGroup = $VMStat.ResourceGroupName
        PublicIP  = $pub
        PrivateIP = $saveval.PrivateIpAddress
    }
}
$VMFields | Format-Table
