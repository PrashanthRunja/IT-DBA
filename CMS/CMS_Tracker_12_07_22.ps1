
$HostServer = "P054SQLMGMT02\SQLADMIN"
$HostDB = "DBASUPPORT"

$ServerList = "select name from msdb.dbo.sysmanagement_shared_registered_servers_internal where server_group_id=9"
$Servers = Invoke-Sqlcmd -ServerInstance $HostServer -Query $ServerList | Select-Object name -ExpandProperty name | Sort-Object name
$Servers = $Servers.name
#$Servers = "D016RDSWRKS01.amer.EPIQCORP.COM\EDMADEV"

$CMSQuery = @"   
IF OBJECT_ID('CMS_Tracker','U') is not null
TRUNCATE TABLE CMS_Tracker
ELSE

CREATE TABLE [dbo].[CMS_Tracker](
	[DataCenter] [nvarchar](200) NULL,
	[ConnectedServer] [nvarchar](200) NULL,
	[Instance] [nvarchar](200) NULL,
	[NodeName] [nvarchar](50) NULL,
	[Is_Clustered] [nvarchar](5) NULL,
	[Is_Physical] [nvarchar](5) NULL,
	[Domain] [nvarchar](50) NULL,
	[IPAddress] [nvarchar](50) NULL,
	[OSVersion] [nvarchar](max) NULL,
	[SQLEdition] [nvarchar](max) NULL,
	[EditionBit] [nvarchar](50) NULL,
	[SQLVersion] [nvarchar](50) NULL,
	[SQLBuild] [nvarchar](50) NULL,
	[SPLevel] [nvarchar](50) NULL,
	[UserDatabases] [nvarchar](50) NULL,
	[DatabaseGB] [nvarchar](50) NULL,
	[DataSizeGB] [nvarchar](50) NULL,
	[MemoryGB] [nvarchar](50) NULL,
	[Processors] [nvarchar](50) NULL,
	[Cores] [nvarchar](50) NULL,
	[CPU] [nvarchar](50) NULL,
	[TotalCapacityGB] [nvarchar](50) NULL,
	[TotalFreespaceGB] [nvarchar](50) NULL,
	[FreePercent] [nvarchar](50) NULL,
	[LastUpdated] [datetime] DEFAULT GETDATE()
) ON [PRIMARY] 

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
				END AS [Is Clustered?],
				CONNECTIONPROPERTY(''local_net_address'') AS local_net_address,
				CASE LEFT(CONVERT(VARCHAR, SERVERPROPERTY(''ProductVersion'')),4) 
				WHEN ''11.0'' THEN ''SQL Server 2012''
				WHEN ''12.0'' THEN ''SQL Server 2014''
				WHEN ''13.0'' THEN ''SQL Server 2016''
				WHEN ''14.0'' THEN ''SQL Server 2017''
				WHEN ''15.0'' THEN ''SQL Server 2019''
				ELSE ''Newer than SQL Server 2019''
				END AS [Version Build],
				SERVERPROPERTY(''ProductVersion'') AS SQL_Build,
				SERVERPROPERTY (''Edition'') AS [Edition],
				SERVERPROPERTY(''ProductLevel'') AS [Service Pack],
				/*CASE SERVERPROPERTY(''IsIntegratedSecurityOnly'') 
				WHEN 0 THEN ''SQL Server and Windows Authentication mode''
				WHEN 1 THEN ''Windows Authentication mode''
				END AS [Server Authentication]*/
				[cpu_count] AS [CPUs],
				[physical_memory_kb]/1024 /1024 AS [RAM (GB)]
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
				SERVERPROPERTY (''Edition'') AS [Edition],
				CONNECTIONPROPERTY(''local_net_address'') AS local_net_address,
				SERVERPROPERTY(''ProductVersion'') AS SQL_Build,
				SERVERPROPERTY(''ProductLevel'') AS [Service Pack],
				CASE SERVERPROPERTY(''IsIntegratedSecurityOnly'') 
				WHEN 0 THEN ''SQL Server and Windows Authentication mode''
				WHEN 1 THEN ''Windows Authentication mode''
				END AS [Server Authentication],
				CASE SERVERPROPERTY(''IsClustered'') 
				WHEN 0 THEN ''False''
				WHEN 1 THEN ''True''
				END AS [Is Clustered?],
				SERVERPROPERTY(''ComputerNamePhysicalNetBIOS'') AS [Current Node Name],
				SERVERPROPERTY(''Collation'') AS [ SQL Collation],
				[cpu_count] AS [CPUs],
				[physical_memory_in_bytes]/1048576 AS [RAM (MB)]
				FROM  
				[sys].[dm_os_sys_info]'
              )
        ELSE
          SELECT 'This SQL Server instance is running SQL Server 2000 or lower! You will need alternative methods in getting the SQL instance level information.'


"@
Write-Host $instance

    $sql_out = Invoke-Sqlcmd -ServerInstance $instance -Query $query
    
 
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
    $DatabaseGB = ($DBs.DatabaseGB | Measure-Object -sum ).sum
    $DataSizeGB = ($DBs.DataSizeGB | Measure-Object -sum ).sum    

    $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ComputerName $computer | select Domain, Model, NumberOfProcessors 

    $domain = $cs.domain
    $model = $cs.model
    if(($model -like "VMware Virtual Platform") -or ($model -like "Virtual Machine") -or ($model -like "VirtualBox") -or ($model -match "VMware"))
    {
    $IS_Physical = 'N'
    } 
    elseif ($model.count -eq 0)
    {
    $IS_Physical = ""
    }
    else 
    {
    $IS_Physical = 'Y'
    }

    $IP = $sql_out.local_net_address
    if(([string]::IsNullOrWhitespace($IP)))
    {
    $IP = Invoke-Sqlcmd -ServerInstance $instance -Database master -Query "SELECT TOP(1) local_net_address AS address FROM sys.dm_exec_connections WHERE local_net_address IS NOT NULL;" | Select-Object address -ExpandProperty address
    }
    
    $cluster = @"   
            SELECT
            (SELECT create_date FROM sys.databases WHERE name = 'tempdb'),
            SERVERPROPERTY('servername') AS 'ServerName',
            SERVERPROPERTY('machinename') AS 'Windows_Name',
            SERVERPROPERTY('ComputerNamePhysicalNetBIOS') AS 'NetBIOS_Name',
            SERVERPROPERTY('instanceName') AS 'InstanceName',
            (SELECT top 1 1 FROM MASTER.dbo.sysprocesses WHERE program_name like 'sqLAgent%') SQLAgentUP,
            SERVERPROPERTY('IsClustered') AS 'IsClustered',
            ( SELECT top 1 ec.local_tcp_port as 'SQL Port' from sys.dm_exec_connections ec
            where ec.session_id = @@SPID) as TCP_Port,
            ( SELECT top 1 ec.local_net_address as 'IP Addr' from sys.dm_exec_connections ec
            where ec.session_id = @@SPID) as TCP_IP
"@
    $clus = Invoke-Sqlcmd -ServerInstance $instance -Query $cluster -ErrorAction SilentlyContinue

 
    $Nodename  = $clus.NetBIOS_Name
    if($clus.IsClustered -eq 1)
    {
    $IS_Clus = 'Y'
    } 
    else 
    {
    $IS_Clus = 'N'
    }


    $OS = Get-CimInstance -ComputerName $computer -ClassName win32_operatingsystem | select caption,BuildNumber
    $OS_version = $OS.caption + " (Build " + $OS.BuildNumber +":)"

    $memory = Invoke-Command -ComputerName $computer {Get-WmiObject win32_computersystem} | select @{name="RAM";e={[math]::Round($_.totalphysicalmemory/1GB,0)}}
    $memory = $memory.RAM

    $processor = Get-CimInstance -ComputerName $computer -ClassName win32_processor | select NumberofCores,Name
    $cores = ($processor | Measure-Object -sum NumberofCores).sum
    

    $disks = Get-CimInstance -ComputerName $computer -ClassName Win32_Volume | Where {@("C:\","T:\") -notcontains $_.name -and $_.drivetype -eq '3' -and $_.name -notmatch "Volume" -and $_.name -notmatch "TEMPDB"} | SELECT name,capacity,freespace
    if(([string]::IsNullOrWhitespace($disks)))
    {
    $disks = Get-CimInstance -ComputerName $computer -ClassName Win32_Volume | Where {$_.drivetype -eq '3' -and $_.name -notmatch "Volume" } | SELECT name,capacity,freespace
    }

    $totalCapacity = ($disks.Capacity | Measure-Object -sum ).sum
    $totalCapacity = [math]::Round($totalCapacity / 1GB,2)
    $totalFreespace = ($disks.freespace | Measure-Object -sum ).sum
    $totalFreespace = [math]::Round($totalFreespace / 1GB,2)
    $PercentFree = [Math]::round((($totalFreespace/$totalCapacity) * 100))


    $SQLEdition = $sql_out.Edition
    $EditionBit = $sql_out.Edition.Split(" ")[-1].split("(").split(")")[1]
    $SQLVersion = $sql_out.'Version Build'
    $SQLBuild = $sql_out.SQL_Build
    $SPLevel = $sql_out.'Service Pack'
    $Processors = $cs.NumberOfProcessors
    $CPU = $processor[0].name

    $Insert = "INSERT into dbo.CMS_Tracker (DataCenter, ConnectedServer, Instance, NodeName, Is_Physical, Is_Clustered , Domain, IPAddress, OSVersion, 
    SQLEdition, EditionBit, SQLVersion, SQLBuild, UserDatabases, DatabaseGB, DataSizeGB, SPLevel, MemoryGB, Processors, Cores, CPU, TotalCapacityGB, TotalFreespaceGB, FreePercent)
                            VALUES ('LVDC','" + $computer + "','" + $instance + "','" + $Nodename + "','" + $IS_Physical + "','" + $IS_Clus + "','" + $domain + "','" + $IP + "','" + $OS_version + "',
                            '" + $SQLEdition + "','" + $EditionBit + "','" + $SQLVersion + "','" + $SQLBuild + "'
                            ,'" + $Databases + "','" + [math]::Round($DatabaseGB,2) + "','" + [math]::Round($DataSizeGB,2) + "'
                            ,'" + $SPLevel + "','" + $memory + "','" + $Processors + "','" + $cores + "','" + $CPU + "'
                            ,'" + $totalCapacity + "','" + $totalFreespace + "','" + $PercentFree + "')"

    Invoke-Sqlcmd -ServerInstance $HostServer -Database $HostDB -Query $Insert -Verbose;

         
  }