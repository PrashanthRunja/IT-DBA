$Datacenter = 'KADC'
$HostServer = "P082SQLMGMT01.CACUST.LOCAL"
$HostDB = "DBASUPPORT"
$Table = "CommandLog_CheckDB"

$ServerList = "select name from msdb.dbo.sysmanagement_shared_registered_servers_internal where server_group_id=9"
$Servers = Invoke-Sqlcmd -ServerInstance $HostServer -Query $ServerList | Select-Object name -ExpandProperty name | Sort-Object name
$Servers = $Servers.name
#$Servers="P054SQLMGMT03\SQLADMIN"

$TableQuery = @"   
IF OBJECT_ID('$Table','U') is not null
TRUNCATE TABLE [$Table]
ELSE

CREATE TABLE [dbo].[$Table](
	[DataCenter] [nvarchar](10) NULL,
	[SqlInstance] [nvarchar](50) NULL,
	[Database] [nvarchar](500) NULL,
	[StartTime] [nvarchar](50) NULL,
	[EndTime] [nvarchar](50) NULL,
	[ErrorNumber] int,
    [LastUpdated] [datetime] DEFAULT GETDATE()
) ON [PRIMARY]
GO

"@
 Invoke-Sqlcmd -ServerInstance $HostServer -Database $HostDB -Query $TableQuery


foreach ($SQLInstance in $servers) 
{

  write-host $SQLInstance 

$CheckDB = ""   

$query= "select '$DataCenter' as Datacenter,'$SQLInstance' As SqlInstance,databasename,StartTime,EndTime, ErrorNumber from [master].[dbo].[CommandLog] WHERE databasename in (SELECT name FROM master.dbo.sysdatabases WHERE CONVERT(varchar(500),databasepropertyex(name, 'Status'),0) = 'ONLINE' and name not in ('tempdb')) and StartTime IN (SELECT MAX(StartTime) FROM [master].[dbo].[CommandLog]  GROUP BY DatabaseName)"
$CheckDBs = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query $query -QueryTimeout 0 

    Foreach($CheckDB in $CheckDBs)
    {

    $Datacenter=$CheckDB.Datacenter; $SqlInstance = $CheckDB.SqlInstance; $DatabaseName=$CheckDB.DatabaseName; $StartTime=$CheckDB.StartTime; $EndTime=$CheckDB.EndTime; $ErrorNumber= $CheckDB.ErrorNumber; 

    $Insert = "INSERT into dbo.CommandLog_CheckDB ([Datacenter], [SqlInstance], [Database],[StartTime],[EndTime],[ErrorNumber])
                    VALUES ('$Datacenter','"  + $SqlInstance + "','" + $DatabaseName + "','" + $StartTime + "','" + $EndTime + "','" + $ErrorNumber + "')"
    
    Invoke-Sqlcmd -ServerInstance $HostServer -Database $HostDB -Query $Insert -Verbose;
    }
}



