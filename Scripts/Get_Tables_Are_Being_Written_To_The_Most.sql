/*
	| What Tables Are Being Written To The Most?
	| But it’s a tricky kind of script. It takes a while to run on busy systems. 
  | There’s a faster way to drill into writes if you switch your focus from which queries are writing so much to which tables are being written to so much. 
  | Both methods of drilling down can be helpful, but the table approach is faster and doesn’t require an extended event session and it might be enough to point you in the right direction.
  | Created by Michael J. Swart
*/
USE [specify your databasename here]
 
-- get the latest lsn for current DB
DECLARE @xact_seqno binary(10);
DECLARE @xact_seqno_string_begin varchar(50);
EXEC sp_replincrementlsn @xact_seqno OUTPUT;
SET @xact_seqno_string_begin = '0x' + CONVERT(varchar(50), @xact_seqno, 2);
SET @xact_seqno_string_begin = stuff(@xact_seqno_string_begin, 11, 0, ':')
SET @xact_seqno_string_begin = stuff(@xact_seqno_string_begin, 20, 0, ':');
 
-- wait a few seconds
WAITFOR DELAY '00:00:10'
 
-- get the latest lsn for current DB
DECLARE @xact_seqno_string_end varchar(50);
EXEC sp_replincrementlsn @xact_seqno OUTPUT;
SET @xact_seqno_string_end = '0x' + CONVERT(varchar(50), @xact_seqno, 2);
SET @xact_seqno_string_end = stuff(@xact_seqno_string_end, 11, 0, ':')
SET @xact_seqno_string_end = stuff(@xact_seqno_string_end, 20, 0, ':');
 
WITH [Log] AS
(
  SELECT Category, 
         SUM([Log Record Length]) AS [Log Bytes]
  FROM   fn_dblog(@xact_seqno_string_begin, @xact_seqno_string_end)
  CROSS  APPLY (SELECT ISNULL(AllocUnitName, Operation)) AS C(Category)
  GROUP  BY Category
)
SELECT   Category, 
         [Log Bytes],
         100.0 * [Log Bytes] / SUM([Log Bytes]) OVER () AS [%]
FROM     [Log]
ORDER BY [Log Bytes] DESC;
