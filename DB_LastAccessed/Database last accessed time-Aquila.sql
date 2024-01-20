-- get database last accessed time

declare @db table (dbname sysname, lastAccessDate datetime)

insert into @db
SELECT DatabaseName, MAX(LastAccessDate) LastAccessDate
FROM
    (SELECT
        DB_NAME(database_id) DatabaseName
        , last_user_seek
        , last_user_scan
        , last_user_lookup
        , last_user_update
    FROM sys.dm_db_index_usage_stats) AS PivotTable
UNPIVOT 
    (LastAccessDate FOR last_user_access IN
        (last_user_seek
        , last_user_scan
        , last_user_lookup
        , last_user_update)
    ) AS UnpivotTable
GROUP BY DatabaseName
HAVING DatabaseName NOT IN ('master', 'tempdb', 'model', 'msdb')

insert into @db
select name, null from sys.databases where name not in (select dbname from @db)
and name not in ('master', 'tempdb', 'model', 'msdb')

select * from @db order by lastAccessDate desc


select sqlserver_start_time 
  from sys.dm_os_sys_info
  

