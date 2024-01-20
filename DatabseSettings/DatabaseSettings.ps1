$Datacenter = 'KADC'
$HostServer = "P082SQLMGMT01.CACUST.LOCAL"
$HostDB = "DBASUPPORT"
$Table = "DatabaseSettings"

$ServerList = "select name from msdb.dbo.sysmanagement_shared_registered_servers_internal where server_group_id=9"
$Servers = Invoke-Sqlcmd -ServerInstance $HostServer -Query $ServerList | Select-Object name -ExpandProperty name | Sort-Object name
$Servers = $Servers.name
#$Servers="P054SQLMGMT03\SQLADMIN"

$TableQuery = @"   
IF OBJECT_ID('$Table','U') is not null
TRUNCATE TABLE $Table
ELSE

CREATE TABLE [dbo].[$Table](
	[Datacenter] [nvarchar](10) NULL,
	[SqlInstance] [nvarchar](50) NULL,
	[DatabaseName] [nvarchar](300) NULL,
	[DateCreated] [date] NULL,
	[RecoveryModel] [nvarchar](20) NULL,
	[CompatibilityLevel] [nvarchar](10) NULL,
	[SQLVersionCompatibility] [nvarchar](10) NULL,
	[StateDesc] [nvarchar](25) NULL,
	[ReadOnly] [bit] NULL,
	[DatabaseGB] [nvarchar](10) NULL,
	[DataSizeGB] [nvarchar](10) NULL,
	[LastGoodCheckDb] [nvarchar](50) NULL,
	[DaysSinceLastGoodCheckDb] [varchar](25) NULL,
	[Collation] [nvarchar](50) NULL,
	[Owner] [nvarchar](50) NULL,
	[EncryptionEnabled] [bit] NULL,
	[FullTextEnabled] [bit] NULL,
	[PageVerify] [nvarchar](20) NULL,
	[LastUpdated] [datetime] DEFAULT GETDATE() NOT NULL
) ON [PRIMARY]
GO

"@
 Invoke-Sqlcmd -ServerInstance $HostServer -Database $HostDB -Query $TableQuery

foreach ($SQLInstance in $servers) 
{
write-host $SQLInstance

$DBSettings=""
$DbQuery= "SET NOCOUNT ON;
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
                    SELECT @DataCenter,@SQLInstance, @Name,CASE WHEN  MAX(VALUE) != 'NULL' THEN MAX(VALUE) ELSE 'NULL' END AS LastGoodCheckDBTime,@DaysSinceLastGoodCheckDb,@Status FROM #temp
                    WHERE Field = 'dbi_dbccLastKnownGood';

                    truncate table #temp

                FETCH NEXT FROM looping_cursor INTO @Name
                END
            CLOSE looping_cursor;
            DEALLOCATE looping_cursor;

SELECT     
    '$DataCenter' as Datacenter,'$SQLInstance' as Instance,DB_NAME(db.database_id) DatabaseName, Convert(date,db.create_date) As DateCreated, db.recovery_model_desc as RecoveryModel,db.compatibility_level As Compatibility,CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(128)),2) * 10 AS CHAR(3)) As SQLVersionCompatibility, db.state_desc as StateDesc, db.is_read_only As ReadOnly, 
    Round((CAST(mfrows.RowSize AS FLOAT)*8)/1024/1024+(CAST(mflog.LogSize AS FLOAT)*8)/1024/1024,0) 'DatabaseGB' ,
    Round((CAST(mfrows.RowSize AS FLOAT)*8)/1024/1024,0) 'DataSizeGB',
	Res.LastGoodCheckDBTime As 'LastGoodCheckDBTime',DATEDIFF(DAY, Res.LastGoodCheckDBTime, GETDATE()) As 'DaysSinceLastGoodCheckDb',
    db.collation_name as Collation,suser_sname( db.owner_sid ) AS Owner, db.is_encrypted as EncryptionEnabled, db. is_fulltext_enabled as FullTextEnabled,db.page_verify_option_desc as PageVerify
    FROM sys.databases db 
    LEFT JOIN (SELECT database_id, SUM(CAST(size as bigint)) RowSize  FROM sys.master_files  WHERE type = 0  GROUP BY database_id, type) mfrows 
        ON mfrows.database_id = db.database_id     
    LEFT JOIN (SELECT database_id, SUM(CAST (size as bigint)) Logsize  FROM sys.master_files  WHERE type = 1 GROUP BY database_id, type) mflog 
        ON mflog.database_id = db.database_id   
	LEFT JOIN #Results Res
	ON Res.[Database] =DB_NAME(db.database_id)
    JOIN sys.databases Sysdb 
    ON mflog.database_id = Sysdb.database_id 
    where Sysdb.source_database_id IS NULL --and Res.[Database] not in ('tempdb') 
    ORDER BY Instance,DB_NAME(db.database_id)"

    $DBSettings = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query $DbQuery -QueryTimeout 0

    Foreach($DBSetting in $DBSettings)
    {

    $Datacenter=$DBSetting.Datacenter; $SqlInstance = $DBSetting.Instance; $DatabaseName=$DBSetting.DatabaseName; $DateCreated=$DBSetting.DateCreated; $RecoveryModel=$DBSetting.RecoveryModel; $CompatibilityLevel= $DBSetting.Compatibility; 
    $SQLVersionCompatibility=$DBSetting.SQLVersionCompatibility; $StateDesc=$DBSetting.StateDesc; $ReadOnly=$DBSetting.ReadOnly; $DatabaseGB=$DBSetting.DatabaseGB; $DataSizeGB=$DBSetting.DataSizeGB; $LastGoodCheckDBTime=$DBSetting.LastGoodCheckDBTime; $DaysSinceLastGoodCheckDb=$DBSetting.DaysSinceLastGoodCheckDb; 
    $Collation=$DBSetting.Collation; $Owner=$DBSetting.Owner; $EncryptionEnabled=$DBSetting.EncryptionEnabled;$FullTextEnabled=$DBSetting.FullTextEnabled; $PageVerify=$DBSetting.PageVerify   

        $Insert = "INSERT into dbo.$Table ([Datacenter], [SqlInstance], [DatabaseName],[DateCreated],[RecoveryModel],[CompatibilityLevel],[SQLVersionCompatibility],[StateDesc],[ReadOnly],[DatabaseGB],[DataSizeGB],[LastGoodCheckDb],[DaysSinceLastGoodCheckDb],[Collation],[Owner],[EncryptionEnabled],[FullTextEnabled],[PageVerify])
                            VALUES ('$Datacenter','"  + $SqlInstance + "','" + $DatabaseName + "','" + $DateCreated + "','" + $RecoveryModel + "','" + $CompatibilityLevel + "','" + $SQLVersionCompatibility + "',
                            '" + $StateDesc + "','" + $ReadOnly + "','" + $DatabaseGB + "','" + $DataSizeGB + "','" + $LastGoodCheckDBTime + "','" + $DaysSinceLastGoodCheckDb + "','" + $Collation + "','" + $Owner + "', '" + $EncryptionEnabled + "','" + $FullTextEnabled + "','" + $PageVerify + "')"
    
    Invoke-Sqlcmd -ServerInstance $HostServer -Database $HostDB -Query $Insert -Verbose;
    }

}

