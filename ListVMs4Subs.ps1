<#
.SYNOPSIS
    Script to monitor current status of all subscriptions accessed by the user.
.DESCRIPTION
    This script opens the Azure subscriptions the script is logged into and collects all 
    the status results for each vm. This data is stored in a csv file in a folder specified by the user. 
.PARAMETER filePath
    The path to store the csv files in. Required write permission for that folder.
    When this parameter is supplied the folder selector is not displayed and the input used is substituted. 
.PARAMETER noGrid
    Switch to turn off the grid of results generated for interactive use.
.EXAMPLE
    C:\>AzureMonitorVMs.ps1 -fullPath "C:\tmp" -noGrid 
    <Description of example>
    Collect all the status of vms to store under the C:\tmp directory
.NOTES
    Author: Dan Williams 
    Date:   July 31, 2018
#>
Param([string]$filePath,[switch]$noGrid,[switch]$verbose)
#Clear
Function Select-FolderDialog {
  param([string]$Description="Select Folder",[string]$RootFolder="Desktop")

  [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") |
  Out-Null

  $objForm = New-Object System.Windows.Forms.FolderBrowserDialog 
  $objForm.Rootfolder = $RootFolder
  $objForm.Description = $Description
  $Show = $objForm.ShowDialog()
  If ($Show -eq "OK")
  {
    Return $objForm.SelectedPath
  } else {
    Write-Error "Operation cancelled by user."
    exit
  }
}
if($verbose){
    if($VerbosePreference){
      $oldverbose = $VerbosePreference
    }else {
      $oldverbose = "SilentlyContinue"
    }
   $VerbosePreference = "continue"
}
<#
$azureAccountName = "dwilliams3"
$azurePassword = Read-host "What's your password?" -AsSecureString

Clear

$psCred = New-Object System.Management.Automation.PSCredential($azureAccountName, $azurePassword)

Login-AzureRmAccount -Credential $psCred | out-null
#>
$Date = get-date -f _yyyyMMdd_hhmmss

if ($filePath){
  $Path = ($filePath+"\AzureMonitorVMs")
}else{
  $folder = Select-FolderDialog  # the variable contains user folder selection
  $Path = ($folder+"\AzureMonitorVMs")
}
Write-Verbose "Folder selected - $folder"
#$Path = ("Z:\Shared_Data\AzureVMMonitor"+$Date)

if ((Test-Path $Path) -ne "true") {
  $Directory = New-Item $Path -type directory
}
$Directory = $Path

Write-Verbose "Path = $Path "
Write-Verbose "Dir = $Directory"


$PublicIPAll = ""
$HostEnv = (Get-Host).PrivateData

#-----------------------------------------------------------
#         Subscriptions --- Starting of the loop
#-----------------------------------------------------------

$subsAzure = Get-AzureRmSubscription |Select-Object Name,State,Id,TenantId
$subsAzure = $subsAzure | Where-Object {$_.State -ne "Disabled"}
$subsAzure = $subsAzure | Sort-Object @{Expression={$_.Name}; Ascending=$true}

#CSV Exports Subscriptions
$csvsubPath = $Directory + "\Subscriptions"+$Date+".csv"
#$csvsubs =
#$subsAzure  | Export-Csv $csvsubPath -NoTypeInformation

$n = 0
<###########################################################
############################################################
###########################################################>

ForEach ($subAzure in $subsAzure) { #For each enabled subscription
  if ($subsAzure[$n].State -eq "Enabled") {
    $SubscriptionID = $subsAzure[$n].Id
    $TenantID = $subsAzure[$n].TenantId
    $SubName = $subsAzure[$n].Name

    Set-AzureRmContext -SubscriptionId $SubscriptionID -TenantId $TenantID | out-null
    Write-Verbose "Gathering $SubName status"

    $n ++                                  #
    $y = 0
    if ((Test-Path ($Directory + "\" +$SubName )) -ne "true") {
      New-Item ($Directory + "\" +$SubName ) -type directory
    }
    $DirectorySubName = $Directory + "\" + $SubName
    
    $VMStatus = Get-AzureRmVM -Status
    $VMFields = @()
    
    foreach ($VMStat in $VMStatus) {
    #    NIC    = $VMStat.NIC
      #Invoke-Command -scriptblock {Get-Process | Sort CPU -descending | Select -first 5 } -computername $VMStat.Name
      $VMFields += [pscustomobject]@{
        Name   = $VMStat.Name
        ResourceGroup = $VMStat.ResourceGroupName
        State  = $VMStat.PowerState
        VMSize = $VMStat.HardwareProfile.VmSize
        OSType = $VMStat.StorageProfile.OsDisk.OsType
        StatusCode = $VMStat.StatusCode       
      }
    }
 
    if($noGrid -eq $false){ #
      $VMFields | Out-GridView -Title $SubName
    }
    $fullPath = $DirectorySubName + "\VmStats_"+ $Date +".csv" 
    $VMFields | export-csv -Path $fullPath -NoTypeInformation

    <#
    $vm.StorageProfile.DataDisks.count 
if ($($vm.StorageProfile.OsDisk.EncryptionSettings).length -ge 0) {Write-Host "None"}

        Read the log from each resource group looking for non-Informational entries
    #>
    <#
    $Log = Get-AzureRmLog -ResourceGroup NSGTest #| Where {$_.Level -ne "Informational"} | select Level,EventTimestamp,EventDataId,$(Properties) 
    foreach ($entry in $Log) { 
      $MyFields = [pscustomobject]@{
        Level   = $event.Level
        EventTimestamp = $event.EventTimestamp
        EventDataId    = $event.EventDataId
        statusCode  = $event.Properties.statusCode
        statusMessage  = $event.Properties.statusMessage
      }
      $MyFields | Format-Custom
    } 
    #>
  }
}
$scptName = $MyInvocation.MyCommand.Name 
Write-Verbose "$scptName completed"
if($oldverbose){
      $VerbosePreference = $oldverbose
    }else {
      $oldverbose = "SilentlyContinue"
}
