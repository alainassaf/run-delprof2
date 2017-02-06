<#
.SYNOPSIS
Runs delprof2.exe on servers in the selected Worker Group
.DESCRIPTION
Runs delprof2.exe on servers in the selected Worker Group

This script has a dependency on delprof2.exe written by Helge Klein. It can be downloaded from https://helgeklein.com/free-tools/delprof2-user-profile-deletion-tool/. It is recommended that this script be run as a Citrix admin. 

.PARAMETER XMLBrokers
Optional parameter. Which Citrix XMLBroker(s) (farm) to query. Can be a list separated by commas.
.PARAMETER Delproflocation
Optional parameter. Location of Delprof2.exe.
.EXAMPLE
PS C:\PSScript > .\run-delprof2.ps1
Will use all default values.
.EXAMPLE
PS C:\PSScript > .\run-delprof2.ps1 -XMLBrokers "XMLBROKER"
Will use "XMLBROKER" to query XenApp farm.
.EXAMPLE
PS C:\> .\run-delprof2.ps1 -XMLBrokers "XMLBROKER" -Delproflocation "C:\delprof2.exe"
Will use "XMLBROKER" to query XenApp farm and "c:\delprof2.exe" as location for delprof2.exe.
.NOTES
NAME        :  run-delprof2
VERSION     :  1.04
LAST UPDATED:  2/6/2017
AUTHOR      :  Alain Assaf
.LINK
http://www.linkedin.com/in/alainassaf/
http://wagthereal.com
https://helgeklein.com/free-tools/delprof2-user-profile-deletion-tool/
https://mcpmag.com/articles/2015/01/08/powershell-scripts-talk-back.aspx
https://blogs.msdn.microsoft.com/powershell/2006/10/14/windows-powershell-exit-codes/
https://blogs.msdn.microsoft.com/kebab/2013/06/09/an-introduction-to-error-handling-in-powershell/
https://technet.microsoft.com/en-us/library/ff730949.aspx
https://msdn.microsoft.com/en-us/powershell/scripting/getting-started/cookbooks/selecting-items-from-a-list-box
http://stackoverflow.com/questions/25187048/run-executable-from-powershell-script-with-parameters
http://windowssecrets.com/forums/showthread.php/156384-Powershell-Forms-Which-Button
.INPUTS
None
.OUTPUTS
None
#>

Param(
 [parameter(Position = 0, Mandatory=$False )]
 [ValidateNotNullOrEmpty()]
 $XMLBrokers="CITRIXXMLBROKER", # Change to hardcode a default value for your XML Brokers
 
 [parameter(Position = 1, Mandatory=$False )]
 [ValidateNotNullOrEmpty()]
 $Delproflocation="C:\Delprof2 1.6.0\delprof2.exe" # Change to hardcode a default location for delprof2.exe
 )

#Constants
$PSSnapins = ("*citrix*")
#$ErrorActionPreference= 'silentlycontinue'

### START FUNCTION: get-mymodule #####################################################
Function Get-MyModule {
 Param([string]$name)
  if(-not(Get-Module -name $name)) {
  if(Get-Module -ListAvailable | Where-Object { $_.name -like $name }) {
   Import-Module -Name $name
   $true
  } #end if module available then import
  else { $false } #module not available
  } # end if not module
 else { $true } #module already loaded
}
### END FUNCTION: get-mymodule #####################################################
 
### START FUNCTION: get-mysnapin ###################################################
Function Get-MySnapin {
Param([string]$name)
 if(-not(Get-PSSnapin -name $name)) {
 if(Get-PSSnapin -Registered | Where-Object { $_.name -like $name }) {
 add-PSSnapin -Name $name
 $true
 } #end if module available then import
 else { $false } #snapin not available
 } # end if not snapin
 else { $true } #snapin already loaded
}
### END FUNCTION: get-mysnapin #####################################################

### START FUNCTION: test-port ######################################################
# Function to test RDP availability
# Written by Aaron Wurthmann (aaron (AT) wurthmann (DOT) com)
function Test-Port{
    Param([string]$srv=$strhost,$port=3389,$timeout=300)
    $ErrorActionPreference = "SilentlyContinue"
    $tcpclient = new-Object system.Net.Sockets.TcpClient
    $iar = $tcpclient.BeginConnect($srv,$port,$null,$null)
    $wait = $iar.AsyncWaitHandle.WaitOne($timeout,$false)
    if(!$wait) {
        $tcpclient.Close()
        Return $false
    } else {
        $error.Clear()
        $tcpclient.EndConnect($iar) | out-Null
        Return $true
        $tcpclient.Close()
    }
}
### END FUNCTION: test-port ########################################################

# Load PowerShell Snapins
foreach ($snapin in $PSSnapins.Split(",")) {
    if (!(get-MySnapin $snapin)) {
        write-warning "$snapin PowerShell Cmdlet not available."
        write-warning "Please run this script from a system with the $snapin PowerShell Cmdlets installed."
        exit 1
 }
} 

# Find an XML Broker that is up
$DC = $XMLBrokers.Split(",")
foreach ($broker in $DC) {
    if ((Test-Port $broker) -and (Test-Port $broker -port 1494) -and (Test-Port $broker -port 2598))  {
        $XMLBroker = $broker
    } else {
        write-warning "$XMLBROKER is not valid. Exiting run-delprof2.ps1"
        exit 1
    }
}

# Confirm delprof2.exe exists 
if (!(test-path $Delproflocation)) {
    write-warning "$Delproflocation is not valid. Exiting run-delprof2.ps1"
    exit 1
}

# Get a list of Worker Groups
$workergroups = Get-XAWorkerGroup -ComputerName $xmlbroker | select WorkerGroupname | sort -Property workergroupname

# Create a list box of Workergroups for user to pick
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$wgObjForm = New-Object System.Windows.Forms.Form 
$wgObjForm.Text = "Select a Worker Group"
$wgObjForm.Size = New-Object System.Drawing.Size(325,700) 
$wgObjForm.StartPosition = "CenterScreen"

$OKButton = New-Object System.Windows.Forms.Button
$OKButton.Location = New-Object System.Drawing.Size(75,620)
$OKButton.Size = New-Object System.Drawing.Size(75,23)
$OKButton.Text = "OK"
$OKButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$wgObjForm.AcceptButton = $OKButton
$wgObjForm.Controls.Add($OKButton)

$CancelButton = New-Object System.Windows.Forms.Button
$CancelButton.Location = New-Object System.Drawing.Size(150,620)
$CancelButton.Size = New-Object System.Drawing.Size(75,23)
$CancelButton.Text = "Cancel"
$CancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$wgObjForm.CancelButton = $CancelButton
$wgObjForm.Controls.Add($CancelButton)

$objLabel = New-Object System.Windows.Forms.Label
$objLabel.Location = New-Object System.Drawing.Point(10,15) 
$objLabel.Size = New-Object System.Drawing.Size(280,30) 
$objLabel.Text = "The computers in the workergroup will have delprof run against them:"
$wgObjForm.Controls.Add($objLabel) 

$objListBox = New-Object System.Windows.Forms.ListBox 
$objListBox.Location = New-Object System.Drawing.Point(10,45)
$objListBox.Size = New-Object System.Drawing.Size(275,50) 
$objListBox.Height = 500

foreach ($wg in $workergroups) {
    [void] $objListBox.Items.Add($wg.WorkerGroupName)
}

$wgObjForm.Controls.Add($objListBox) 

$wgObjForm.Topmost = $True

$result = $wgObjForm.ShowDialog()

if ($result -eq [System.Windows.Forms.DialogResult]::OK)
{
    $workergroup = $objListBox.SelectedItem
} else {
    exit 1
}

# Get computers in workergroup
$wgservers = (Get-XAWorkerGroupServer -ComputerName $XMLBroker -WorkerGroupName $workergroup)

# Run DelProf against each server in workergroup
foreach ($server in $wgservers) {
    $sname = $server.servername.Tostring()
    $arg1 = '-c:' + $sname
    $arg2 = '/u'
    & $Delproflocation $arg1 $arg2
}