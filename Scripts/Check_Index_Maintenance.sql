/*
  | This is a terrible way to live life. DBAs and Developers have had the 5% and 30% rule for index
  | maintenance pounded into their heads for so long that they don't know any better. No one really
  | measures performance before and after, nor do they take into account the time and resources
  | taken to perform the maintenance against any gains that may have occurred.
  | For thresholds, we usually recommend 50% to reorganize, 80% to rebuild, and for larger databases, only tables with a page count > 5000.
  | Make sure that CommandLog table exists in msdb database.
*/
WITH im AS (
SELECT DatabaseName
  , Command
  , StartTime
  , EndTime
  , DATEDIFF(SECOND, StartTime, EndTime) AS Index_Minutes
  , IndexName
FROM msdb.dbo.CommandLog
WHERE CommandType LIKE '%INDEX%'
  AND NOT DatabaseName IN ( 'master', 'msdb', 'model', 'tempdb' )
)
SELECT t.name
  , i.name AS IndexName
  , (SUM(a.used_pages) *8) / 1024. AS [Index MB]
  , MAX(im.Index_Minutes) AS WorldRecord
  , im.Command
FROM sys.indexes AS i
  JOIN sys.partitions AS p ON p.object_id = i.object_id AND p.index_id = i.index_id
  JOIN sys.allocation_units AS a ON a.container_id = p.partition_id
  JOIN sys.tables t ON t.object_id = i.object_id
  JOIN im ON im.IndexName = i.name
WHERE t.is_ms_shipped = 0
GROUP BY t.name, i.name, im.Command
ORDER BY t.name, i.name;
