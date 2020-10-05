/*
	| Identifying Top Objects Associated with Lock Contention
	| If you have a significant number of database objects, you can use sys.dm_db_index_operational_stats 
	| to efficiently identify tables associated with a significant amount of blocking.
	| Identifying the top 3 objects associated with waits on page locks
*/
SELECT TOP 3
	OBJECT_NAME(o.object_id, o.database_id) object_nm
	, o.index_id
	, partition_number
	, page_lock_wait_count
	, page_lock_wait_in_ms
	, case when mid.database_id is null then 'N' else 'Y' end as missing_index_identified
FROM sys.dm_db_index_operational_stats (db_id(), NULL, NULL, NULL) o
	LEFT OUTER JOIN (SELECT DISTINCT database_id, object_id
FROM sys.dm_db_missing_index_details) as mid ON mid.database_id = o.database_id and mid.object_id = o.object_id
ORDER BY page_lock_wait_count DESC
