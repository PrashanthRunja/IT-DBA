##example command
## .\Validation_Script.ps1 -ServerName P054SQLMGMT03.EPIQCORP.COM\SQLADMIN ##Make sure to include instance name if it's a named instance

##Defining parameters
param (
[Parameter(Mandatory=$true)][string]$ServerName
)

##Stop further execution if error is encountered
$ErrorActionPreference = "Stop" 


##load SMO assembly into memory
##only valid for one session
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO')  | out-null

##create SMO server object
##can be used with remote servers as well
$Server = new-object ('Microsoft.SqlServer.Management.Smo.Server') $ServerName

##First test if SQL server is online
$Tmstmp = get-date

$ServerStatus = $Server.Status

if ($ServerStatus -eq $null)
{
    While ($ServerStatus -eq $null -and (New-TimeSpan -start $tmstmp -end (get-date)).TotalSeconds -lt 60)
    {
        Write-Warning "SQL server $ServerName is not online. Retrying every 10 seconds for the next 1 minute `n`n"
        Start-Sleep -Seconds 10
        $ServerStatus = $Server.Status
    }
}

##If SQL server is still not reachable after 1 minute, exit the code
if ($ServerStatus -eq $null)
{
    Write-Warning "Could not connect to $ServerName. Please investigate `n`n"
    Exit
}


##Gather OS information
$HostName = $ServerName.Split('\')

$ServerInformation = @()

$SQLInfo = $Server.Information | Select-Object FullyQualifiedNetName, Product, Edition, VersionString, Processors, PhysicalMemory

$OSInfo = Get-CimInstance -ComputerName $HostName[0] -Class Win32_OperatingSystem | Select-Object Caption, LastBootUpTime

$InstanceName = $Server.InstanceName

$ServerInformation += [PSCustomObject]@{
    FQDN = $SQLInfo.FullyQualifiedNetName
    OS = $OSInfo.Caption
    CPU = $SQLInfo.Processors
    Memory = $SQLInfo.PhysicalMemory
    'Last BootUp Time' = $OSInfo.LastBootUpTime
 }


##Get SQL instance configurations
$InstanceConfigInfo = $Server.Configuration.Properties | Select-Object DisplayName, RunValue | Where-Object {$_.DisplayName -in "clr enabled", "clr strict security", "cost threshold for parallelism", "Database Mail XPs", "max degree of parallelism ", "max server memory (MB)", "min server memory (MB)", "remote access", "remote admin connections", "remote query timeout", "xp_cmdshell"}  | Sort-Object DisplayName


##Gather SQL Server databases information
$MasterDatabase = $Server.Databases['master']
$ExecTSQL = $MasterDatabase.ExecuteWithResults('SELECT database_id, name, state_desc FROM sys.databases order by name')
$data = $ExecTSQL.Tables.Rows

$UserDatabaseCount = $data | Select-Object database_id | Where-Object {$_.database_id -gt 4} | Measure-Object

$OnlineUserDatabaseCount = $data | Select-Object database_id, state_desc | Where-Object {$_.state_desc -eq 'ONLINE' -and $_.database_id -gt 4} | Measure-Object

$NotOnlineUserDatabaseCount = $data | Select-Object database_id, state_desc | Where-Object {$_.state_desc -ne 'ONLINE' -and $_.database_id -gt 4} | Measure-Object

$SQLInformation += [PSCustomObject]@{
   FQDN = $SQLInfo.FullyQualifiedNetName
   InstanceName = if ($InstanceName -eq "") {"Default"} else {$InstanceName}
   Product = $SQLInfo.Product
   Edition = $SQLInfo.Edition
   Build = $SQLInfo.VersionString
   'Number of User Databases' = $UserDatabaseCount.Count
   'Online User Databases' = $OnlineUserDatabaseCount.Count
   'Problematic User Databases' = $NotOnlineUserDatabaseCount.Count
}

##Gather SQL services information
$ServicesInfo = Get-CimInstance -ComputerName $HostName[0] -ClassName Win32_Service | Select-Object DisplayName, State, StartName, StartMode | Where-Object {$_.DisplayName -like '*SQL Server*' -or $_.DisplayName -like '*Cohesity*'} | Sort-Object DisplayName


##Display all the information
#$ServerInformation
#$SQLInformation
#$ServicesInfo | Format-Table
#$InstanceConfigInfo | Format-Table


##CSS code for styling the report
$CSSheader = @"
<style>

    h1 {
        font-family: Arial, Helvetica, sans-serif;
        color: #1893f8;
        font-size: 28px;
    }
    
    h2 {
        font-family: Arial, Helvetica, sans-serif;
        color: #251e9d;
        font-size: 16px;
    } 
    
   table {
		font-size: 12px;
		border: 0px; 
		font-family: Arial, Helvetica, sans-serif;
	} 
	
    td {
		padding: 4px;
		margin: 0px;
		border: 0;
	}
	
    th {
        background: #395870;
        background: linear-gradient(#49708f, #1893f8);
        color: #fff;
        font-size: 11px;
        text-transform: uppercase;
        padding: 10px 15px;
        vertical-align: middle;
	}

    tbody tr:nth-child(even) {
        background: ##f0f0f2;
    }  

    #GeneratedFrom {
        font-family: Arial, Helvetica, sans-serif;
        color: #ff3300;
        font-size: 11px;
    }

    .StopStatus {

        color: #ff0000;
    }    
  
    .RunningStatus {

        color: #008000;
    }

    .DBOfflineStatus {

        color: #ff0000;
    }    
  
    .DBOnlineSStatus {

        color: #008000;
    }

</style>
"@


##Prepare HTML bodies
$HostName = "<h1>Server Name: $ServerName</h1>"

$ServerInformationHTML = $ServerInformation | ConvertTo-Html -As List -Property FQDN, OS, CPU, Memory, 'Last BootUp Time' -Fragment -PreContent "<h2>VM Information</h2>"

$SQLInformationHTML = $SQLInformation | ConvertTo-Html -As List -Property FQDN, InstanceName, Product, Edition, Build, 'Number of User Databases', 'Online User Databases', 'Problematic User Databases' -Fragment -PreContent "<h2>SQL Server Information</h2>"

$ServicesInfoHTML = $ServicesInfo | ConvertTo-Html -Property DisplayName, State, StartName, StartMode -Fragment -PreContent "<h2>SQL Services</h2>"
$ServicesInfoHTML = $ServicesInfoHTML -replace '<td>Running</td>','<td class="RunningStatus">Running</td>'
$ServicesInfoHTML = $ServicesInfoHTML -replace '<td>Stopped</td>','<td class="StopStatus">Stopped</td>'

$InstanceConfigInfoHTML = $InstanceConfigInfo | ConvertTo-Html -Property DisplayName, RunValue -Fragment -PreContent "<h2>SQL Instance Configurations</h2>"

##Combine HTML bodies
$NetBiosName = $Server.ComputerNamePhysicalNetBIOS
$Title = "$NetBiosName Validation"
$HTMLCombined = ConvertTo-HTML -Body "$HostName $ServerInformationHTML $SQLInformationHTML $ServicesInfoHTML $InstanceConfigInfoHTML" -Head  $CSSheader -Title $Title -PostContent "<p id='GeneratedFrom'>Generated from: $env:computername</p>"

##Output to HTML file
$datetime = Get-Date -format yyyy-MM-ddTHH-mm-ss
$FileName = 'C:\Temp\'+$NetBiosName+'_Validation_'+$datetime+'.html'
$HTMLCombined | Out-File $FileName


###Display items that need attention
##Problematic databases
if ($NotOnlineUserDatabaseCount.Count -ne 0)
{
    Write-Warning "Below databases are not online on $ServerName :" ## -ForegroundColor White -BackgroundColor Blue
    $DisplayPrbDBs = $data | Select-Object @{name="ServerName"; expression={$ServerName}}, name, state_desc | Where-Object {$_.state_desc -ne 'ONLINE'}
    $DisplayPrbDBs | Out-String
}

##Stopped SQL Services
if ($ServicesInfo.State -contains "Stopped")
{
    Write-Warning "Below services are not online on $ServerName :" ## -ForegroundColor White -BackgroundColor Blue
    $DisplayPrbSvcs = $ServicesInfo | Select-Object @{name="ServerName"; expression={$ServerName}}, DisplayName, State, StartName, StartMode | Where-Object {$_.State -ne 'Running'}
    $DisplayPrbSvcs | Format-Table | Out-String
}

##If all databases and services are online, display below message
if ($NotOnlineUserDatabaseCount.Count -eq 0 -and $ServicesInfo.State -notcontains "Stopped")
{
    Write-Host "Didn't spot issues with databases or SQL services on" $ServerName -ForegroundColor White -BackgroundColor Blue
}

##Display location of HTML report
Write-Host "SQL Server build on" $ServerName "is:" $SQLInfo.VersionString -ForegroundColor White -BackgroundColor Blue
Write-Host "Detailed report for" $ServerName "is located here:" $FileName"`n`n" -ForegroundColor White -BackgroundColor Blue