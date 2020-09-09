/*
  | If you’ve been running DBCC CHECKDB with Ola Hallengren's scripts, it's easy to find out how
  | long they take (as long as you're logging the commands to a table -- this is the default). 
  | This script will take the CommandLog table that Ola's jobs populate as they run and joins them
  | to backup information to obtain size data.

*/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
DECLARE @startDate DATETIME;
SET @startDate = GETDATE();
WITH cl AS (
SELECT DatabaseName
  , CommandType
  , StartTime
  , EndTime
  , DATEDIFF(SECOND, StartTime, EndTime) AS [DBCC in Minutes]
FROM master.dbo.CommandLog
WHERE CommandType = 'DBCC_CHECKDB'
AND NOT DatabaseName IN ( 'master', 'msdb', 'model', 'tempdb' )
)
SELECT DISTINCT BS.database_name AS [Database Name]
  , CONVERT(NUMERIC(10, 1), BF.file_size / 1048576.0) AS SizeMB
  , cl.DBCC_Minutes
  , CAST( AVG(( BF.file_size / cl.DBCC_Minutes) / 1048576.0) AS INT) AS [Avg MB/Sec]
FROM msdb.dbo.backupset AS BS
INNER JOIN msdb.dbo.backupfile AS BF ON BS.backup_set_id = BF.backup_set_id
INNER JOIN cl ON cl.DatabaseName = BS.database_name
WHERE BF.[file_type] = 'D'
  AND BF.[file_type] = 'D'
  AND BS.type = 'D'
  AND BS.backup_start_date BETWEEN DATEADD(yy, -1, @startDate) AND @startDate
GROUP BY BS.database_name, CONVERT(NUMERIC(10, 1), BF.file_size / 1048576.0), cl.DBCC_Minutes;
