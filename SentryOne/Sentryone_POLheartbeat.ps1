
$SqlInstance = "P054SENSQLS01.Epiqcorp.com"
$DB="SQLSentry"

$Header = @"
<style>
TABLE {border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
TH {border-width: 1px; padding: 3px; border-style: solid; border-color: black; background-color: #9FD4DC;text-align: left;}
TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
</style>
"@


$DBQuery = "use SQLSentry
SELECT [ManagementEngineName]
          ,[SiteName]
          ,[HeartbeatDateTime]
	      ,GETUTCDATE() AS UTCTime
          ,datediff(HOUR,[HeartbeatDateTime],GETUTCDATE()) as TimeDiff_Hours  
          ,[ServiceAccountName]
          ,[ServiceVersion]
          ,[DeviceCount]
      FROM SQLSentry.[dbo].vwMonitoringServiceList
	  union
SELECT [ManagementEngineName]
          ,[SiteName]
          ,[HeartbeatDateTime]
	      ,GETUTCDATE() AS UTCTime
          ,datediff(HOUR,[HeartbeatDateTime],GETUTCDATE()) as TimeDiff_Hours  
          ,[ServiceAccountName]
          ,[ServiceVersion]
          ,[DeviceCount]
      FROM [TUK-I-SQLSEN-01.corp.dtiglobal.com].SentryOne.[dbo].vwMonitoringServiceList
      --where datediff(HOUR,[HeartbeatDateTime],GETUTCDATE())>2 
      order by [ManagementEngineName]"


   $POL = Invoke-Sqlcmd -ServerInstance $SqlInstance -Database $DB -Query $DBQuery -Verbose | Select ManagementEngineName,SiteName,HeartbeatDateTime,UTCTime,TimeDiff_Hours,ServiceAccountName,DeviceCount 

   If($POL.Count -ne 0)
   {

    $POL =$POL | ConvertTo-Html -Head $Header

    Send-MailMessage -Body "Heartbeat monitoring check on the SentryOne POLER machines</br></br>$POL" -To EPIQ-DBA-IND@epiqglobal.com -From DL-SQLDatabaseSupportL1@epiqglobal.com -SmtpServer mailrelay.amer.epiqcorp.com -Subject "SentryOne heartbeat check"  -BodyAsHtml
    }
 

