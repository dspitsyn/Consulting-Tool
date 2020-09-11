/*
  | Removing Unnecessary Indexes
  | SQL server provides dm_db_index_usage_stats DMV to find index statistics. 
  | Run the T-SQL code below, to get usage statistics for different indexes. 
  | If you find indexes that are not used at all, or used rarely, they can be dropped to gain performance.
*/
SELECT OBJECT_NAME(IUS.[OBJECT_ID]) AS [OBJECT NAME]
  , DB_NAME(IUS.database_id) AS [DATABASE NAME]
  , I.[NAME] AS [INDEX NAME]
  , USER_SEEKS
  , USER_SCANS
  , USER_LOOKUPS
  , USER_UPDATES
FROM SYS.DM_DB_INDEX_USAGE_STATS AS IUS
  INNER JOIN SYS.INDEXES AS I ON I.[OBJECT_ID] = IUS.[OBJECT_ID]
  AND I.INDEX_ID = IUS.INDEX_ID
