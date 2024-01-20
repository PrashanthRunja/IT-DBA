$servername = 'P054WFSQLSSRS01.amer.EPIQCORP.COM'
$CohesityCluster = 'p054dpgcoh101'
$username = '637741'
$domain = 'AMER.EPIQCORP.COM'
$instanceDBname = 'SSISRS/ReportServerTempDB'
$objects = $servername + '/' + $instanceDBname
$objects

$jobName = D:\PowerShell\Cohesity_PS\PS\protectedBy.ps1 -vip $CohesityCluster -username $username -domain $domain -object $servername -jobType sql -quickSearch -returnJobName
$jobName

D:\PowerShell\Cohesity_PS\PS\backupNow.ps1 -vip $CohesityCluster `
                                        -username $username `
                                        -domain $domain `
                                        -jobName $jobName `
                                        -backupType kLog `
                                        -objects $objects `
                                        -localOnly `
                                        -progress `
                                        -wait


