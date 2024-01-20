[CmdletBinding()]
Param(
  [Parameter(Mandatory=$True)][string]$CohesityCluster,    
  [Parameter(Mandatory=$True)][string]$SourceServer,
  [Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()]$SourceInstanceName,
  [Parameter(Mandatory=$True)][string]$TargetServer,
  [Parameter(Mandatory=$True)][ValidateNotNullOrEmpty()]$TargetInstanceName,
  [Parameter(Mandatory=$True)][string]$SourceDatabase,
  [Parameter(Mandatory=$True)][string]$TargetDatabase, 
  [Parameter(Mandatory=$True,HelpMessage="Enter Values (Y,N).")][ValidateSet("Y", "N")][string]$DevtoProd
)


if((![string]::IsNullOrWhitespace($TargetInstanceName)))
{
$DestInst = $TargetServer +'\'+ $TargetInstanceName
}
else
{
$DestInst=$TargetServer
}
$DefaultDatapath = Invoke-Sqlcmd -ServerInstance $DestInst -Query "SELECT SERVERPROPERTY('InstanceDefaultDataPath') AS DataPath" | select DataPath -ExpandProperty DataPath
$DataVol = Get-DbaDiskSpace -ComputerName $DestInst | Sort-Object Free -Descending| Where-Object {$_.label -match "Data"} | Select-Object -First 1 Name,Capacity,Free -ExpandProperty Name
$DataVol = $DataVol.Substring(0,$DataVol.Length-1)

$DefDatapath01 = $DefaultDatapath | Split-Path 
$DefDatapath = $DefDatapath01 | Split-Path 

#$DataSecVol = Get-DbaDbFile -SqlInstance $TargetServer | Sort-Object Size -Descending | Where-Object {$_.ID -eq 3 -and $_.database -match "EDDS"} | Select-Object -First 1 PhysicalName -ExpandProperty PhysicalName
#$DataSecpath = $DataSecVol | Split-Path

$mdfFolder = $DefaultDatapath.Replace($DefDatapath,$DataVol)
$ldfFolder = Invoke-Sqlcmd -ServerInstance $DestInst -Query "SELECT SERVERPROPERTY('InstanceDefaultLogPath') AS LogPath" | select LogPath -ExpandProperty LogPath

if((![string]::IsNullOrWhitespace($SourceInstanceName)))
{
$SourceDatabase = $SourceInstanceName +'/'+ $SourceDatabase
}
<#
if((![string]::IsNullOrWhitespace($TargetInstanceName)))
{
$TargetDatabase = $TargetInstanceName +'/'+ $TargetDatabase
}
#>

$username = $env:UserName
$domain = 'Amer.EPIQCORP.COM'
$SourceServer = $SourceServer+'.'+$domain
$TargetServer = $TargetServer+'.'+$domain


$SourceServer, $SourceInstanceName , $TargetServer , $TargetInstanceName,  $SourceDatabase ,  $TargetDatabase,$DataPath, $LogPath

D:\PowerShell\Cohesity_PS\PS\restoreSQL.ps1 -vip $CohesityCluster `
                                        -username $username `
                                        -domain $domain `
                                        -clusterName $CohesityCluster `
                                        -sourceServer $SourceServer `
                                        -targetServer $TargetServer `
                                        -sourceDB $SourceDatabase `
                                        -targetDB $TargetDatabase `
                                        -mdfFolder $mdfFolder `
                                        -ldfFolder $ldfFolder `
                                        -latest `
                                        -progress `
                                        -overWrite
                                      
                                        
If($DevtoProd -eq "Y")
{
$Permissionsquery= 
"ALTER DATABASE $TargetDatabase SET RECOVERY FULL
GO
IF EXISTS (SELECT name FROM sys.databases WHERE name = '$TargetDatabase') 
BEGIN
DECLARE @sql VARCHAR(4000)
SET @sql = 'use $TargetDatabase 
        exec sp_changedbowner ''sa''
       exec dbo.RegenerateMasterKey
       --EXEC sp_change_users_login ''update_one'',''ocr'',''ocr''
       EXEC sp_change_users_login ''update_one'',''usrca'',''usrca''
       EXEC sp_change_users_login ''update_one'',''ca_web_user'',''ca_web_user''
       EXEC sp_droprolemember ''db_owner'',''amer\CA_ApplicationDev''
       EXEC sp_droprolemember ''db_owner'', ''AMER\CA-ETLMatrix-User''
       EXEC sp_droprolemember ''db_owner'',''ECA_DataAnalysts''
       EXEC sp_droprolemember ''db_owner'', ''AMER\CA-ETLMatrix-User''
       EXEC sp_addrolemember ''db_datareader'',''amer\CA_ApplicationDev''
       EXEC sp_droprolemember ''role_STG_Developer'',''AMER\DLG-ECAR-DB-STG-IND-Developer''
       EXEC sp_droprolemember ''db_ddladmin'',''AMER\DLG-ECAR-DB-STG-IND-Developer''
       grant view definition to [AMER\ca_applicationdev] '
EXEC sp_sqlexec @Sql
END"      

Invoke-Sqlcmd -ServerInstance $DestInst -Query $Permissionsquery -QueryTimeout 0
}
else
{
$Permissionsquery= 
"ALTER DATABASE $TargetDatabase SET RECOVERY SIMPLE
GO

DECLARE @sql VARCHAR(4000)
SET @sql = 'use $TargetDatabase 
       exec sp_changedbowner ''sa''
       exec dbo.RegenerateMasterKey
    EXEC sp_change_users_login ''Report''
    EXEC sp_change_users_login ''update_one'',''usrca'',''usrca''
    EXEC sp_change_users_login ''update_one'',''rptuser'',''rptuser''  -- this may fail, that's okay
    EXEC sp_change_users_login ''update_one'',''UsrCA'',''UsrCA''
    EXEC sp_change_users_login ''update_one'',''CA_Web_User'',''CA_Web_User''     
	EXEC sp_addrolemember ''db_owner'',''ECA_DataAnalysts''
    EXEC sp_addrolemember ''db_owner'',''amer\CA_ApplicationDev''
    exec sp_addrolemember ''db_datareader'', ''AMER\ET-GG-ECA_PWRQRY'' '
EXEC sp_sqlexec @Sql"      

Invoke-Sqlcmd -ServerInstance $DestInst -Query $Permissionsquery -QueryTimeout 0
}
#Get-DbaDiskSpace -ComputerName P054ECASQLP51.AMER.EPIQCORP.COM | Sort-Object Free -Descending | Where-Object {$_.label -match "Data"} | Select-Object -First 1 Name,Capacity,Free -ExpandProperty Name
#Show-DbaInstanceFileSystem -SqlInstance p077rl1isql03.client.dtiglobal.com\dist03
#Get-DbaDbFile -SqlInstance $TargetServer | Sort-Object Size -Descending | Where-Object {$_.ID -eq 3 -and $_.database -match "EDDS"} | Select-Object -First 1 PhysicalName