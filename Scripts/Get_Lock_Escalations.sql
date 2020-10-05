/*
  |https://blogs.msdn.microsoft.com/sql_pfe_blog/2009/06/11/three-usage-scenarios-for-sys-dm_db_index_operational_stats
  | to track how many attempts were made to escalate to table locks (index_lock_promotion_attempt_count), 
  | as well as how many times escalations actually succeeded (index_lock_promotion_count). 
*/
SELECT TOP 3
  OBJECT_NAME(object_id, database_id) object_nm
  , index_id
  , partition_number
  , index_lock_promotion_attempt_count
  , index_lock_promotion_count
FROM sys.dm_db_index_operational_stats (db_id(), NULL, NULL, NULL)
ORDER BY index_lock_promotion_count DESC
