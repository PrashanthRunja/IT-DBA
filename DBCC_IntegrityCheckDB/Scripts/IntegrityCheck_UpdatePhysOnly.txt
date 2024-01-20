DECLARE @MaintInsert TABLE (InsState VARCHAR(4000))
DECLARE @JobID UNIQUEIDENTIFIER
DECLARE @JobIDPickup UNIQUEIDENTIFIER
DECLARE @JobCmdStep1 VARCHAR(4000)
DECLARE @JobCmdStep2 VARCHAR(4000)
DECLARE @JobCmdPickupStep1 VARCHAR(4000)
DECLARE @InsCmd VARCHAR(4000)

-- Create insert statements for additional parameters for the MaintParameter table
INSERT INTO @MaintInsert
SELECT 'INSERT INTO [DBASupport].[dbo].[MaintParameter] ([Param_Job], [Param_Name], [Param_Type], [Param_Value])
		VALUES (''DatabaseIntegrityCheck - USER_DATABASES > 2TB'', ''' + [Param_Name] + ''', ''' + [Param_Type] + ''', ''' + 
		CASE WHEN [Param_Name] = '@PhysicalOnly' THEN 'Y'
			ELSE [Param_Value] END
		 + ''')' AS SQLCmd
FROM [DBASupport].[dbo].[MaintParameter]
WHERE Param_Job = 'DatabaseIntegrityCheck - USER_DATABASES Pickup'

-- Comment this out if running against CMS
SELECT * FROM @MaintInsert

-- Execute the INSERT statements to add parameters
WHILE EXISTS (SELECT InsState FROM @MaintInsert)
BEGIN
	SELECT TOP 1 @InsCmd = InsState FROM @MaintInsert
	exec (@InsCmd)
	DELETE FROM @MaintInsert WHERE InsState = @InsCmd
END

-- Get the job ID for the job being updated
SELECT @JobID = job_id
FROM msdb.dbo.sysjobs
where [Name] = 'DatabaseIntegrityCheck - USER_DATABASES > 2TB'

SELECT @JobIDPickup = job_id
FROM msdb.dbo.sysjobs
where [Name] = 'DatabaseIntegrityCheck - USER_DATABASES Pickup'

-- Get the existing command for the steps to be updated

SELECT @JobCmdStep1 = command 
FROM msdb.dbo.sysjobsteps
WHERE job_id = @JobID
	AND step_id = 1

SELECT @JobCmdStep2 = command 
FROM msdb.dbo.sysjobsteps
WHERE job_id = @JobID
	AND step_id = 2

SELECT @JobCmdPickupStep1 = command 
FROM msdb.dbo.sysjobsteps
WHERE job_id = @JobIDPickup
	AND step_id = 1

-- Update the command to use the new parameters just added
SET @JobCmdStep1 = REPLACE(@JobCmdStep1, 'USER_DATABASES', 'USER_DATABASES > 2TB')
SET @JobCmdStep2 = REPLACE(@JobCmdStep2, 'USER_DATABASES Pickup', 'USER_DATABASES > 2TB')
SET @JobCmdPickupStep1 = REPLACE(@JobCmdPickupStep1, 'USER_DATABASES', 'USER_DATABASES Pickup')

-- Update the jobs
EXEC msdb.dbo.sp_update_jobstep
	@job_id = @JobID,
	@command = @JobCmdStep1,
	@step_id = 1

EXEC msdb.dbo.sp_update_jobstep
	@job_id = @JobID,
	@command = @JobCmdStep2,
	@step_id = 2

EXEC msdb.dbo.sp_update_jobstep
	@job_id = @JobIDPickup,
	@command = @JobCmdPickupStep1,
	@step_id = 1

-- Update the @PhysicalOnly parameter to 'N'
UPDATE DBASupport.dbo.MaintParameter
SET [Param_Value] = 'N'
WHERE [Param_Job] = 'DatabaseIntegrityCheck - USER_DATABASES Pickup'
	AND [Param_Name] = '@PhysicalOnly'
	
UPDATE DBASupport.dbo.MaintParameter
SET [Param_Value] = 'N'
WHERE [Param_Job] = 'DatabaseIntegrityCheck_Catalog - USER_DATABASES'
	AND [Param_Name] = '@PhysicalOnly'
	
UPDATE DBASupport.dbo.MaintParameter
SET [Param_Value] = 'N'
WHERE [Param_Job] = 'DatabaseIntegrityCheck - USER_DATABASES'
	AND [Param_Name] = '@PhysicalOnly'

-- DEBUG --
--DELETE DBASupport.dbo.MaintParameter
--WHERE [Param_Job] = 'DatabaseIntegrityCheck - USER_DATABASES > 2TB'