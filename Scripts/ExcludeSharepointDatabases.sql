/*
	==========================================================================================
	| File:     ExcludeSharepointDatabases.sql
	| Version:  16.01 - January, 2016

	|Summary:  	
		This script will find all Sharepoint Databases on Instance and 
		exclude them from Maintenance plan (State: 26 January 2016).

	| Version Updates:
		26.01.2016 | Added by Dmitry Spitsyn
			# GET AND EXCLUDE SHAREPOINT DATABASES
	==========================================================================================
*/
CREATE TABLE #SPDB (databasename sysname PRIMARY KEY CLUSTERED);
INSERT INTO #SPDB (databasename)
EXEC sp_msforeachdb N'USE [?];
SELECT DISTINCT db_name()
FROM sys.extended_properties AS p
WHERE class_desc = ''DATABASE'' AND name = ''isSharePointDatabase'' AND value = 1;';

DECLARE @UserDatabases NVARCHAR(MAX) = '';
-- Output of all NONE-Sharepoint databases
SELECT @UserDatabases = @UserDatabases + d.name + ', '
FROM sys.databases d LEFT JOIN #SPDB s ON (d.name = s.DatabaseName)
WHERE d.database_id != 2 AND s.DatabaseName IS NULL;

IF @UserDatabases = ''
	SET @UserDatabases = 'ALL_DATABASES';
ELSE
	SET @UserDatabases = LEFT(@UserDatabases, LEN(@UserDatabases) - 1);

DROP TABLE #SPDB;
EXEC msdb.dbo.IndexOptimize
	  @Databases = @UserDatabases
	, @FragmentationLow = NULL
	, @FragmentationMedium = 'INDEX_REORGANIZE,INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'
	, @FragmentationHigh = 'INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE'
	, @FragmentationLevel1 = 5
	, @FragmentationLevel2 = 30
	, @PadIndex = 'N'
	, @Indexes = 'ALL_INDEXES'
	, @UpdateStatistics = 'ALL'
	, @OnlyModifiedStatistics = 'N'
	, @StatisticsSample = 100
	, @LogToTable = 'Y';
