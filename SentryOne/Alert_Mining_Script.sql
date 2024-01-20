
/************************************************************************************
The Queries below are used to datamine event information through triggered conditions. Queries toward the top are more high level. The lower you go the more level/object specifc the queries become. 

Notes:
- Note that by default SentryOne retains a years worth of alert data. So it is recommended that you limit your time range to say the last 30-90 days. 
Also make sure as you go through cycles of alert tuning, that you set the start times for after each tuning cycle, as the older alert data will still be there.

- If you have a particular alert bubble up that I have not provided an event/object specific query for, update the template query at the very bottom with the desired Condition name.
*************************************************************************************/


/* Global General Condition counts*/
SELECT conditiontypename AS Condition, 
       Count(*) AS TheCount 
FROM   objectconditionactionhistory ocah 
       JOIN conditiontype ct 
         ON ocah.conditiontypeid = ct.id 
       JOIN conditiontypecategory ctc 
         ON ct.conditiontypecategoryid = ctc.id 
WHERE  conditiontypecategoryid != '89AFED32-B625-4A6E-BE8D-9CEBBDE16A76' 
       AND conditiontypecategoryid != 'E2AAD766-0B60-4E5D-90A8-2AE62135E99E' and ActionTypeName = 'Send Email'
	   AND EventStartTime > DATEADD(day, -90, GETDATE())
GROUP  BY conditiontypename 
ORDER  BY thecount DESC 

---------------------------------------------------------------------------------------------------------------
/* General Condition counts by target */
SELECT parentobjectname AS ParentObject, 
       conditiontypename AS Condition, 
       Count(*) AS TheCount 
FROM   objectconditionactionhistory ocah 
       JOIN conditiontype ct 
         ON ocah.conditiontypeid = ct.id 
       JOIN conditiontypecategory ctc 
         ON ct.conditiontypecategoryid = ctc.id 
WHERE  conditiontypecategoryid != '89AFED32-B625-4A6E-BE8D-9CEBBDE16A76' 
       AND conditiontypecategoryid != 'E2AAD766-0B60-4E5D-90A8-2AE62135E99E' and ActionTypeName = 'Send Email'
	   AND EventStartTime > DATEADD(day, -90, GETDATE())
--AND ParentObjectName like '%<ServerName>%' 
GROUP  BY parentobjectname, 
          conditiontypename 
ORDER  BY thecount DESC 

---------------------------------------------------------------------------------------------------------------

/* Global Advisory Condition counts - Send to Alerting Channels/Health Score*/
SELECT dcd.NAME AS Condition,
	Count(*) AS TheCount
FROM   DynamicConditionDefinition dcd 
       JOIN AlertingChannelLog acl 
         ON dcd.ID = acl.DynamicConditionID 
WHERE acl.NormalizedStartTimeUtc > DATEADD(day, -90, GETDATE())
--AND ActionTypeName = 'Send Email'
--AND ObjectName = '%<ServerName>%' 
--AND dcd.name = '%<ConditionName>%' 
GROUP  BY  dcd.NAME 
ORDER  BY thecount DESC 

-----------------------------------------------------------------------------------------N----------------------

/* Global Advisory Condition counts - Send Email*/
SELECT dcd.NAME AS Condition,
	Count(*) AS TheCount
FROM   DynamicConditionDefinition dcd 
       JOIN ObjectConditionActionHistory ocah 
         ON dcd.ConditionID = ocah.ConditionTypeID
WHERE ActionTypeName = 'Send Email'
AND EventStartTime > DATEADD(day, -90, GETDATE())
--AND ObjectName = '%<ServerName>%' 
--AND dcd.name = '%<ConditionName>%' 
GROUP  BY  dcd.NAME 
ORDER  BY thecount DESC 

---------------------------------------------------------------------------------------------------------------

/* Advisory Condition counts by target - Send to Alerting Channels/Health Score*/
SELECT ObjectName AS Target,
	dcd.NAME AS Condition, 
	Count(*) AS TheCount
FROM   DynamicConditionDefinition dcd 
       JOIN AlertingChannelLog acl 
         ON dcd.id = acl.DynamicConditionID
WHERE acl.NormalizedStartTimeUtc > DATEADD(day, -90, GETDATE())
--AND ObjectName = '%<ServerName>%' 
--AND dcd.name = '%<ConditionName>%' 
GROUP  BY ObjectName, 
          dcd.NAME 
ORDER  BY thecount DESC 

---------------------------------------------------------------------------------------------------------------

/* Advisory Condition counts by target - Send Email*/
SELECT ObjectName AS Target,
	dcd.NAME AS Condition,
	Count(*) AS TheCount
FROM   DynamicConditionDefinition dcd 
       JOIN ObjectConditionActionHistory ocah 
         ON dcd.ConditionID = ocah.ConditionTypeID
WHERE ActionTypeName = 'Send Email'
AND EventStartTime > DATEADD(day, -90, GETDATE())
--AND ObjectName = '%<ServerName>%' 
--AND dcd.name = '%<ConditionName>%' 
GROUP  BY ObjectName, 
          dcd.NAME 
ORDER  BY thecount DESC


---------------------------------------------------------------------------------------------------------------

/*Global Job Failure counts*/
SELECT parentobjectname AS ParentObject, 
       objectname AS Job, 
       Count(*) AS TheCount 
FROM   objectconditionactionhistory ocah 
       JOIN conditiontype ct 
         ON ocah.conditiontypeid = ct.id 
       JOIN conditiontypecategory ctc 
         ON ct.conditiontypecategoryid = ctc.id 
WHERE  conditiontypename = 'SQL Server Agent Job: Failure' AND ActionTypeName = 'Send Email' 
AND EventStartTime > DATEADD(day, -90, GETDATE())
GROUP  BY parentobjectname, 
          objectname 
ORDER  BY thecount DESC 

---------------------------------------------------------------------------------------------------------------

/*Global Job Step Failure counts*/
SELECT parentobjectname AS ParentObject, 
       objectname AS Job, 
	   esos.StepName,
       Count(*) AS TheCount 
FROM   objectconditionactionhistory ocah 
       JOIN conditiontype ct 
         ON ocah.conditiontypeid = ct.id 
       JOIN conditiontypecategory ctc 
         ON ct.conditiontypecategoryid = ctc.id 
       JOIN EventSourceObjectStep esos
	     ON ocah.ObjectID = esos.ObjectID
WHERE  conditiontypename = 'SQL Server Agent Job: Step Failure' AND ActionTypeName = 'Send Email'
AND EventStartTime > DATEADD(day, -90, GETDATE())
GROUP  BY parentobjectname, 
          objectname,
		  esos.StepName
ORDER  BY thecount DESC 

---------------------------------------------------------------------------------------------------------------

/*Global Job Runtime Max counts*/
SELECT parentobjectname AS ParentObject, 
       objectname AS Job, 
       Count(*) AS TheCount 
FROM   objectconditionactionhistory ocah 
       JOIN conditiontype ct 
         ON ocah.conditiontypeid = ct.id 
       JOIN conditiontypecategory ctc 
         ON ct.conditiontypecategoryid = ctc.id 
WHERE  conditiontypename = 'SQL Server Agent Job: Runtime Threshold Max' AND ActionTypeName = 'Send Email'
AND EventStartTime > DATEADD(day, -90, GETDATE())
GROUP  BY parentobjectname, 
          objectname 
ORDER  BY thecount DESC 


---------------------------------------------------------------------------------------------------------------

/*Specific target job failure counts*/
SELECT parentobjectname AS ParentObject, 
       objectname AS Job, 
       Count(*) AS TheCount 
FROM   objectconditionactionhistory ocah 
       JOIN conditiontype ct 
         ON ocah.conditiontypeid = ct.id 
       JOIN conditiontypecategory ctc 
         ON ct.conditiontypecategoryid = ctc.id 
WHERE  conditiontypename = 'SQL Server Agent Job: Failure' 
		AND ActionTypeName = 'Send Email'
       AND parentobjectname LIKE '%<ServerName>%' 
AND EventStartTime > DATEADD(day, -90, GETDATE()) 
GROUP  BY parentobjectname, 
          objectname 
ORDER  BY thecount DESC 

---------------------------------------------------------------------------------------------------------------

/*Blocking Alerts per Target*/
SELECT parentobjectname AS ParentObject, 
       ct.name, 
       Count(*) AS TheCount 
FROM   objectconditionactionhistory ocah 
       JOIN conditiontype ct 
         ON ocah.conditiontypeid = ct.id 
       JOIN conditiontypecategory ctc 
         ON ct.conditiontypecategoryid = ctc.id 
WHERE  (conditiontypename = 'SQL Server: Blocking SQL' or conditiontypename = 'SQL Server: Blocking SQL: Duration Threshold Max') AND ActionTypeName = 'Send Email' 
AND EventStartTime > DATEADD(day, -90, GETDATE())
GROUP  BY parentobjectname, ct.name
ORDER  BY thecount DESC 

---------------------------------------------------------------------------------------------------------------

/*Top SQL Error Counts by server and texdata*/
CREATE table #RawData
(
ParentObject varchar(30),
TextData Varchar(max),
EventStartTime datetime
)


INSERT INTO #RawData
SELECT ParentObjectName AS ParentObject, 
(SUBSTRING(message, CHARINDEX('data:', message)+7, CHARINDEX('Message Recipients:',message) - CHARINDEX('data:', message) + Len('Message Recipients:')-30)) AS 'TextData' , EventStartTime
FROM   ObjectConditionActionHistory ocah 
       JOIN ConditionType ct 
         ON ocah.ConditionTypeID = ct.id 
       JOIN ConditionTypeCategory ctc 
         ON ct.ConditionTypeCategoryID = ctc.id 
WHERE  ConditionTypeName = 'SQL Server: Top SQL: Error' and ActionTypeName = 'Send Email'
AND EventStartTime > DATEADD(day, -90, GETDATE())
--AND parentobjectname like '%<ServerName>%' 

SELECT ParentObject, TextData, COUNT(*) as 'TheCount' from #RawData
GROUP BY ParentObject, TextData
ORDER BY TheCount desc

DROP TABLE #RawData

---------------------------------------------------------------------------------------------------------------

/*Top SQL Max Runtime Counts by server and texdata*/
CREATE table #RawData
(
ParentObject varchar(max),
TextData Varchar(max),
EventStartTime datetime
)


INSERT INTO #RawData
SELECT ParentObjectName AS ParentObject, 
(SELECT SUBSTRING(message, CHARINDEX('data:', message)+8, CHARINDEX('[Connection]',message) - CHARINDEX('data:', message) + Len('[Connection]')-98)) AS 'TextData', EventStartTime
FROM   ObjectConditionActionHistory ocah 
       JOIN ConditionType ct 
         ON ocah.ConditionTypeID = ct.id 
       JOIN ConditionTypeCategory ctc 
         ON ct.ConditionTypeCategoryID = ctc.id 
WHERE  ConditionTypeName = 'SQL Server: Top SQL: Duration Threshold Max' and ActionTypeName = 'Send Email'
AND EventStartTime > DATEADD(day, -90, GETDATE())
--AND parentobjectname like '%<ServerName>%'

SELECT ParentObject, TextData, COUNT(*) as 'TheCount' from #RawData
GROUP BY ParentObject, TextData
ORDER BY TheCount desc

--SELECT ParentObject, TextData, EventStartTime from #RawData

DROP TABLE  #RawData

---------------------------------------------------------------------------------------------------------------

/*Specific target job failure counts by month*/ 
SELECT parentobjectname AS ParentObject, 
       conditiontypename AS Condition, 
       objectname AS Job, 
       Datepart(month, eventstarttime) AS TheMonth, 
       Datepart(year, eventstarttime)  AS TheYear, 
       Count(*)                        AS TheCount 
FROM   objectconditionactionhistory ocah 
       JOIN conditiontype ct 
         ON ocah.conditiontypeid = ct.id 
       JOIN conditiontypecategory ctc 
         ON ct.conditiontypecategoryid = ctc.id 
WHERE conditiontypename = 'SQL Server Agent Job: Failure' --MAx duration 
       AND parentobjectname LIKE '%<ServerName>%' 
       AND objectname = 'RA - Perform Manual Failover' 
--AND EventStartTime > '2018-05-21 10:49:06.137', 
GROUP  BY Datepart(month, eventstarttime), 
          Datepart(year, eventstarttime), 
          objectname, 
          parentobjectname, 
          conditiontypename 

---------------------------------------------------------------------------------------------------------------

/*Specific target job failure counts by Week and Month*/
SELECT parentobjectname AS ParentObject, 
       conditiontypename AS Condition, 
       objectname AS Job, 
       Datepart(week, eventstarttime)  AS TheWeek, 
       Datepart(month, eventstarttime) AS TheMonth, 
       Datepart(year, eventstarttime)  AS TheYear, 
       Count(*)                        AS TheCount 
FROM   objectconditionactionhistory ocah 
       JOIN conditiontype ct 
         ON ocah.conditiontypeid = ct.id 
       JOIN conditiontypecategory ctc 
         ON ct.conditiontypecategoryid = ctc.id 
WHERE  conditiontypename = 'SQL Server Agent Job: Failure' 
       AND parentobjectname LIKE '%<ServerName>%' 
       AND objectname = 'RA - Perform Manual Failover' 
--AND EventStartTime > '2018-05-21 10:49:06.137', 
GROUP  BY Datepart(week, eventstarttime), 
          Datepart(month, eventstarttime), 
          Datepart(year, eventstarttime), 
          objectname, 
          parentobjectname, 
          conditiontypename 

---------------------------------------------------------------------------------------------------------------

/*FCI Failover Logs*/
SELECT objectname, 
       conditiontypename, 
       eventstarttime, 
       message 
FROM   objectconditionactionhistory ocah 
       JOIN conditiontype ct 
         ON ocah.conditiontypeid = ct.id 
       JOIN conditiontypecategory ctc 
         ON ct.conditiontypecategoryid = ctc.id 
WHERE  conditiontypename LIKE '%SQL Server Cluster Failover%' 
AND EventStartTime > DATEADD(day, -90, GETDATE())
--AND ObjectName like '%%' 

---------------------------------------------------------------------------------------------------------------

/*AG Failover Logs*/
SELECT objectname, 
       conditiontypename, 
       eventstarttime, 
       message 
FROM   objectconditionactionhistory ocah 
       JOIN conditiontype ct 
         ON ocah.conditiontypeid = ct.id 
       JOIN conditiontypecategory ctc 
         ON ct.conditiontypecategoryid = ctc.id 
WHERE  conditiontypename LIKE '%SQL Availability Group Failover%' 
AND EventStartTime > DATEADD(day, -90, GETDATE())
--AND ObjectName like '%%' 

---------------------------------------------------------------------------------------------------------------

/* Global Deadlock Counts by Target */
SELECT parentobjectname AS ParentObject, 
       objectname AS Event, 
       Count(*) AS TheCount 
FROM   objectconditionactionhistory ocah 
       JOIN conditiontype ct 
         ON ocah.conditiontypeid = ct.id 
       JOIN conditiontypecategory ctc 
         ON ct.conditiontypecategoryid = ctc.id 
WHERE  conditiontypename = 'SQL Server: Deadlock' 
AND EventStartTime > DATEADD(day, -90, GETDATE())
GROUP  BY parentobjectname, 
          objectname 
ORDER  BY thecount DESC 

---------------------------------------------------------------------------------------------------------------

/*Deadlock Counts for specific Server and Application */
SELECT parentobjectname AS ParentObject, 
       objectname AS Event, 
       Count(*) AS TheCount 
FROM   objectconditionactionhistory ocah 
       JOIN conditiontype ct 
         ON ocah.conditiontypeid = ct.id 
       JOIN conditiontypecategory ctc 
         ON ct.conditiontypecategoryid = ctc.id 
WHERE  conditiontypename = 'SQL Server: Deadlock' 
	--AND Message LIKE '%<Application>%' --This could be used to filter off of any info in the actual Deadlock alert 
	--AND ParentObjectName like '%<ServerName>%'
	AND EventStartTime > DATEADD(day, -90, GETDATE())
GROUP  BY parentobjectname, 
          objectname 
ORDER  BY thecount DESC 


-------------------------------------------------------------------------
--                             Deeper Deadlock Mining 
-------------------------------------------------------------------------

--Pulls Deadlock Counts per Target, per Application
SELECT esc.ObjectName, ApplicationName, COUNT (*) AS TheCount  FROM PerformanceAnalysisTraceDeadlock patd
JOIN DeadlockApplicationDeadlock dad ON patd.ID = dad.DeadlockID
JOIN DeadlockApplication da ON dad.DeadlockApplicationID = da.ID
JOIN EventSourceConnection esc ON patd.EventSourceConnectionID = esc.ID
--WHERE StartTime > '2017-03-21 19:55:35.847' and StartTime < '2017-03-21 19:55:35.847'
--AND esc.ObjectName like '%<Target Name>%'
GROUP BY esc.ObjectName, ApplicationName
ORDER BY TheCount DESC 

--Pulls Deadlock Counts per Target, per Database
SELECT esc.ObjectName, DatabaseName, COUNT (*) AS TheCount  FROM PerformanceAnalysisTraceDeadlock patd
JOIN DeadlockDatabaseDeadlock ddd ON patd.ID = ddd.DeadlockID
JOIN DeadlockDatabase dd ON ddd.DeadlockDatabaseID = dd.ID
JOIN EventSourceConnection esc ON patd.EventSourceConnectionID = esc.ID
--WHERE StartTime > '2017-03-21 19:55:35.847' and StartTime < '2017-03-21 19:55:35.847'
--AND esc.ObjectName like '%<Target Name>%'
GROUP BY esc.ObjectName, DatabaseName
ORDER BY TheCount DESC 

--Pulls Deadlock Counts per Target, per User
SELECT esc.ObjectName, UserName, COUNT (*) AS TheCount  FROM PerformanceAnalysisTraceDeadlock patd
JOIN DeadlockUserDeadlock dud ON patd.ID = dud.DeadlockID
JOIN DeadlockUser du ON dud.DeadlockUserID = du.ID
JOIN EventSourceConnection esc ON patd.EventSourceConnectionID = esc.ID
--WHERE StartTime > '2017-03-21 19:55:35.847' and StartTime < '2017-03-21 19:55:35.847'
--AND esc.ObjectName like '%<Target Name>%'
GROUP BY esc.ObjectName, UserName
ORDER BY TheCount DESC 

--Pulls Deadlock Counts per Target, per Resource
SELECT esc.ObjectName, ResourceName, COUNT (*) AS TheCount  FROM PerformanceAnalysisTraceDeadlock patd
JOIN DeadlockResourceDeadlock drd ON patd.ID = drd.DeadlockID
JOIN DeadlockResource dr ON drd.DeadlockResourceID = dr.ID
JOIN EventSourceConnection esc ON patd.EventSourceConnectionID = esc.ID
--WHERE StartTime > '2017-03-21 19:55:35.847' and StartTime < '2017-03-21 19:55:35.847'
--AND esc.ObjectName like '%<Target Name>%'
GROUP BY esc.ObjectName, ResourceName
ORDER BY TheCount DESC 

--Pulls Deadlock Counts per Target, per TextData
SELECT esc.ObjectName, NormalizedTextData, COUNT (*) AS TheCount  FROM PerformanceAnalysisTraceDeadlock patd
JOIN DeadlockTraceHashDeadlock dthd ON patd.ID = dthd.DeadlockID
JOIN DeadlockTraceHash dth ON dthd.DeadlockTraceHashID = dth.ID
JOIN EventSourceConnection esc ON patd.EventSourceConnectionID = esc.ID
JOIN PerformanceAnalysisTraceHash pth ON dth.NormalizedTextMD5 = pth.NormalizedTextMD5
--WHERE StartTime > '2017-03-21 19:55:35.847' and StartTime < '2017-03-21 19:55:35.847'
--AND esc.ObjectName like '%<Target Name>%'
GROUP BY esc.ObjectName, dth.NormalizedTextMD5, NormalizedTextData
ORDER BY TheCount DESC 

---------------------------------------------------------------------------------------------------------------


/*General Alert Mining Template*/
SELECT parentobjectname AS ParentObject, 
       objectname AS Job, 
       Count(*) AS TheCount 
FROM   objectconditionactionhistory ocah 
       JOIN conditiontype ct 
         ON ocah.conditiontypeid = ct.id 
       JOIN conditiontypecategory ctc 
         ON ct.conditiontypecategoryid = ctc.id 
WHERE  conditiontypename = '<ConditionName>' --Update to desired Condition 
AND ActionTypeName = 'Send Email' 
AND EventStartTime > DATEADD(day, -90, GETDATE())
GROUP  BY parentobjectname, 
          objectname 
ORDER  BY thecount DESC 


