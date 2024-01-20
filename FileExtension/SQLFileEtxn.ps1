$DataCenter = 'LVDC'
$HostServer = "P054SQLMGMT03\SQLADMIN"
$HostDB = "DBASUPPORT"
$Table = "SQLDBFileExtension"

$ServerList = "select name from msdb.dbo.sysmanagement_shared_registered_servers_internal where server_group_id in('20','23')"
$Servers = Invoke-Sqlcmd -ServerInstance $HostServer -Query $ServerList | Select-Object name -ExpandProperty name | Sort-Object name
$Servers = $Servers.name
#$Servers ="P054ECASQLS11.amer.EPIQCORP.COM"

$TableQuery = @"   
IF OBJECT_ID('$Table','U') is not null
TRUNCATE TABLE $Table
ELSE

CREATE TABLE [dbo].[$Table](
	[Datacenter] [nvarchar](10) NULL,
	[SQLInstance] [nvarchar](50) NULL,
	[DatabaseName] [nvarchar](300) NULL,
    [DateCreated] [date] NULL,
	[FileType] [nvarchar](10) NULL,
	[FileName] [nvarchar](300) NULL,
	[JobStatus] [nvarchar](15) NULL,
	[LastUpdated] [datetime] DEFAULT GETDATE() NOT NULL
) ON [PRIMARY]
GO

"@
 Invoke-Sqlcmd -ServerInstance $HostServer -Database $HostDB -Query $TableQuery

foreach ($SQLInstance in $servers) 
{
$SQLQuery= "SELECT 
'$SQLInstance' as SQLInstance, DB.NAME AS DatabaseName,db.create_date as DateCreated, TYPE_DESC AS FileType, PHYSICAL_NAME AS FileName
FROM SYS.MASTER_FILES MF
INNER JOIN SYS.DATABASES DB ON DB.DATABASE_ID = MF.DATABASE_ID
where PHYSICAL_NAME not like '%MDF%' and PHYSICAL_NAME not like '%LDF%' and PHYSICAL_NAME not like '%NDF%'
ORDER BY DatabaseName"

$Files= Invoke-Sqlcmd -ServerInstance $SQLInstance -Query $SQLQuery | Select Datacenter,SQLInstance,DatabaseName,DateCreated,FileType,FileName  #| where DatabaseName -NotLike LogicalName

if($Files) 
{

$JobQuery="SELECT @@SERVERNAME as SQLInstance, [name] as 'job name', [enabled] as 'JobStatus'
FROM msdb.dbo.sysjobs
where name='DBA - File Extension Fix'"

$JobStatus = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query $JobQuery | Select JobStatus -ExpandProperty JobStatus


if($Files) 
{

    $JobQuery="SELECT @@SERVERNAME as SQLInstance, [name] as 'job name', [enabled] as 'JobStatus'
    FROM msdb.dbo.sysjobs
    where name='DBA - File Extension Fix'"

    $JobStatus = Invoke-Sqlcmd -ServerInstance $SQLInstance -Query $JobQuery | Select JobStatus -ExpandProperty JobStatus
    if(([string]::IsNullOrWhitespace($JobStatus))) 
    {
    $JobStatus = 'Job not exists'
    }
    foreach ($File in $Files) 
    {
        Write-Host $File

        $Insert = "INSERT into dbo.$Table (Datacenter,SQLInstance, DatabaseName,DateCreated, FileType, FileName,JobStatus)
                                    VALUES ('$Datacenter','"  + $SQLInstance + "','" + $File.DatabaseName + "','" + $File.DateCreated + "','" + $File.FileType + "','" + $File.FileName + "','" + $JobStatus + "')"

        Invoke-Sqlcmd -ServerInstance $HostServer -Database $HostDB -Query $Insert -Verbose;
    }

}


#Get-DbaDbFile -SqlInstance 'P054SQLMGMT03\SQLADMIN'| select Database,LogicalName | where {$_.Database -notmatch [$_.LogicalName]}
}
}
