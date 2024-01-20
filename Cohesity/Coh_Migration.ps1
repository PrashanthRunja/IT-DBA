
$CohesityCluster = 'p054dpgcoh301'
$username = '637741'
$domain = 'Amer.EPIQCORP.COM'

$SourceServer ="P054FLTSQLS02.uscust.local"
$SourceInstanceName ="FORLITST"
$TargetServer="P054LITSQLS02.USCUST.LOCAL"
$TargetInstanceName="FORLITST"

$DataPath = "E:\FORLITST_Data_01\MSSQL2019.FORLITST\Data\"
$LogPath = "E:\FORLITST_LOGS_01\MSSQL2019.FORLITST\Logs\"


#Incremnatal Backup
$jobName = D:\PowerShell\Cohesity_PS\PS\protectedBy.ps1 -vip $CohesityCluster -username $username -domain $domain -object $SourceServer -jobType sql -quickSearch -returnJobName
$jobName

D:\PowerShell\Cohesity_PS\PS\backupNow.ps1 -vip $CohesityCluster `
                                        -username $username `
                                        -domain $domain `
                                        -jobName $jobName `
                                        -backupType kRegular `
                                        -localOnly `
                                        -progress `
                                        -wait



if((![string]::IsNullOrWhitespace($SourceInstanceName)))
{
$SourceInstance = $SourceServer +'/'+ $SourceInstanceName
}
else
{
$SourceInstance=$TargetServer
}

if((![string]::IsNullOrWhitespace($TargetInstanceName)))
{
$TargetInstance = $TargetServer +'/'+ $TargetInstanceName
}
else
{
$TargetInstance=$TargetServer
}

$Dbs =Invoke-Sqlcmd -ServerInstance "P054SQLMGMT03\SQLADMIN" -Database DBASupport -Query "select databasename from databasesettings_master where sqlinstance like '$SourceServer%' and databasename not in ('master','model','msdb','tempdb','DBASupport')order by databasename" | select databasename -ExpandProperty databasename
foreach($SourceDatabase in $Dbs)
    {
    write-host $SourceDatabase 


    if((![string]::IsNullOrWhitespace($SourceInstanceName)))
    {
    $SourceDatabase = $SourceInstanceName +'/'+ $SourceDatabase
    }
    if((![string]::IsNullOrWhitespace($TargetInstanceName)))
    {
    $TargetDatabase = $SourceDatabase
    }

    $SourceServer, $TargetServer , $SourceDatabase , $TargetDatabase, $TargetInstanceName

    #Restore
    D:\PowerShell\Cohesity_PS\PS\restoreSQL.ps1 -vip $CohesityCluster `
                                            -username $username `
                                            -domain $domain `
                                            -clusterName $CohesityCluster `
                                            -sourceServer $SourceServer `
                                            -targetServer $TargetServer `
                                            -sourceDB $SourceDatabase `
                                            -targetDB $TargetDatabase `
                                            -targetInstance $TargetInstanceName `
                                            -mdfFolder $DataPath `
                                            -ldfFolder $LogPath `
                                            -latest `
                                            -progress `
                                            -overWrite `
                                            -noRecovery
                                        

    }
