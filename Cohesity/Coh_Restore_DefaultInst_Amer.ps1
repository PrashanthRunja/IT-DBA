[CmdletBinding()]
Param(
  
  [Parameter(Mandatory=$True)][string]$SourceServer,
  [Parameter(Mandatory=$True)][string]$TargetServer,
  [Parameter(Mandatory=$True)][string]$SourceDatabase,
  [Parameter(Mandatory=$True)][string]$TargetDatabase
)


$CohesityCluster = 'p054dpgcoh201'
$username = '637741'
$domain = 'AMER.EPIQCORP.COM'
$SourceServer = $SourceServer+'.'+$domain
$TargetServer = $TargetServer+'.'+$domain

$DefaultDatapath = Invoke-Sqlcmd -ServerInstance $TargetServer -Query "SELECT SERVERPROPERTY('InstanceDefaultDataPath') AS DataPath" | select DataPath -ExpandProperty DataPath
$DataVol = Get-DbaDiskSpace -ComputerName $TargetServer | Sort-Object Free -Descending | Select-Object -First 1 Name,Capacity,Free -ExpandProperty Name
$DataVol = $DataVol.Substring(0,$DataVol.Length-1)

$DefDatapath01 = $DefaultDatapath | Split-Path 
$DefDatapath = $DefDatapath01 | Split-Path 

$DataPath = $DefaultDatapath.Replace($DefDatapath,$DataVol)
$LogPath = Invoke-Sqlcmd -ServerInstance $TargetServer -Query "SELECT SERVERPROPERTY('InstanceDefaultLogPath') AS LogPath" | select LogPath -ExpandProperty LogPath

$DataPath, $LogPath , $SourceServer , $TargetServer ,  $SourceDatabase ,  $TargetDatabase

D:\PowerShell\Cohesity_PS\PS\restoreSQL.ps1 -vip $CohesityCluster `
                                        -username $username `
                                        -domain $domain `
                                        -sourceDB $SourceDatabase `
                                        -SourceServer $SourceServer `
                                        -clusterName $CohesityCluster `
                                        -TargetServer $TargetServer `
                                        -mdfFolder $DataPath `
                                        -ldfFolder $LogPath `
                                        -targetDB $TargetDatabase `
                                        -overWrite `
                                        -progress `
                                        -latest



$Permissionsquery= 
"ALTER DATABASE $TargetDatabase  SET RECOVERY FULL
GO
IF EXISTS (SELECT name FROM sys.databases WHERE name = '$TargetDatabase') 
BEGIN
DECLARE @sql VARCHAR(4000)
SET @sql = ' use $TargetDatabase 
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

Invoke-Sqlcmd -ServerInstance $TargetServer -Query $Permissionsquery -QueryTimeout 0


#Get-DbaDiskSpace -ComputerName $TargetServer | Sort-Object Free -Descending | Select-Object -First 1 Name,Capacity,Free -ExpandProperty Name