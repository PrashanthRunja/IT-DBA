$DataCenter = 'LVDC-EMS'
$HostServer = "P054SQLMGMT02\SQLADMIN"
$HostDB = "DBASUPPORT"
$CheckDbTable = "DBCC_CheckDb"
$CommandLogtable= "DBCC_CheckDb_CommandLog"

$ServerList = "select b.server_group_id,a.name,b.server_name
                from [msdb].[dbo].[sysmanagement_shared_server_groups_internal] a
                inner join msdb.dbo.sysmanagement_shared_registered_servers_internal b
                on a.server_group_id =b.server_group_id
                where a.parent_id =10 order by a.name,a.server_group_id"
$Servergroups = Invoke-Sqlcmd -ServerInstance $HostServer -Query $ServerList #| Select-Object name -ExpandProperty name | Sort-Object name
$Servers = $Servergroups.server_name

foreach($SQLInstance in $Servers)
{
 Write-Host $SQLInstance



$Usrname=""
$pass=""
$CheckDbQuery=""
$CommandLogQuery=""

$Svrgrp = $Servergroups | Select-Object server_group_id,name,server_name | Where-Object {$_.server_name -eq $SQLInstance}
$Cred = invoke-sqlcmd -ServerInstance $HostServer -Database $HostDB -Query "select * from [DM_Credentials]" | Where-Object {$_.server_group_id -eq $Svrgrp.server_group_id}

$server_group_id =$Cred| Select-Object server_group_id -ExpandProperty server_group_id 
$Fldname =$Cred| Select-Object name -ExpandProperty name 
$Usrname=$Cred| Select-Object Username -ExpandProperty Username 
$pass=$Cred| Select-Object Password -ExpandProperty Password 

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
            DECLARE @SQLInstance VARCHAR(100) = '$SQLInstance'
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

 $CheckDBArray += Invoke-Sqlcmd -ServerInstance $SQLInstance -Query $CheckDbQuery -Username $Usrname -Password $pass -QueryTimeout 0 
 $CheckDBArray | Write-DbaDataTable -SqlInstance $HostServer -Database $HostDB  -Schema dbo -Table $CheckDbTable -BatchSize 5000 -KeepNulls 

## DataLoad to CommandLog Table  
$CommandLogArray = ""   
$CommandLogArray = @() 

$CommandLogQuery= "select '$DataCenter' as Datacenter,'$SQLInstance' As SqlInstance,databasename,StartTime,EndTime, ErrorNumber from [master].[dbo].[CommandLog] WHERE StartTime IN (SELECT MAX(StartTime) FROM [master].[dbo].[CommandLog]  GROUP BY DatabaseName)"

$CommandLogArray += Invoke-Sqlcmd -ServerInstance $SQLInstance -Query $CommandLogQuery -Username $Usrname -Password $pass -QueryTimeout 0 
$CommandLogArray | Write-DbaDataTable -SqlInstance $HostServer -Database $HostDB  -Schema dbo -Table $CommandLogtable -BatchSize 5000 -KeepNulls 
}

