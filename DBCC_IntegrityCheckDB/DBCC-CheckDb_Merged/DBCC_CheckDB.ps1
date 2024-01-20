$DataCenter = 'LVDC'
$HostServer = "P054SQLMGMT02\SQLADMIN"
$HostDB = "DBASUPPORT"
$CheckDbTable = "DBCC_CheckDb"
$CommandLogtable= "DBCC_CheckDb_CommandLog"

$ServerList = "select name from msdb.dbo.sysmanagement_shared_registered_servers_internal where server_group_id=9"
$Servers = Invoke-Sqlcmd -ServerInstance $HostServer -Query $ServerList | Select-Object name -ExpandProperty name | Sort-Object name
$Servers = $Servers.name
#$Servers = "P054DNFSQLS01.uscust.local\DNF"

$CheckDbtblQuery = @"   
IF OBJECT_ID('$CheckDbTable','U') is not null
TRUNCATE TABLE $CheckDbTable
ELSE

CREATE TABLE [dbo].[$CheckDbTable](
	[DataCenter] [nvarchar](10) NULL,
	[SqlInstance] [nvarchar](50) NULL,
	[Database] [nvarchar](300) NULL,
	[LastGoodCheckDb] [nvarchar](50) NULL,
	[DaysSinceLastGoodCheckDb] VARCHAR(25),
	[LastUpdated] [datetime] DEFAULT GETDATE()
) ON [PRIMARY]
GO

"@

 Invoke-Sqlcmd -ServerInstance $HostServer -Database $HostDB -Query $CheckDbtblQuery

$CommandlogtblQuery = @"   
IF OBJECT_ID('$CommandLogtable','U') is not null
TRUNCATE TABLE [$CommandLogtable]
ELSE

CREATE TABLE [dbo].[$CommandLogtable](
	[DataCenter] [nvarchar](10) NULL,
	[SqlInstance] [nvarchar](50) NULL,
	[Database] [nvarchar](500) NULL,
	[StartTime] [nvarchar](50) NULL,
	[EndTime] [nvarchar](50) NULL,
	[ErrorNumber] int
) ON [PRIMARY]
GO

"@
 Invoke-Sqlcmd -ServerInstance $HostServer -Database $HostDB -Query $CommandlogtblQuery

foreach($Server in $Servers)
{
 Write-Host $Server
## DataLoad to CheckDB Table 

$CheckDBArray = ""   
$CheckDBArray = @() 

$CheckDbQuery="SET NOCOUNT ON;
            DBCC TRACEON (3604);

            if object_id('tempdb..#temp') is not null DROP TABLE #temp
            if object_id('tempdb..#Results') is not null DROP TABLE #Results

            CREATE TABLE #temp (
                    Id INT IDENTITY(1,1), 
                    ParentObject VARCHAR(255),
                    [Object] VARCHAR(255),
                    Field VARCHAR(255),
                    [Value] VARCHAR(255)
            )

            CREATE TABLE #Results (
		            DataCenter nvarchar(15),
		            SQLInstance nvarchar(100),
                    [Database] VARCHAR(500),
                    [LastGoodCheckDBTime] VARCHAR(25),
		            DaysSinceLastGoodCheckDb VARCHAR(25),
		            Status VARCHAR(50)
            )
            DECLARE @DataCenter VARCHAR(10) = '$DataCenter'
            DECLARE @Name VARCHAR(500);
            DECLARE @SQLInstance VARCHAR(100) = '$Server'
            DECLARE @DaysSinceLastGoodCheckDb VARCHAR(100)
            DECLARE @Status VARCHAR(100) = 'CheckDB should be performed'

            DECLARE looping_cursor CURSOR
            FOR

            SELECT name
            FROM master.dbo.sysdatabases
            WHERE CONVERT(varchar(500),databasepropertyex(name, 'Status'),0) = 'ONLINE'

            OPEN looping_cursor
            FETCH NEXT FROM looping_cursor INTO @Name
            WHILE @@FETCH_STATUS = 0
                BEGIN

                    INSERT INTO #temp
                    EXECUTE('DBCC PAGE (['+@Name+'], 1, 9, 3)WITH TABLERESULTS');

                    INSERT INTO #Results
                    SELECT @DataCenter,@SQLInstance, @Name,MAX(VALUE),@DaysSinceLastGoodCheckDb,@Status FROM #temp
                    WHERE Field = 'dbi_dbccLastKnownGood';

                    truncate table #temp

                FETCH NEXT FROM looping_cursor INTO @Name
                END
            CLOSE looping_cursor;
            DEALLOCATE looping_cursor;

            SELECT DataCenter,SQLInstance,[Database]
                ,ISNULL([LastGoodCheckDBTime],'1900-01-01 00:00:00.000') AS 'LastGoodDBCC'
            	,DATEDIFF(DAY, LastGoodCheckDBTime, GETDATE()) As 'DaysSinceLastGoodCheckDb'
            --	,Status
            FROM #Results
            where [Database] not in ('tempdb') -- and LastGoodDBCC <= DATEADD(day,-14, GETDATE())"

 $CheckDBArray += Invoke-Sqlcmd -ServerInstance $Server -Query $CheckDbQuery
 $CheckDBArray | Write-DbaDataTable -SqlInstance $HostServer -Database $HostDB -Schema dbo -Table $CheckDbTable -BatchSize 5000 -KeepNulls 

## DataLoad to CommandLog Table  
$CommandLogArray = ""   
$CommandLogArray = @() 

$CommandLogQuery= "select '$DataCenter' as Datacenter,'$Server' As SqlInstance,databasename,StartTime,EndTime, ErrorNumber from [master].[dbo].[CommandLog] WHERE databasename in (SELECT name FROM master.dbo.sysdatabases WHERE CONVERT(varchar(500),databasepropertyex(name, 'Status'),0) = 'ONLINE' and name not in ('tempdb')) and StartTime IN (SELECT MAX(StartTime) FROM [master].[dbo].[CommandLog]  GROUP BY DatabaseName)"

$CommandLogArray = Invoke-Sqlcmd -ServerInstance $Server -Query $CommandLogQuery -QueryTimeout 0 
$CommandLogArray | Write-DbaDataTable -SqlInstance $HostServer -Database $HostDB -Schema dbo -Table $CommandLogtable -BatchSize 5000 -KeepNulls 
}

