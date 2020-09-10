/*
  | Version: 16.01
  | Description:
  | These days, 8 files is where most folks see performance level off, if 4 isn't cutting it.
  | Just make sure they're all the same starting size and have all the same autogrowth settings. 
  | Having unevenly sized files can lead to uneven query distribution across them.
*/
SELECT name, physical_name AS [CurrentLocation]
FROM sys.master_files  
WHERE database_id = DB_ID(N'tempdb');  
GO
USE master;  
GO  
ALTER DATABASE tempdb   
MODIFY FILE (NAME = tempdev, FILENAME = 'H:\DEVSQLTEMP\DEV.SQLTEMP\tempdev.mdf'); 
GO
ALTER DATABASE tempdb   
MODIFY FILE (NAME = tempdev01, FILENAME = 'H:\DEVSQLTEMP\DEV.SQLTEMP\tempdev01.ndf');
GO
ALTER DATABASE tempdb   
MODIFY FILE (NAME = tempdev02, FILENAME = 'H:\DEVSQLTEMP\DEV.SQLTEMP\tempdev02.ndf');
GO
ALTER DATABASE tempdb   
MODIFY FILE (NAME = tempdev03, FILENAME = 'H:\DEVSQLTEMP\DEV.SQLTEMP\tempdev03.ndf');
GO 
ALTER DATABASE tempdb   
MODIFY FILE (NAME = templog, FILENAME = 'H:\DEVSQLTEMP\DEV.SQLTEMP\templog.ldf');  
GO
