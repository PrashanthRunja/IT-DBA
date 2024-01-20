$HostServer = "P054SQLMGMT02\SQLADMIN"
$HostDB = "DBASUPPORT"

$ServerList = "select name from msdb.dbo.sysmanagement_shared_registered_servers_internal where server_group_id=9"
$Servers = Invoke-Sqlcmd -ServerInstance $HostServer -Query $ServerList | Select-Object name -ExpandProperty name | Sort-Object name
$Servers = $Servers.name


$Total =@()
#$Today = Get-Date -format "yyyyMMdd"
#$30days = Get-Date -Date $30DaysAgo -Format 'yyyyMMdd'

foreach ($SQLInstance in $servers) 
{
       $instance = $SQLInstance
       #$computer= $instance -replace "\*",""
        if($instance.IndexOf("\") -gt 0) {
             $computer = $instance.Substring(0, $instance.IndexOf("\"))
        } else {
             $computer = $instance
        }

$ErrorLogPath = Get-DbaDefaultPath -SqlInstance $SQLInstance | select errorlog -ExpandProperty errorlog
#Write-Host $SQLInstance +'  '+ $ErrorLogPath  | Format-Table -AutoSize

$files=Invoke-Command -Cn $computer { Get-ChildItem $Using:ErrorLogPath -Recurse| Where-Object {$_.Extension -eq '.txt' -and $_.LastWriteTime -lt  (Get-Date).AddDays(-30)}}

#Invoke-Command -Computer $SQLInstance | Get-ChildItem -Path $ErrorLogPath -Recurse -Include *.log
#$files=Get-DbaFile -SqlInstance $SQLInstance -Path $ErrorLogPath -FileType txt
    if($files.Count -gt 200)
    {
    $Total += $SQLInstance +'  '+ $files.Count | Format-Table -AutoSize
    }
}
$Total

<#
$SQLInstance ="P054FLTSQLS02.uscust.local\FORLITST"
Get-DbaDefaultPath -SqlInstance $SQLInstance | select errorlog -ExpandProperty errorlog
#>




