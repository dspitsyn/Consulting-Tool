/*
	| Some tips for minimizing tempdb utilization
	| 1. Use fewer #temp tables and @table variables
	| 2. Minimize concurrent index maintenance, and avoid the SORT_IN_TEMPDB option if it isn't needed
	| 3. Avoid unnecessary cursors; avoid static cursors if you think this may be a bottleneck, since static cursors use work tables in tempdb
	| 4. Try to avoid spools (e.g. large CTEs that are referenced multiple times in the query)
	| 5. don't use MARS thoroughly test the use of snapshot / RCSI isolation levels - don't just turn it on for all databases since you've been told it's better than NOLOCK 
	| (it is, but it isn't free) in some cases, it may sound unintuitive, but use more temp tables. e.g. breaking up a humongous query into parts may be slightly less efficient, 
	| but if it can avoid a huge memory spill to tempdb because the single, larger query requires a memory grant too large...
	| 6. Avoid enabling triggers for bulk operations
	| 7. Avoid overuse of LOB types (max types, XML, etc) as local variables
	| 8. keep transactions short and sweet
	| 9. Don't set tempdb to be everyone's default database
*/
DBCC DROPCLEANBUFFERS
GO
DBCC FREEPROCCACHE
GO
DBCC FREESESSIONCACHE
GO
DBCC FREESYSTEMCACHE ('ALL')
GO

DBCC SHRINKFILE (N'temppro' , 0, TRUNCATEONLY)
GO
DBCC SHRINKFILE (N'temppro1' , 0, TRUNCATEONLY)
GO
DBCC SHRINKFILE (N'temppro2' , 0, TRUNCATEONLY)
GO
DBCC SHRINKFILE (N'temppro3' , 0, TRUNCATEONLY)
GO
