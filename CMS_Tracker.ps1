$Datacenter = 'LVDC'
$HostServer = "P054SQLMGMT02\SQLADMIN"
$HostDB = "DBASUPPORT"

$ServerList = "select name from msdb.dbo.sysmanagement_shared_registered_servers_internal where server_group_id=9"
$Servers = Invoke-Sqlcmd -ServerInstance $HostServer -Query $ServerList | Select-Object name -ExpandProperty name | Sort-Object name
$Servers = $Servers.name
#$Servers = "P054SQLCI1601.USCUST.LOCAL\PORTAL"

$CMSQuery = @"   
IF OBJECT_ID('CMS_Tracker','U') is not null
TRUNCATE TABLE CMS_Tracker
ELSE

CREATE TABLE [dbo].[CMS_Tracker](
	[DataCenter] [nvarchar](200) NULL,
	[ConnectedServer] [nvarchar](200) NULL,
	[Instance] [nvarchar](200) NOT NULL,
	[NodeName] [nvarchar](50) NULL,
	[Is_Clustered] [nvarchar](5) NULL,
	[Is_Physical] [nvarchar](5) NULL,
	[Domain] [nvarchar](50) NULL,
	[IPAddress] [nvarchar](50) NULL,
	[OSVersion] [nvarchar](max) NULL,
	[SQLVersion] [nvarchar](50) NULL,
	[SQLEdition] [nvarchar](max) NULL,
	[EditionBit] [nvarchar](50) NULL,
	[SQLBuild] [nvarchar](50) NULL,
	[SPLevel] [nvarchar](50) NULL,
        [CurrentCU] [nvarchar](10) NULL,
	[UserDatabases] [smallint] NULL,
	[DatabaseGB] [int] NULL,
	[DataSizeGB] [int] NULL,
	[MemoryGB] [smallint] NULL,
	[Processors] [smallint] NULL,
	[Cores] [smallint] NULL,
	[CPU] [nvarchar](50) NULL,
	[TotalCapacityGB] [int] NULL,
	[TotalFreespaceGB] [int] NULL,
	[FreePercent] [smallint] NULL,
	[LastUpdated] [datetime] DEFAULT GETDATE(),
	CONSTRAINT PK_Instance PRIMARY KEY (Instance)
)

"@
 Invoke-Sqlcmd -ServerInstance $HostServer -Database $HostDB -Query $CMSQuery

    
    foreach ($SQLInstance in $servers) 
    {
       $instance = $SQLInstance
       #$computer= $instance -replace "\*",""
        if($instance.IndexOf("\") -gt 0) {
             $computer = $instance.Substring(0, $instance.IndexOf("\"))
        } else {
             $computer = $instance
        }

       #$instance = $computer+"\"+$sql
       $sql_out=""
       $query = @"

        DECLARE @version VARCHAR(4)
        DECLARE @result int

        SELECT @version = substring(@@version, 22, 4)

        IF CONVERT(SMALLINT, @version) >= 2012
         EXEC (
				'SELECT 
				SERVERPROPERTY(''ServerName'') AS [Instance Name],
				SERVERPROPERTY(''ComputerNamePhysicalNetBIOS'') AS [Current Node Name],
				CASE SERVERPROPERTY(''IsClustered'') 
				    WHEN 0 THEN ''N''
				    WHEN 1 THEN ''Y''
				END AS [Is Clustered],
                CASE WHEN virtual_machine_type = 1
                    THEN ''N'' 
                    ELSE ''Y''
                END [Is Physical],
                DEFAULT_DOMAIN() As Domain,
				CONNECTIONPROPERTY(''local_net_address'') AS local_net_address,
				CASE LEFT(CONVERT(VARCHAR, SERVERPROPERTY(''ProductVersion'')),4) 
				WHEN ''11.0'' THEN ''SQL Server 2012''
				WHEN ''12.0'' THEN ''SQL Server 2014''
				WHEN ''13.0'' THEN ''SQL Server 2016''
				WHEN ''14.0'' THEN ''SQL Server 2017''
				WHEN ''15.0'' THEN ''SQL Server 2019''
                WHEN ''16.0'' THEN ''SQL Server 2022''
				ELSE ''Newer than SQL Server 2022''
				END AS [Version Build],
				SERVERPROPERTY(''ProductVersion'') AS SQL_Build,
				SERVERPROPERTY (''Edition'') AS [Editionbit],
                CASE (select SERVERPROPERTY(''EditionID''))
                    WHEN -1534726760 then ''Standard''
                    WHEN 1804890536 then ''Enterprise''
                    WHEN 1872460670 then ''Enterprise''
                    WHEN 610778273 then ''Enterprise''
                    WHEN 284895786 then ''Business Intelligence''
                    WHEN -2117995310 then ''Developer''
                    WHEN -1592396055 then ''Express''
                    WHEN -133711905 then ''Express''
                    WHEN 1293598313 then ''Web''
                    WHEN 1674378470 then ''SQL Database or SQL Data Warehouse''
                END as [Edition],
				SERVERPROPERTY(''ProductLevel'') AS [Service Pack],
                SERVERPROPERTY(''ProductUpdateLevel'') AS CurrentCU,
				/*CASE SERVERPROPERTY(''IsIntegratedSecurityOnly'') 
				WHEN 0 THEN ''SQL Server and Windows Authentication mode''
				WHEN 1 THEN ''Windows Authentication mode''
				END AS [Server Authentication]*/
				[cpu_count] AS [Cores],
				cpu_count/hyperthread_ratio AS Processors,
				[physical_memory_kb]/1048000 AS MemoryGB
				FROM  
				[sys].[dm_os_sys_info]'
             )
       

        ELSE IF CONVERT(SMALLINT, @version) >= 2005
          EXEC (
				'SELECT 
				SERVERPROPERTY(''ServerName'') AS [Instance Name],
				CASE LEFT(CONVERT(VARCHAR, SERVERPROPERTY(''ProductVersion'')),4) 
				WHEN ''9.00'' THEN ''SQL Server 2005''
				WHEN ''10.0'' THEN ''SQL Server 2008''
				WHEN ''10.5'' THEN ''SQL Server 2008 R2''
				ELSE ''Older than SQL Server 2005''
				END AS [Version Build],
				SERVERPROPERTY (''Edition'') AS [Editionbit],
                CASE (select SERVERPROPERTY(''EditionID''))
                    WHEN -1534726760 then ''Standard''
                    WHEN 1804890536 then ''Enterprise''
                    WHEN 1872460670 then ''Enterprise''
                    WHEN 610778273 then ''Enterprise''
                    WHEN 284895786 then ''Business Intelligence''
                    WHEN -2117995310 then ''Developer''
                    WHEN -1592396055 then ''Express''
                    WHEN -133711905 then ''Express''
                    WHEN 1293598313 then ''Web''
                    WHEN 1674378470 then ''SQL Database or SQL Data Warehouse''
                END as [Edition],
				CONNECTIONPROPERTY(''local_net_address'') AS local_net_address,
				SERVERPROPERTY(''ProductVersion'') AS SQL_Build,
				SERVERPROPERTY(''ProductLevel'') AS [Service Pack],
                SERVERPROPERTY(''ProductUpdateLevel'') AS CurrentCU,
				CASE SERVERPROPERTY(''IsIntegratedSecurityOnly'') 
				WHEN 0 THEN ''SQL Server and Windows Authentication mode''
				WHEN 1 THEN ''Windows Authentication mode''
				END AS [Server Authentication],
				CASE SERVERPROPERTY(''IsClustered'') 
				    WHEN 0 THEN ''N''
				    WHEN 1 THEN ''Y''
				END AS [Is Clustered],
                CASE WHEN virtual_machine_type = 1
                    THEN ''N'' 
                    ELSE ''Y''
                END [Is Physical],
                DEFAULT_DOMAIN() As Domain,
				SERVERPROPERTY(''ComputerNamePhysicalNetBIOS'') AS [Current Node Name],
				SERVERPROPERTY(''Collation'') AS [ SQL Collation],
				[cpu_count] AS [Cores],
				[physical_memory_in_bytes]/1073700000 AS MemoryGB,
				cpu_count/hyperthread_ratio AS Processors
				FROM  
				[sys].[dm_os_sys_info]'
              )
        ELSE
          SELECT 'This SQL Server instance is running SQL Server 2000 or lower! You will need alternative methods in getting the SQL instance level information.'

"@
    Write-Host $instance

    $sql_out = Invoke-Sqlcmd -ServerInstance $instance -Query $query
    if((![string]::IsNullOrWhitespace($sql_out)))
    {    

    $dbquery = @"   
                SELECT     
                DB_NAME(db.database_id) DatabaseName,     
                (CAST(mfrows.RowSize AS FLOAT)*8)/1024/1024 'DataSizeGB',     
                (CAST(mflog.LogSize AS FLOAT)*8)/1024/1024 'LogSizeGB', 
                --cast(FORMAT(mfrows.RowSize, 'N2')AS FLOAT *8)/1024/1024 'MDFSize GB',
                (CAST(mfrows.RowSize AS FLOAT)*8)/1024/1024+(CAST(mflog.LogSize AS FLOAT)*8)/1024/1024 'DatabaseGB'
                FROM sys.databases db 
                LEFT JOIN (SELECT database_id, 
				            SUM(CAST(size as bigint)) RowSize
                            FROM sys.master_files 
                            WHERE type = 0  
			                GROUP BY database_id, type) mfrows 
                    ON mfrows.database_id = db.database_id     
                LEFT JOIN (SELECT database_id, 
				            SUM(CAST (size as bigint)) Logsize
                            FROM sys.master_files 
                            WHERE type = 1 
			                GROUP BY database_id, type) mflog 
                    ON mflog.database_id = db.database_id   
			    join sys.databases Sysdb 
			    ON mflog.database_id = Sysdb.database_id 
                where DB_NAME(db.database_id) NOT IN ('master','model','msdb','tempdb') 
			    and Sysdb.source_database_id IS NULL
	                ORDER BY 1

"@

    $DBs = Invoke-Sqlcmd -ServerInstance $instance -Query $dbquery

    $Databases = $DBs.DatabaseName.count
    $DatabaseGB = [math]::Round(($DBs.DatabaseGB | Measure-Object -sum ).sum)
    $DataSizeGB = [math]::Round(($DBs.DataSizeGB | Measure-Object -sum ).sum)    

    $Nodename = $sql_out.'Current Node Name'
    $IS_Clus = $sql_out.'Is Clustered'
    $IS_Physical = $sql_out.'Is Physical'
    #$domain = $sql_out.Domain

    $domainQuery="DECLARE @Domain varchar(100), @key varchar(100)
                    SET @key = 'SYSTEM\ControlSet001\Services\Tcpip\Parameters\'
                    EXEC master..xp_regread @rootkey='HKEY_LOCAL_MACHINE', @key=@key,@value_name='Domain',@value=@Domain OUTPUT 
                    SELECT convert(varchar(100),@Domain) As Domain"
    $domain = Invoke-Sqlcmd -ServerInstance $instance -Query $domainQuery | Select-Object Domain -ExpandProperty Domain

    $IP = $sql_out.local_net_address
    if(([string]::IsNullOrWhitespace($IP)))
    {
    $IP = Invoke-Sqlcmd -ServerInstance $instance -Database master -Query "SELECT TOP(1) local_net_address AS address FROM sys.dm_exec_connections WHERE local_net_address IS NOT NULL;" | Select-Object address -ExpandProperty address
    }
    
    if(([string]::IsNullOrWhitespace($IP)) -or $IP -eq "::1")
    {
    $IP = Test-Connection -ComputerName $computer -Count 1  | Select-Object IPV4Address -ExpandProperty IPV4Address
    $IP=$IP.IPV4Address
    }
    

    #$OS_version = Get-DbaOperatingSystem -ComputerName $computer | Select-Object OSVersion -ExpandProperty OSVersion
    $OS= "Select	CASE SUBSTRING(@@VERSION,CHARINDEX('Windows',@@VERSION,0),15)	WHEN 'Windows NT 6.3' THEN 'Windows Server 2012 R2'	WHEN 'Windows NT 6.2' THEN 'Windows Server 2012'	WHEN 'Windows NT 6.1' THEN 'Windows Server 2008 R2'	ELSE SUBSTRING(@@VERSION,CHARINDEX('Windows',@@VERSION,0),29) 	END AS [OSVersion]"$OS_version = Invoke-Sqlcmd -ServerInstance $instance -Query $OS| Select-Object OSVersion -ExpandProperty OSVersion
    
    $cores = $sql_out.Cores
    $Processors = $sql_out.Processors
    $Model = "EXEC sys.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'HARDWARE\DESCRIPTION\System\CentralProcessor\0', N'ProcessorNameString';"
    $CPU =  Invoke-Sqlcmd -ServerInstance $instance -Query $Model | Select-Object Data -ExpandProperty Data
    $memory = $sql_out.MemoryGB
    

    $diskvolumes = "SELECT DISTINCT 
            CONVERT(CHAR(100), SERVERPROPERTY('Servername')) AS Server,
            volume_mount_point [Disk], 
            file_system_type [File System], 
            logical_volume_name as [Logical Drive Name], 
            CONVERT(DECIMAL(18,2),total_bytes/1073741824.0) AS [Capacity], ---1GB = 1073741824 bytes
            CONVERT(DECIMAL(18,2),available_bytes/1073741824.0) AS [Freespace],  
            CAST(CAST(available_bytes AS FLOAT)/ CAST(total_bytes AS FLOAT) AS DECIMAL(18,2)) * 100 AS [PercentFree] 
            FROM sys.master_files 
            CROSS APPLY sys.dm_os_volume_stats(database_id, file_id)
            where logical_volume_name not like '%Temp%' and volume_mount_point not like 'T%' and volume_mount_point not like '\\%'"
    $disks = Invoke-Sqlcmd -ServerInstance $instance -Query $diskvolumes

    if((![string]::IsNullOrWhitespace($disks)))
    {
    $totalCapacity = [math]::Round(($disks.Capacity | Measure-Object -sum ).sum)
    $totalFreespace = [math]::Round(($disks.freespace | Measure-Object -sum ).sum)
    $PercentFree = [Math]::round((($totalFreespace/$totalCapacity) * 100))
    }
    else
    {
    $totalCapacity= 0
    $totalFreespace = 0
    $PercentFree = 9999
    }


    $SQLEdition = $sql_out.Edition
    $EditionBit = $sql_out.Editionbit.Split(" ")[-1].split("(").split(")")[1]
    $SQLVersion = $sql_out.'Version Build'
    $SQLBuild = $sql_out.SQL_Build
    $SPLevel = $sql_out.'Service Pack'
    $CurrentCU = $sql_out.'CurrentCU'

    $Insert = "INSERT into dbo.CMS_Tracker (DataCenter, ConnectedServer, Instance, NodeName, Is_Physical, Is_Clustered , Domain, IPAddress, OSVersion, 
    SQLEdition, EditionBit, SQLVersion, SQLBuild, UserDatabases, DatabaseGB, DataSizeGB, SPLevel, CurrentCU, MemoryGB, Processors, Cores, CPU, TotalCapacityGB, TotalFreespaceGB, FreePercent)
                            VALUES ('$Datacenter','" + $computer + "','" + $instance + "','" + $Nodename + "','" + $IS_Physical + "','" + $IS_Clus + "','" + $domain + "','" + $IP + "','" + $OS_version + "',
                            '" + $SQLEdition + "','" + $EditionBit + "','" + $SQLVersion + "','" + $SQLBuild + "'
                            ,'" + $Databases + "','" + $DatabaseGB + "','" + $DataSizeGB + "'
                            ,'" + $SPLevel + "','" + $CurrentCU + "','" + $memory + "','" + $Processors + "','" + $cores + "','" + $CPU + "'
                            ,'" + $totalCapacity + "','" + $totalFreespace + "','" + $PercentFree + "')"

    Invoke-Sqlcmd -ServerInstance $HostServer -Database $HostDB -Query $Insert -Verbose;

    }
  }