$HostServer = "P054SQLMGMT03\SQLADMIN"
$HostDB = "DBASUPPORT"

$ServerList = "select name from msdb.dbo.sysmanagement_shared_registered_servers_internal where server_group_id in('20','23') and (name not like '%SOLARWINDS' and name not like '%CIC') order by name"
$Servers = Invoke-Sqlcmd -ServerInstance $HostServer -Query $ServerList | Select-Object name -ExpandProperty name | Sort-Object name
$Servers = $Servers.name

Foreach($SQLInstance in $Servers)
{
#Write-Host $SQLInstance
$sql = @"
DECLARE @Svg NVARCHAR(50)
SELECT @Svg =  service_account FROM sys.dm_server_services WHERE servicename like 'SQL Server%' and servicename not like '%Agent%' --and service_account like '%SVG%'
--Select @@SERVERNAME,@Svg

SELECT  @@SERVERNAME As ServerName,@Svg As ServiceAccount,
    CASE WHEN EXISTS 
    (
        select @@SERVERNAME as Servername, m.name member_name,r.name role_namelogoff 

from sys.server_principals r
join sys.server_role_members rm
on r.principal_id = rm.role_principal_id
join sys.server_principals m
on m.principal_id = rm.member_principal_id
where m.name = @Svg
    )
    THEN 'Login exists'
    ELSE 'Login not exists'
END As Login

--DECLARE @sql nvarchar(max) = 'CREATE LOGIN ' + quotename(@svg) + ' FROM WINDOWS WITH DEFAULT_DATABASE=[master]'+','+' DEFAULT_LANGUAGE=[us_english] 
--ALTER SERVER ROLE [sysadmin] ADD MEMBER' + quotename(@svg);
--exec(@sql)
"@
invoke-sqlcmd -ServerInstance $SQLInstance -Query $sql | Select-Object Servername,ServiceAccount,Login

#$isSysadmin = ( @(invoke-sqlcmd $sql -ServerInstance $SQLInstance ).Count -eq 1 )
#write-host $SQLInstance,$sql "Is a sysadmin: $isSysadmin"
}


