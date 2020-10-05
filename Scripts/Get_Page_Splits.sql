/*
	| https://docs.microsoft.com/de-de/archive/blogs/sql_pfe_blog/three-usage-scenarios-for-sys-dm_db_index_operational_stats
	| Page Split Tracking
	| Excessive page splitting can have a significant effect on performance. The following query identifies 
	| the top 10 objects involved with page splits (ordering by leaf_allocation_count and referencing both 
	| the leaf_allocation_count and nonleaf_allocation_count columns). The leaf_allocation_count column represents 
	| page splits at the leaf and the nonleaf_allocation_count represents splits at the non-leaf levels of an index:
*/
SELECT TOP 10
	OBJECT_NAME(object_id, database_id) object_nm
	, index_id
	, partition_number
	, leaf_allocation_count
	, nonleaf_allocation_count
FROM sys.dm_db_index_operational_stats
	(db_id(), NULL, NULL, NULL)
ORDER BY leaf_allocation_count DESC
