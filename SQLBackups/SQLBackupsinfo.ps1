$Datacenter = 'TKDC'
$HostServer = "P053SQLMGMT01.APCUST.LOCAL"
$HostDB = "DBASUPPORT"
$Table = "SQLBackups_info"

$ServerList = "select name from msdb.dbo.sysmanagement_shared_registered_servers_internal where server_group_id = 15 order by server_group_id,name"
$Servers = Invoke-Sqlcmd -ServerInstance $HostServer -Query $ServerList | Select-Object name -ExpandProperty name | Sort-Object name
$Servers = $Servers.name
#$Servers="P054RVL1ASQL00.uscust.local"

$TableQuery = @"   
IF OBJECT_ID('$Table','U') is not null
TRUNCATE TABLE $Table
ELSE

CREATE TABLE [dbo].[$Table](
	[Datacenter] [nvarchar](10) NULL,
	[SqlInstance] [nvarchar](50) NULL,
	[DatabaseName] [nvarchar](300) NULL,
	[State] [nvarchar](20) NULL,
	[RecoveryModel] [nvarchar](20) NULL,
	[LastFull] [datetime] NULL,
	[TimeSince LastFull_inDays] int NULL,
	[FullBackupSize] [nvarchar](10) NULL,
	[LastT-Log] [datetime] NULL,
	[TimeSince LastT-Log_inMins] int NULL,
	[T-LogBackupSize] [nvarchar](10) NULL,
	[LastUpdated] [datetime] DEFAULT GETDATE() NOT NULL
	) ON [PRIMARY]
GO

"@
 Invoke-Sqlcmd -ServerInstance $HostServer -Database $HostDB -Query $TableQuery

foreach($Server in $Servers)
{
write-host $Server

$DBBackups=""
$BackupQuery= "WITH MostRecentBackups
   AS(
      SELECT 
         database_name AS [Database],
         MAX(bus.backup_finish_date) AS LastBackupTime,
         CASE bus.type
            WHEN 'D' THEN 'Full'
            WHEN 'I' THEN 'Differential'
            WHEN 'L' THEN 'Transaction Log'
         END AS Type
      FROM msdb.dbo.backupset bus
      WHERE bus.type <> 'F'
      GROUP BY bus.database_name,bus.type
   ),
   BackupsWithSize
   AS(
      SELECT mrb.*, (SELECT TOP 1 CONVERT(DECIMAL(10,2), b.backup_size/1024/1024/1024) AS backup_size FROM msdb.dbo.backupset b WHERE [Database] = b.database_name AND LastBackupTime = b.backup_finish_date) AS [Backup Size]
      FROM MostRecentBackups mrb
   )
   
   SELECT 
      '$DataCenter' as Datacenter,  
      '$Server' AS SqlInstance, 
      d.name AS [DatabaseName],
      d.state_desc AS State,
      d.recovery_model_desc AS [RecoveryModel],
      bf.LastBackupTime AS [LastFull],
		DATEDIFF(DAY,bf.LastBackupTime,GETDATE()) AS [TimeSinceLastFull_inDays],
        bf.[Backup Size] AS [FullBackupSize],
--      bd.LastBackupTime AS [Last Differential],
--      DATEDIFF(DAY,bd.LastBackupTime,GETDATE()) AS [Time Since Last Differential (in Days)],
--      bd.[Backup Size] AS [Differential Backup Size],
      bt.LastBackupTime AS [LastTLog],
	  DATEDIFF(MINUTE,bt.LastBackupTime,GETDATE()) AS [TimeSinceLastTLog_inMins],
      bt.[Backup Size] AS [TLogBackupSize]
   FROM sys.databases d
   LEFT JOIN BackupsWithSize bf ON (d.name = bf.[Database] AND (bf.Type = 'Full' OR bf.Type IS NULL))
   LEFT JOIN BackupsWithSize bd ON (d.name = bd.[Database] AND (bd.Type = 'Differential' OR bd.Type IS NULL))
   LEFT JOIN BackupsWithSize bt ON (d.name = bt.[Database] AND (bt.Type = 'Transaction Log' OR bt.Type IS NULL))
   WHERE d.name <> 'tempdb' AND d.source_database_id IS NULL  AND d.state_desc not in ('OFFLINE') AND d.is_read_only =0
   AND (DATEDIFF(DAY,bf.LastBackupTime,GETDATE())>3 OR (DATEDIFF(MINUTE,bt.LastBackupTime,GETDATE()) >120 AND d.recovery_model_desc != 'SIMPLE'))"

    $DBBackups = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query $BackupQuery -QueryTimeout 0 

    Foreach($DBBackup in $DBBackups)
    {

    $Datacenter=$DBBackup.Datacenter; $SqlInstance = $DBBackup.SQLInstance; $DatabaseName=$DBBackup.DatabaseName; $State=$DBBackup.state; $RecoveryModel=$DBBackup.RecoveryModel; $Lastfull= $DBBackup.Lastfull; 
    $TimeSinceLastFull_inDays=$DBBackup.TimeSinceLastFull_inDays; $FullBackupSize=$DBBackup.FullBackupSize; $LastTLog=$DBBackup.LastTLog; $TimeSinceLastTLog_inMins=$DBBackup.TimeSinceLastTLog_inMins; $TLogBackupSize=$DBBackup.TLogBackupSize; 
   

    $Insert = "INSERT into dbo.$Table ([Datacenter], [SqlInstance], [DatabaseName],[State],[RecoveryModel],[LastFull],[TimeSince LastFull_inDays],[FullBackupSize],[LastT-Log],[TimeSince LastT-Log_inMins],[T-LogBackupSize])
                            VALUES ('$Datacenter','"  + $SqlInstance + "','" + $DatabaseName + "','" + $State + "','" + $RecoveryModel + "','" + $Lastfull + "','" + $TimeSinceLastFull_inDays + "',
                            '" + $FullBackupSize + "','" + $LastTLog + "','" + $TimeSinceLastTLog_inMins + "','" + $TLogBackupSize + "')"
    
    Invoke-Sqlcmd -ServerInstance $HostServer -Database $HostDB -Query $Insert -Verbose;
    }

}

