USE DBASupport
GO

------------------------------------------------------
--    sproc - DBA_IntegrityCheckDailyAlertCheck     --
------------------------------------------------------

IF EXISTS (SELECT * FROM dbo.sysobjects WHERE id = object_id (N'[dbo].[DBA_IntegrityCheckDailyAlertCheck]'))
	DROP PROCEDURE DBA_IntegrityCheckDailyAlertCheck
GO

CREATE PROCEDURE DBA_IntegrityCheckDailyAlertCheck as 
BEGIN
	DECLARE @Subject NVARCHAR(500)
		, @Message NVARCHAR(MAX)
		, @EmailTo NVARCHAR(500)
		, @CMD NVARCHAR(MAX)

SET @EmailTo ='SQLDatabaseSupport@epiqsystems.com'

SET @Subject = 'DBCC Failure on '+@@SERVERNAME

SET @CMD = ''

IF (EXISTS (
	SELECT DatabaseName FROM (
		SELECT DATABASEPROPERTYEX(DatabaseName,'LastGoodCheckDbTime') LastGoodCheckDbTime,c.*,d.is_read_only 
		FROM [master].dbo.[CommandLog] c 
		JOIN sys.databases d 
		  ON c.DatabaseName=d.[Name] 
		WHERE CommandType='DBCC_CHECKDB'
			AND EndTime > DATEADD(HOUR,-27,GETDATE())
	) a 
	WHERE a.ErrorNumber<>0 
		OR a.ErrorMessage IS NOT NULL 
		OR (a.LastGoodCheckDbTime<a.StartTime 
				AND a.is_read_only=0)
)) BEGIN
	
		SELECT @CMD = @CMD+ 'PRINT ''Integrity Error in :'+DatabaseName+'''; ' 
		FROM (
			SELECT DATABASEPROPERTYEX(DatabaseName,'LastGoodCheckDbTime') LastGoodCheckDbTime,* FROM [master].[dbo].[CommandLog] 
			WHERE CommandType='DBCC_CHECKDB'
				AND EndTime > DATEADD(HOUR,-27,GETDATE())
		) a 
		WHERE a.ErrorNumber<>0 OR a.ErrorMessage IS NOT NULL OR a.LastGoodCheckDbTime<a.StartTime

		EXEC (@CMD)

		SET @Message = '<html><head><title></title></head>
		<body><br><br><h1>DBCC Failure on '+@@SERVERNAME+'</h1><p>'

		SELECT @Message = @Message + 'Integrity Error in :'+DatabaseName+'</br>' FROM (
			SELECT DATABASEPROPERTYEX(DatabaseName,'LastGoodCheckDbTime') LastGoodCheckDbTime,* FROM [master].[dbo].[CommandLog] 
			WHERE CommandType='DBCC_CHECKDB'
				AND EndTime > DATEADD(HOUR,-27,GETDATE())
		) a 
		WHERE a.ErrorNumber<>0 
			OR a.ErrorMessage IS NOT NULL 
			OR a.LastGoodCheckDbTime < a.StartTime

		SET @Message = @Message + '<p>sent FROM '+@@servername+'<br></table></body></html>'

		EXEC MSDB.DBO.SP_SEND_DBMAIL @Profile_name = 'Administrator'
			, @Recipients = @EmailTo
			, @Subject = @Subject
			, @Body = @Message
			, @Body_format = N'HTML'

		RAISERROR('Integrity Error',16,1)
	
	END
END
GO

USE [msdb]
GO

------------------------------------------------------------------
--  DatabaseIntegrityCheck - USER_DATABASES - DailyAlertCheck   --
------------------------------------------------------------------

DECLARE @JobID BINARY(16)
DECLARE @ReturnCode INT

SELECT @ReturnCode = 0
/****** Object:  JobCategory [DBA]    Script Date: 11/7/2021 11:30:18 AM ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'DBA' AND category_class=1)
	EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'DBA'

SELECT @JobID = job_id 
FROM msdb.dbo.sysjobs 
WHERE ([Name] = N'DatabaseIntegrityCheck - USER_DATABASES - DailyAlertCheck')

IF (@JobID IS NOT NULL)
BEGIN
    EXEC msdb.dbo.sp_delete_job @JobID, @delete_unused_schedule=1
END

SET @JobID = NULL

EXEC @ReturnCode =  msdb.dbo.sp_add_job 
		@job_name=N'DatabaseIntegrityCheck - USER_DATABASES - DailyAlertCheck', 
		@enabled=1, 
		@notify_level_eventlog=3,
		@notify_level_email = 2,  
	    @notify_email_operator_name = N'SQLSupport', 
		@description=N'Check if any DBCC CHECKDB failed', 
		@category_name=N'DBA', 
		@owner_login_name=N'sa', 
		@job_id = @JobID OUTPUT

/****** Object:  Step [execute check]    Script Date: 11/7/2021 11:30:18 AM ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep 
		@job_id=@JobID, 
		@step_name=N'Execute Check', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, 
		@subsystem=N'TSQL', 
		@command=N'exec DBASupport.dbo.DBA_IntegrityCheckDailyAlertCheck', 
		@database_name=N'master', 
		@flags=0
		
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule 
		@job_id=@JobID, 
		@name=N'Daily_0100', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20211107, 
		@active_end_date=99991231, 
		@active_start_time=010000, 
		@active_end_time=235959 

EXEC msdb.dbo.sp_add_jobserver @job_id = @JobID, @server_name = N'(local)'
EXEC msdb.dbo.sp_update_job @job_id = @JobID, @start_step_id = 1

------------------------------------------------------
--  DatabaseIntegrityCheck - USER_DATABASES Pickup  --
------------------------------------------------------

SELECT @JobID = job_id 
FROM msdb.dbo.sysjobs 
WHERE ([Name] = N'DatabaseIntegrityCheck - USER_DATABASES Pickup')

IF (@JobID IS NOT NULL)
BEGIN
    EXEC msdb.dbo.sp_delete_job @JobID, @delete_unused_schedule=1
END

SET @JobID = NULL

EXEC msdb..sp_add_job 
		@job_name = N'DatabaseIntegrityCheck - USER_DATABASES Pickup',
		@description = N'Pickup DBs not having run in-place DBCC CHECKDB for DB <1TB',
		@enabled=1,
		@notify_level_eventlog=3,
		@notify_level_email = 2,  
	    @notify_email_operator_name = N'SQLSupport', 
		@category_name=N'DBA', 
		@owner_login_name=N'sa', 
		@job_id = @JobID OUTPUT 

EXEC msdb.dbo.sp_add_jobstep @job_id=@JobID, 
		@step_name=N'DatabaseIntegrityCheck - USER_DATABASES Pickup', 
		@step_id=1,  
		@on_success_action=1, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @CMD VARCHAR (8000)

--PreStuff Variable
SET @CMD = ''sqlcmd -E -S '' + @@SERVERNAME + '' -d dbasupport -Q "EXECUTE [dbasupport].[dbo].[DatabaseIntegrityCheck_Builder] ''


-- Pull Parameters together
SELECT @CMD = COALESCE( @CMD + Param_Name + '' = '' + 
                            CASE Param_Type 
							    WHEN ''C'' 
								    THEN  '''''''' + Param_Value + ''''''''
								ELSE 
								    Param_Value
						    END
							+ '','' , ''''  ) 
  FROM MaintParameter
 WHERE Param_Job = ''DatabaseIntegrityCheck - USER_DATABASES Pickup''
 
SELECT @Cmd =  LEFT (@Cmd, LEN(@CMD)-1) + ''" -b''
-- Change ''NULL'' to NULL
SELECT @CMD = REPLACE(@CMD, ''''''NULL'''''', ''NULL'')

--PRINT @CMD

EXECUTE XP_CMDSHELL @CMD', 
		@database_name=N'DBASupport', 
		@flags=0

EXEC msdb..sp_add_jobschedule 
		@job_id=@JobID,
		@name=N'Sun 0900AM',
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=1, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20211110, 
		@active_end_date=99991231, 
		@active_start_time=090000, 
		@active_end_time=235959

EXEC msdb.dbo.sp_add_jobserver @job_id = @JobID, @server_name = N'(local)'
EXEC msdb.dbo.sp_update_job @job_id = @JobID, @start_step_id = 1

GO

DECLARE @SchID INT
DECLARE @JobID BINARY(16)

SELECT @JobID = job_id 
FROM msdb.dbo.sysjobs 
WHERE ([Name] = N'DatabaseIntegrityCheck - USER_DATABASES')

IF (@JobID IS NOT NULL)
BEGIN
    EXEC msdb.dbo.sp_delete_job @JobID, @delete_unused_schedule=1
END

SET @JobID = NULL

EXEC msdb..sp_add_job 
		@job_name = N'DatabaseIntegrityCheck - USER_DATABASES',
		@description = N'In-place DBCC CHECKDB for DB <1TB',
		@enabled=1,
		@notify_level_eventlog=3,
		@notify_level_email = 2,  
	    @notify_email_operator_name = N'SQLSupport', 
		@category_name=N'DBA', 
		@owner_login_name=N'sa', 
		@job_id = @JobID OUTPUT 
	
	EXEC msdb..sp_add_jobschedule 
		@job_id=@JobID,
		--@job_name = N'DatabaseIntegrityCheck - USER_DATABASES',
		@name=N'CHECKDB_Thurs 0400',
		@enabled=1, 
		@freq_type=8, 
		@freq_interval=16, 
		@freq_subday_type=1, 
		@freq_subday_interval=0, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=1, 
		@active_start_date=20211110, 
		@active_end_date=99991231, 
		@active_start_time=040000, 
		@active_end_time=235959

EXEC msdb.dbo.sp_add_jobstep @job_name='DatabaseIntegrityCheck - USER_DATABASES', @step_name=N'ListDbsSmallerThan', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=3, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @DBList VARCHAR(MAX)

DECLARE @DaysBetween TINYINT = 7
DECLARE @DBThreshGB INT = 1024


-- Since we are loading the database names, we need to expand the size of the Param_Value field, if needed.  -1 means MAX.
IF NOT EXISTS(SELECT * FROM sys.columns
      WHERE OBJECT_NAME(OBJECT_ID) = ''MaintParameter'' AND [NAME] = ''Param_Value'' AND max_length = -1)
BEGIN
	CREATE TABLE dbo.Tmp_MaintParameter
		(
		Param_ID int NOT NULL IDENTITY (1, 1),
		Param_Job nvarchar(128) NULL,
		Param_Name nvarchar(128) NULL,
		Param_Type nvarchar(10) NULL,
		Param_Value nvarchar(MAX) NULL
		)  ON [PRIMARY]
		 TEXTIMAGE_ON [PRIMARY]

	ALTER TABLE dbo.Tmp_MaintParameter SET (LOCK_ESCALATION = TABLE)

	SET IDENTITY_INSERT dbo.Tmp_MaintParameter ON

	IF EXISTS(SELECT * FROM dbo.MaintParameter)
		 EXEC(''INSERT INTO dbo.Tmp_MaintParameter (Param_ID, Param_Job, Param_Name, Param_Type, Param_Value)
			SELECT Param_ID, Param_Job, Param_Name, Param_Type, CONVERT(nvarchar(MAX), Param_Value) FROM dbo.MaintParameter WITH (HOLDLOCK TABLOCKX)'')

	SET IDENTITY_INSERT dbo.Tmp_MaintParameter OFF

	DROP TABLE dbo.MaintParameter

	EXECUTE sp_rename N''dbo.Tmp_MaintParameter'', N''MaintParameter'', ''OBJECT'' 
END


IF OBJECT_ID(N''tempdb.dbo.#DBInfo'', N''U'') IS NOT NULL  
   DROP TABLE #DBInfo;  
IF OBJECT_ID(N''tempdb.dbo.#Value'', N''U'') IS NOT NULL  
   DROP TABLE #Value;  
IF OBJECT_ID(N''tempdb.dbo.#TempDBs'', N''U'') IS NOT NULL  
   DROP TABLE #TempDBs;  

-- Get only databases < 1TB
SELECT d.[Name]
INTO #TempDBs
FROM sys.master_files mf
INNER JOIN sys.databases d ON d.database_id = mf.database_id
WHERE d.database_id > 4
GROUP BY d.[Name]
HAVING (SUM(CAST(mf.size AS BIGINT)) * 8 / 1024) / 1024 < @DBThreshGB

-- Retreive the last CHECKDB date for all databases
CREATE TABLE #DBInfo (ParentObject VARCHAR(255), [Object] VARCHAR(255), Field VARCHAR(255), [Value] VARCHAR(255))
CREATE TABLE #Value (DatabaseName VARCHAR(255), LastDBCCCheckDB DATETIME)
EXECUTE sp_MSforeachdb ''INSERT INTO #DBInfo EXECUTE (''''DBCC DBINFO ( ''''''''?'''''''' ) WITH TABLERESULTS, NO_INFOMSGS'''');
INSERT INTO #Value (DatabaseName, LastDBCCCheckDB) (SELECT ''''?'''', [Value] FROM #DBInfo WHERE Field = ''''dbi_dbccLastKnownGood'''');
TRUNCATE TABLE #DBInfo;''

-- Put the databases < 1TB in a comma-delimited list
SELECT @DBList = COALESCE(@DBList + ''], ['','''') + DatabaseName
		FROM #Value v
		INNER JOIN #TempDBs t
		  ON v.DatabaseName = t.[Name]
		WHERE LastDBCCCheckDB < DATEADD(DAY,  -@DaysBetween, GETDATE())

-- Cap off the list
SELECT @DBList = ''['' + @DBList + '']''

IF @DBList IS NULL
	SELECT @DBList=''master''

-- UPDATE the parameter table to values needed for this run
UPDATE [DBASupport].[dbo].[MaintParameter]
SET [Param_Value] = @DaysBetween
WHERE [Param_Job] = ''DatabaseIntegrityCheck - USER_DATABASES''
       AND [Param_Name] = ''@Days''

UPDATE [DBASupport].[dbo].[MaintParameter]
SET [Param_Value] = @DBList
WHERE [Param_Job] = ''DatabaseIntegrityCheck - USER_DATABASES''
       AND [Param_Name] = ''@Databases''
', 
		@database_name=N'DBASupport', 
		@flags=0

EXEC msdb.dbo.sp_add_jobstep @job_name='DatabaseIntegrityCheck - USER_DATABASES', @step_name=N'DatabaseIntegrityCheck - USER_DATABASES', 
		@step_id=2, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_fail_action=2, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @CMD VARCHAR (8000)

--PreStuff Variable
SET @CMD = ''sqlcmd -E -S '' + @@SERVERNAME + '' -d dbasupport -Q "EXECUTE [dbasupport].[dbo].[DatabaseIntegrityCheck_Builder] ''





-- Pull Parameters together
SELECT @CMD = COALESCE( @CMD + Param_Name + '' = '' + 
                            CASE Param_Type 
							    WHEN ''C'' 
								    THEN  '''''''' + Param_Value + ''''''''
								ELSE 
								    Param_Value
						    END
							+ '','' , ''''  ) 
  FROM MaintParameter
 WHERE Param_Job = ''DatabaseIntegrityCheck - USER_DATABASES''
 

SELECT @Cmd =  LEFT (@Cmd, LEN(@CMD)-1) + ''" -b''
-- Change ''NULL'' to NULL
SELECT @CMD = REPLACE(@CMD, ''''''NULL'''''', ''NULL'')

--PRINT @CMD

EXECUTE XP_CMDSHELL @CMD', 
		@database_name=N'DBASupport', 
		--@output_file_name=N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\LOG\DatabaseIntegrityCheck_$(ESCAPE_SQUOTE(JOBID))_$(ESCAPE_SQUOTE(STEPID))_$(ESCAPE_SQUOTE(STRTDT))_$(ESCAPE_SQUOTE(STRTTM)).txt', 
		@flags=0
		
EXEC msdb.dbo.sp_add_jobserver @job_id = @JobID, @server_name = N'(local)'
EXEC msdb.dbo.sp_update_job @job_id = @JobID, @start_step_id = 1

GO

UPDATE DBASupport.dbo.MaintParameter SET Param_Value='USER_DATABASES'
WHERE Param_Job LIKE 'DatabaseIntegrityCheck - USER_DATABASES%' AND Param_Name='@Databases'

UPDATE DBASupport.dbo.MaintParameter SET Param_Value='Y'
WHERE Param_Job LIKE 'DatabaseIntegrityCheck - USER_DATABASES%' AND Param_Name='@LogToTable'

UPDATE DBASupport.dbo.MaintParameter SET Param_Value='ALL'
WHERE Param_Job LIKE 'DatabaseIntegrityCheck - USER_DATABASES%' AND Param_Name='@Updateability'

UPDATE DBASupport.dbo.MaintParameter SET Param_Value='180'
WHERE Param_Job LIKE 'DatabaseIntegrityCheck - USER_DATABASES' AND Param_Name='@Duration'

UPDATE DBASupport.dbo.MaintParameter SET Param_Value='4'
WHERE Param_Job LIKE 'DatabaseIntegrityCheck - USER_DATABASES' AND Param_Name='@Days'

UPDATE DBASupport.dbo.MaintParameter SET Param_Value='720'
WHERE Param_Job LIKE 'DatabaseIntegrityCheck - USER_DATABASES Pickup' AND Param_Name='@Duration'

UPDATE DBASupport.dbo.MaintParameter SET Param_Value='6'
WHERE Param_Job LIKE 'DatabaseIntegrityCheck - USER_DATABASES Pickup' AND Param_Name='@Days'

UPDATE DBASupport.dbo.MaintParameter SET Param_Value=','
WHERE Param_Job LIKE 'DatabaseIntegrityCheck - USER_DATABASES' AND Param_Name='@Delim'

UPDATE DBASupport.dbo.MaintParameter SET Param_Value=','
WHERE Param_Job LIKE 'DatabaseIntegrityCheck - USER_DATABASES Pickup' AND Param_Name='@Delim'