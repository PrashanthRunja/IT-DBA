$Datacenter = 'uscust'
$HostServer = "P054SQLMGMT02\SQLADMIN"
$HostDB = "DBASUPPORT"
$Table = "SQL_ADGroup_audit"

$TableQuery = @"   
IF OBJECT_ID('$Table','U') is not null
TRUNCATE TABLE $Table
ELSE

CREATE TABLE [dbo].[$Table](
	[Datacenter] [nvarchar](10) NULL,
	[GroupName] [nvarchar](100) NULL,
	[name] [nvarchar](100) NULL,
	[objectclass] [nvarchar](50) NULL,
	[samaccountname] [nvarchar](100) NULL,
	[date] [datetime] NULL,
) ON [PRIMARY]
GO
GO

"@
 Invoke-Sqlcmd -ServerInstance $HostServer -Database $HostDB -Query $TableQuery

$FIMROLEs = get-adgroupmember -identity "GG-FIMROLE USCUST SQLDBA" | Select-object -Property @{Name="Datacenter";Expression={$Datacenter}},@{Name="GroupName";Expression={"GG-FIMROLE USCUST SQLDBA"}} , name, objectclass, samaccountname, @{name="date";expression={$(get-date)}}  
#$accs | Write-DbaDataTable -SqlInstance $HostServer -Database $HostDB -Schema dbo -Table $Table -BatchSize 5000 -KeepNulls -Verbose

foreach ($FIMROLE in $FIMROLEs)
{
$Datacenter = $FIMROLE.Datacenter.ToString()
$GroupName= $FIMROLE.GroupName.ToString()
$name =$FIMROLE.name.ToString()
$objectclass = $FIMROLE.objectclass.ToString()
$samaccountname = $FIMROLE.samaccountname.ToString()
$date = $FIMROLE.date


$Insert = "INSERT into dbo.SQL_ADGroup_audit (Datacenter, GroupName, name, objectclass, samaccountname, date)
                            VALUES ( '" + $Datacenter + "','" + $GroupName + "','" + $name + "','" + $objectclass + "','" + $samaccountname + "','" + $date + "')"



Invoke-Sqlcmd -ServerInstance $HostServer -Database $HostDB -Query $Insert -Verbose;
}

$USCUSTs = get-adgroupmember -identity "GG-USCUST SQLDBA" | Select-object -Property @{Name="Datacenter";Expression={$Datacenter}},@{Name="GroupName";Expression={"GG-USCUST SQLDBA"}} , name, objectclass, samaccountname, @{name="date";expression={$(get-date)}}  
#$accs | Write-DbaDataTable -SqlInstance $HostServer -Database $HostDB -Schema dbo -Table $Table -BatchSize 5000 -KeepNulls -Verbose

foreach ($USCUST in $USCUSTs)
{
$Datacenter = $USCUST.Datacenter.ToString()
$GroupName= $USCUST.GroupName.ToString()
$name =$USCUST.name.ToString()
$objectclass = $USCUST.objectclass.ToString()
$samaccountname = $USCUST.samaccountname.ToString()
$date = $USCUST.date


$Insert = "INSERT into dbo.SQL_ADGroup_audit (Datacenter, GroupName, name, objectclass, samaccountname, date)
                            VALUES ( '" + $Datacenter + "','" + $GroupName + "','" + $name + "','" + $objectclass + "','" + $samaccountname + "','" + $date + "')"



Invoke-Sqlcmd -ServerInstance $HostServer -Database $HostDB -Query $Insert -Verbose;
}

$EMSs = get-adgroupmember -identity "GG-USCust EMS SQLAdmins" | Select-object -Property @{Name="Datacenter";Expression={$Datacenter}},@{Name="GroupName";Expression={"GG-USCust EMS SQLAdmins"}} , name, objectclass, samaccountname, @{name="date";expression={$(get-date)}}  
#$accs | Write-DbaDataTable -SqlInstance $HostServer -Database $HostDB -Schema dbo -Table $Table -BatchSize 5000 -KeepNulls -Verbose

foreach ($EMS in $EMSs)
{
$Datacenter = $EMS.Datacenter.ToString()
$GroupName= $EMS.GroupName.ToString()
$name =$EMS.name.ToString()
$objectclass = $EMS.objectclass.ToString()
$samaccountname = $EMS.samaccountname.ToString()
$date = $EMS.date


$Insert = "INSERT into dbo.SQL_ADGroup_audit (Datacenter, GroupName, name, objectclass, samaccountname, date)
                            VALUES ( '" + $Datacenter + "','" + $GroupName + "','" + $name + "','" + $objectclass + "','" + $samaccountname + "','" + $date + "')"



Invoke-Sqlcmd -ServerInstance $HostServer -Database $HostDB -Query $Insert -Verbose;
}

