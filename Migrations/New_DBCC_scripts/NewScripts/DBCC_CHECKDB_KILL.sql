DECLARE @JOB_NAME nvarchar(MAX) = N'DatabaseIntegrityCheck - USER_DATABASES';
DECLARE @JOB_NAME1 nvarchar(MAX) = N'DatabaseIntegrityCheck - USER_DATABASES Pickup';

IF EXISTS(
SELECT 1
FROM msdb.dbo.sysjobs_view job
INNER JOIN msdb.dbo.sysjobactivity activity 
  ON job.job_id = activity.job_id
WHERE
	activity.run_Requested_date IS NOT NULL
		AND activity.stop_execution_date IS NULL
		AND job.[Name] = @JOB_NAME
)

BEGIN

EXEC msdb.dbo.sp_stop_job @JOB_NAME

END

IF EXISTS(
SELECT 1
FROM msdb.dbo.sysjobs_view job
INNER JOIN msdb.dbo.sysjobactivity activity 
  ON job.job_id = activity.job_id
WHERE
	activity.run_Requested_date IS NOT NULL
		AND activity.stop_execution_date IS NULL
		AND job.[Name] = @JOB_NAME1
)

BEGIN

EXEC msdb.dbo.sp_stop_job @JOB_NAME1

END

--kill DBCC process if any left

DECLARE @cmd NVARCHAR(max)

SELECT @cmd='KILL '+ CAST(er.session_id AS nvarchar(512)) 
				FROM sys.dm_exec_requests er 
				JOIN sys.dm_exec_sessions es 
				  ON er.session_id=es.session_id
				WHERE es.program_name='SQLCMD' and er.command like '%DBCC%'

--PRINT @cmd
EXEC (@cmd)
