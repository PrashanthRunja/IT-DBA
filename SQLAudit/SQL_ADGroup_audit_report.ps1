$HostServer = "P054SQLMGMT03\SQLADMIN"
$HostDB = "DBASUPPORT"

$OutFileLog = "D:\PowerShell\test1\SQLAUDIT.xlsx"

#If file exists Delete
if (Test-Path $OutFileLog) {
  Remove-Item $OutFileLog
  write-host "$OutFileLog has been deleted"
}

else {
  Write-host "$OutFileLog doesn't exist"
}

$DCs = Invoke-Sqlcmd -ServerInstance $HostServer -Database $HostDB -Query "SELECT distinct Datacenter from [DBASupport].[dbo].[SQL_ADGroup_audit_master] order by Datacenter"

Foreach($DC in $DCs)
{
$DC = $DC.Datacenter

$DBQuery= "select Datacenter, GroupName,name,objectclass,samaccountname,date  from [DBASupport].[dbo].[SQL_ADGroup_audit_master] where datacenter = '$DC' order by name"
$Grid = Invoke-Sqlcmd -ServerInstance $HostServer -Query $DBQuery | select Datacenter, GroupName,name,objectclass,samaccountname,date 

$Grid | Export-Excel -Path $OutFileLog -AutoSize -TableName $DC -WorksheetName $DC
}

Send-MailMessage -Body "Please find the attached spread sheet for SQL Audit</br></br>" -To prashanthkumar.runja@epiqglobal.com,pannadasu@epiqglobal.com -From DL-SQLDatabaseSupportL1@epiqglobal.com -SmtpServer mailrelay.amer.epiqcorp.com -Subject "SQLAUDIT - $PackageStartTime"  -BodyAsHtml -Attachments $OutFileLog
