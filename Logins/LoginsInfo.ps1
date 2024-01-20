$DataCenter = 'AZUR'
$HostServer = "SQLUTIL.SETTLEMENTPLAN.LOCAL\SQLADMIN"
$HostDB = "DBASUPPORT"
$Table = "Logins_info"

$ServerList = "select name from msdb.dbo.sysmanagement_shared_registered_servers_internal where server_group_id=14 order by server_group_id,name"
$Servers = Invoke-Sqlcmd -ServerInstance $HostServer -Query $ServerList | Select-Object name -ExpandProperty name | Sort-Object name
$Servers = $Servers.name
#$Servers="P054ECASISP51.amer.EPIQCORP.COM"

$TableQuery = @"   
IF OBJECT_ID('$Table','U') is not null
TRUNCATE TABLE $Table
ELSE

CREATE TABLE [dbo].[$Table](
	[Datacenter] [nvarchar](10) NULL,
	[SqlInstance] [nvarchar](50) NULL,
	[LoginName] [nvarchar](100) NULL,
	[LoginType] [nvarchar](50) NULL,
	[ServerRoleName] [nvarchar](20) NULL,
	[Password_PolicyChecked] [bit] NULL,
	[Password_ExpiryChecked] [bit] NULL,
	[LoginDisabled] [bit] NULL,
	[PasswordLastSetTime] [datetime],
	[DatabaseName] [nvarchar](300) NULL,
	[UserName] [nvarchar](100) NULL,
	[UserPermissions] [nvarchar](500) NULL,
	[LoginCreateDate] [datetime],
	[LastAccessDate] [datetime],
	[LastUpdated] [datetime] DEFAULT GETDATE() NOT NULL
) ON [PRIMARY]
GO

"@
 Invoke-Sqlcmd -ServerInstance $HostServer -Database $HostDB -Query $TableQuery

foreach($Server in $Servers)
{
write-host $Server

$Logins=""
$LoginQuery= "DECLARE @DB_USers TABLE
            (DBNames sysname, UserName sysname, LoginType sysname, AssociatedRole varchar(max),create_date datetime,modify_date datetime)
            INSERT @DB_USers
            EXEC SP_MSforeachdb
            '
            use [?]
            SELECT ''?'' AS DB_Name,
            case prin.name when ''dbo'' then prin.name + '' (''+ (select SUSER_SNAME(owner_sid) from master.sys.databases where name =''?'') + '')'' else prin.name end AS UserName,
            prin.type_desc AS LoginType,
            isnull(USER_NAME(mem.role_principal_id),'''') AS AssociatedRole ,create_date,modify_date
            FROM sys.database_principals prin
            LEFT OUTER JOIN sys.database_role_members mem ON prin.principal_id=mem.member_principal_id
            WHERE prin.sid IS NOT NULL and prin.sid NOT IN (0x00) and
            prin.is_fixed_role <> 1 AND prin.name not in (''public'',''dbo'')
            AND prin.name NOT LIKE ''##%'''

            SELECT
            '$DataCenter' as Datacenter
            ,'$Server' as Instance
            ,dp.name as [LoginName]
            ,dp.[type_desc] as [LoginType]
            ,pb.name as [ServerRoleName]
            ,sl.is_policy_checked as [Password_PolicyChecked]
            ,sl.is_expiration_checked as [Password_ExpiryChecked]
            ,dp.is_disabled as [LoginDisabled]
            ,LOGINPROPERTY(dp.name, 'PasswordLastSetTime') AS [PasswordLastSetTime]
            , [DBNames]
            ,[UserName],
            STUFF(
            (
            SELECT ',' + CONVERT(VARCHAR(500),associatedrole)
            FROM @DB_USers user2
            WHERE user1.DBNames=user2.DBNames AND user1.UserName=user2.UserName
            FOR XML PATH('')
            ),1,1,'') AS UserPermissions,
            dp.create_date as [LoginCreateDate], max(At.login_time) as [LastAccessDate]
            FROM @DB_USers user1
            right join sys.server_principals dp on dp.name = user1.UserName 
            left join sys.server_role_members rm on dp.principal_id = rm.member_principal_id
            LEFT join sys.server_principals pb on rm.role_principal_id = pb.principal_id
            LEFT join sys.sql_logins sl on dp.principal_id = sl.principal_id 
            LEFT join sys.syslogins sqll on dp.name =sqll.name 
			LEFT join [DBASupport].[dbo].[__AccessTracker] AT on dp.name  = AT.[login_name]			
            where dp.name not like '%##%' and dp.type_desc not in ('SERVER_ROLE') and loginname not like 'NT%'
            --and  dp.name ='AMER\631936'
            GROUP BY
            At.[login_name],dp.name,pb.name,DBNames,sl.is_policy_checked,dp.is_disabled,sl.is_expiration_checked,username ,logintype,dp.create_date,sqll.accdate,dp.[type_desc] 
            ORDER BY LoginName,DBNames,username"

    $Logins = Invoke-Sqlcmd -ServerInstance $Server -Query $LoginQuery -QueryTimeout 0 

    Foreach($Login in $Logins)
    {

    $Datacenter=$Login.Datacenter; $SqlInstance = $Login.Instance; $LoginName=$Login.LoginName; $LoginType=$Login.LoginType; $ServerRoleName=$Login.ServerRoleName; $Password_PolicyChecked= $Login.Password_PolicyChecked; 
    $Password_ExpiryChecked=$Login.Password_ExpiryChecked; $LoginDisabled=$Login.LoginDisabled; $PasswordLastSetTime=$Login.PasswordLastSetTime; $DBNames=$Login.DBNames; $UserName=$Login.UserName; $UserPermissions=$Login.UserPermissions; 
    $LoginCreateDate=$Login.LoginCreateDate; $LastAccessDate=$Login.LastAccessDate;  

    $Insert = "INSERT into dbo.Logins_info ([Datacenter], [SqlInstance], [LoginName],[LoginType],[ServerRoleName],[Password_PolicyChecked],[Password_ExpiryChecked],[LoginDisabled],[PasswordLastSetTime],[DatabaseName],[UserName],[UserPermissions],[LoginCreateDate],[LastAccessDate])
                            VALUES ('$Datacenter','"  + $SqlInstance + "','" + $LoginName + "','" + $LoginType + "','" + $ServerRoleName + "','" + $Password_PolicyChecked + "','" + $Password_ExpiryChecked + "',
                            '" + $LoginDisabled + "','" + $PasswordLastSetTime + "','" + $DBNames + "','" + $UserName + "','" + $UserPermissions + "','" + $LoginCreateDate + "','" + $LastAccessDate + "')"
    
    
    Invoke-Sqlcmd -ServerInstance $HostServer -Database $HostDB -Query $Insert -Verbose;
    }

}

