/*
  | This query will tell you, for each database, how big it was in MB, how long the full backup took, and the average MB/sec.
  | Cheap hardware disks aren't good, and good disks aren't cheap.
*/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED
DECLARE @startDate DATETIME;
SET @startDate = GETDATE();
SELECT BS.database_name
  , CONVERT(NUMERIC(10, 1), BF.file_size / 1048576.0) AS [Size in MB]
  , DATEDIFF(SECOND, BS.backup_start_date, BS.backup_finish_date) AS [Backup in seconds]
  , CAST(AVG(( BF.file_size / ( DATEDIFF(ss, BS.backup_start_date, BS.backup_finish_date) ) / 1048576 )) AS INT) AS [Avg MB/Sec]
FROM msdb.dbo.backupset AS BS
INNER JOIN msdb.dbo.backupfile AS BF
ON BS.backup_set_id = BF.backup_set_id
WHERE NOT BS.database_name IN ( 'master', 'msdb', 'model', 'tempdb' )
 AND BF.[file_type] = 'D'
 AND BS.type = 'D'
 AND BS.backup_start_date BETWEEN DATEADD(yy, -1, @startDate) AND
@startDate
GROUP BY BS.database_name, CONVERT(NUMERIC(10, 1), BF.file_size / 1048576.0),
DATEDIFF(SECOND, BS.backup_start_date, BS.backup_finish_date)
© 2017 Brent Ozar Unlimited®. For comments, questions, and the latest version free, visit: https://www.BrentOzar.com/go/gce
ORDER BY CONVERT(NUMERIC(10, 1), BF.file_size / 1048576.0);
