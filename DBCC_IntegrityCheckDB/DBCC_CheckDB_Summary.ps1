$HostServer = "P054SQLMGMT03\SQLADMIN"
$HostDB = "DBASUPPORT"

$PackageStartTime = [System.TimeZoneInfo]::ConvertTimeBySystemTimeZoneId((Get-Date), 'India Standard Time') 
$SumArray = "" 
$DiffArray = ""

$SumArray = @() 
$DiffArray = @() 
$OutFileLog = "D:\PowerShell\DBCC_Summaryreport.xlsx" 

#If files exists Delete
if (Test-Path $OutFileLog) { Remove-Item $OutFileLog
  write-host "$OutFileLog has been deleted"}
else {Write-host "$OutFileLog doesn't exist"}


$DCs = Invoke-Sqlcmd -ServerInstance $HostServer -Database $HostDB -Query "SELECT DISTINCT DataCenter from dbo.[CommandLog_CheckDB_master] order by DataCenter"
Foreach ($DC in $DCs)
{
$DC=$DC.DataCenter
$Dbquery01= @"
DECLARE @DC varchar(20) = '$DC'
            if object_id('tempdb..#TempA') is not null DROP TABLE #TempA select DataCenter,count([DatabaseName]) As TotalDBCount into  #TempA
            from [DatabaseSettings_master]   where datacenter =@DC group by datacenter
            if object_id('tempdb..#TempB') is not null DROP TABLE #TempB select count ([LastGoodCheckDb]) As [LastGoodCheckDb] into #TempB
            from [DatabaseSettings_master]
            where [LastGoodCheckDb] >= DATEADD(day,-14, GETDATE()) and datacenter =@DC
            if object_id('tempdb..#TempC') is not null DROP TABLE #TempC select Count(ErrorNumber) As ErrorNumber into #TempC
            from [CommandLog_CheckDB_master]
            where ErrorNumber <>0 and datacenter =@DC
            select DataCenter,TotalDBCount,LastGoodCheckDb,TotalDBCount-LastGoodCheckDb As Difference,ErrorNumber from  #TempA, #TempB,#Tempc
"@
$SumArray += Invoke-Sqlcmd -ServerInstance $HostServer -Database $HostDB -Query $Dbquery01 | select DataCenter,TotalDBCount, LastGoodCheckDb,Difference,ErrorNumber

$Dbquery02="select B.DataCenter,B.SqlInstance,B.[DatabaseName],B.LastGoodCheckDb,A.StartTime,A.EndTime,A.ErrorNumber from [CommandLog_CheckDB_master] A
                right join [DatabaseSettings_master] B
                on  A.SqlInstance = B.SqlInstance and  A.[Database] =B.[DatabaseName]
                where
                --A.ErrorNumber <> 0
                --and
                LastGoodCheckDb <= DATEADD(day,-14, GETDATE())
                order by SqlInstance,[Database]"
$DiffArray += Invoke-Sqlcmd -ServerInstance $HostServer -Database $HostDB -Query $Dbquery02 | select DataCenter,SqlInstance, DatabaseName,LastGoodCheckDb,StartTime,EndTime,ErrorNumber
}

$SumArray | Export-Excel -Path $OutFileLog -AutoSize -TableName Summary -WorksheetName Summary
$DiffArray | Export-Excel -Path $OutFileLog -AutoSize -TableName Discrepancies -WorksheetName Discrepancies

Send-MailMessage -Body "Please find the attached spread sheet for DBCC Validations</br></br>" -To prashanthkumar.runja@epiqglobal.com,pannadasu@epiqglobal.com -From DL-SQLDatabaseSupportL1@epiqglobal.com -SmtpServer mailrelay.amer.epiqcorp.com -Subject "DBCC Report - $PackageStartTime"  -BodyAsHtml -Attachments $OutFileLog



