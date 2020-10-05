	/*
		| Step 1
		| Create procedure in msdb Database
	*/
	--------------------------------------------------------------------------------
	USE msdb
	GO
	--------------------------------------------------------------------------------
	IF OBJECT_ID('dbo.sp_BlitzMemoryPressure') IS NULL
		EXEC ('CREATE PROCEDURE dbo.sp_BlitzMemoryPressure AS RETURN 0;');
	GO

	ALTER PROCEDURE dbo.sp_BlitzMemoryPressure
	AS
	SET NOCOUNT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	SET LOCK_TIMEOUT 10000;

	DECLARE @ServiceName NVARCHAR(100)
		, @ExecutionTime DATETIME = GETDATE();
	SET @ServiceName =
		CASE WHEN @@SERVICENAME = 'MSSQLSERVER' THEN 'SQLServer:'
			ELSE 'MSSQL$' + @@SERVICENAME + ':' END;

	/*
	IF OBJECT_ID('USAGE.dbo.MemoryPressure') IS NOT NULL
		DROP TABLE USAGE.dbo.MemoryPressure;
	CREATE TABLE USAGE.dbo.MemoryPressure (
		  ID INT
		, [Counter Name] NVARCHAR(128)
		, [Value] NUMERIC(20, 2)
		, [PointOfTime] DATETIME NULL
		);
	*/

	IF OBJECT_ID('tempdb..#PerformaceValue') IS NOT NULL
		DROP TABLE #PerformaceValue;
	CREATE TABLE #PerformaceValue (
		  object_name NVARCHAR(20)
		, counter_name NVARCHAR(128)
		, instance_name NVARCHAR(128)
		, cntr_value BIGINT
		, formatted_value NUMERIC(20, 2)
		, shortname NVARCHAR(20)
		);

	INSERT INTO #PerformaceValue (object_name, counter_name, instance_name, cntr_value, formatted_value, shortname)
	SELECT
		CASE
			WHEN CHARINDEX('Memory Manager', object_name) > 0 THEN 'Memory Manager'
			WHEN CHARINDEX('Buffer Manager', object_name) > 0 THEN 'Buffer Manager'
			WHEN CHARINDEX('Plan Cache', object_name) > 0 THEN 'Plan Cache'
			WHEN CHARINDEX('Buffer Node', object_name) > 0 THEN 'Buffer Node' -- 2008
			WHEN CHARINDEX('Memory Node', object_name) > 0 THEN 'Memory Node' -- 2012
			WHEN CHARINDEX('Cursor', object_name) > 0 THEN 'Cursor'
			ELSE NULL
		END AS object_name
		, CAST(RTRIM(counter_name) AS NVARCHAR(100)) AS counter_name
		, RTRIM(instance_name) AS instance_name
		, cntr_value
		, CAST(NULL AS DECIMAL(20, 2)) AS formatted_value
		, SUBSTRING(counter_name, 1, PATINDEX('% %', counter_name)) shortname
	FROM sys.dm_os_performance_counters
	WHERE (object_name LIKE @ServiceName + 'Buffer Node%'     -- LIKE is faster than =.
		OR object_name LIKE @ServiceName + 'Buffer Manager%'
		OR object_name LIKE @ServiceName + 'Memory Node%'
		OR object_name LIKE @ServiceName + 'Plan Cache%')
		AND (counter_name LIKE '%pages %'
		OR counter_name LIKE '%Node Memory (KB)%'
		OR counter_name = 'Page life expectancy'
		)
		OR (object_name = @ServiceName + 'Memory Manager'
		AND counter_name IN ('Granted Workspace Memory (KB)'
			, 'Maximum Workspace Memory (KB)'
			, 'Memory Grants Outstanding'
			, 'Memory Grants Pending'
			, 'Target Server Memory (KB)'
			, 'Total Server Memory (KB)'
			, 'Connection Memory (KB)'
			, 'Lock Memory (KB)'
			, 'Optimizer Memory (KB)'
			, 'SQL Cache Memory (KB)'
			/*		2012	*/
			, 'Free Memory (KB)'
			, 'Reserved Server Memory (KB)'
			, 'Database Cache Memory (KB)'
			, 'Stolen Server Memory (KB)'
			)
		)
		OR (object_name LIKE @ServiceName + 'Cursor Manager by Type%'
		AND counter_name = 'Cursor memory usage'
		AND instance_name = '_Total'
		);

	-- Add unit to 'Cursor memory usage'
	UPDATE #PerformaceValue
	SET counter_name = counter_name + ' (KB)'
	WHERE counter_name = 'Cursor memory usage';

	-- Convert values from pages and KB to MB and rename counters accordingly
	UPDATE #PerformaceValue
	SET counter_name = REPLACE(REPLACE(REPLACE(counter_name, ' pages', ''), ' (KB)', ''), ' (MB)', '')
		, formatted_value =
			CASE
				WHEN counter_name LIKE '%pages' THEN cntr_value / 128.
				WHEN counter_name LIKE '%(KB)' THEN cntr_value / 1024.
				ELSE cntr_value
			END;

	-- Delete some pre 2012 counters for 2012 in order to remove duplicates
	DELETE P2008
	FROM #PerformaceValue P2008
		INNER JOIN #PerformaceValue P2012 ON REPLACE(P2008.object_name, 'Buffer', 'Memory') = P2012.object_name
		AND P2008.shortname = P2012.shortname
	WHERE P2008.object_name IN ('Buffer Manager', 'Buffer Node');

	-- Update counter/object names so they look like in 2012

	UPDATE PC

	SET object_name = REPLACE(object_name, 'Buffer', 'Memory')
		, counter_name = ISNULL(M.NewName, counter_name)
	FROM #PerformaceValue PC LEFT JOIN (
	SELECT
		  'Free' AS OldName
		, 'Free Memory' AS NewName

	UNION ALL

	SELECT
		  'Database'
		, 'Database Cache Memory'

	UNION ALL

	SELECT
		  'Stolen'
		, 'Stolen Server Memory'

	UNION ALL

	SELECT
		  'Reserved'
		, 'Reserved Server Memory'

	UNION ALL

	SELECT
		  'Foreign'
		, 'Foreign Node Memory') M ON M.OldName = PC.counter_name
			AND NewName NOT IN (
				SELECT counter_name
				FROM #PerformaceValue
				WHERE object_name = 'Memory Manager'
				)
	WHERE object_name IN ('Buffer Manager', 'Buffer Node');

	-- Build Memory Tree
	IF OBJECT_ID('tempdb..#MemoryPressure') IS NOT NULL
		DROP TABLE #MemoryPressure;
	CREATE TABLE #MemoryPressure (
		  Id INT
		, ParentId INT
		, counter_name NVARCHAR(128)
		, formatted_value NUMERIC(20, 2)
		, shortname NVARCHAR(20)
		);

	-- Level 5
	INSERT #MemoryPressure (Id, ParentId, counter_name, formatted_value, shortname)
	SELECT
		  Id = 1226
		, ParentId = 1225
		, instance_name AS counter_name
		, formatted_value
		, shortname
	FROM #PerformaceValue
	WHERE object_name = 'Plan Cache'
		AND counter_name IN ('Cache')
		AND instance_name <> '_Total';

	-- Level 4
	INSERT #MemoryPressure (Id, ParentId, counter_name, formatted_value, shortname)
	SELECT
		  Id = 1225
		, ParentId = 1220
		, 'Plan ' + counter_name AS counter_name
		, formatted_value
		, shortname
		
	FROM #PerformaceValue	-- SELECT * FROM #MemoryPressure
	WHERE object_name = 'Plan Cache'
		AND counter_name IN ('Cache')
		AND instance_name = '_Total'

	UNION ALL

	SELECT
		  Id = 1222
		, ParentId = 1220
		, counter_name
		, formatted_value
		, shortname
	FROM #PerformaceValue
	WHERE object_name = 'Cursor'
		OR (object_name = 'Memory Manager'
		AND shortname IN ('Connection', 'Lock', 'Optimizer', 'SQL')
		)

	UNION ALL

	SELECT
		  Id = 1112
		, ParentId = 1110
		, counter_name
		, formatted_value
		, shortname
		
	FROM #PerformaceValue
	WHERE object_name = 'Memory Manager'
		AND shortname IN ('Reserved')

	UNION ALL

	SELECT
		  Id = P.ParentID + 1
		, ParentID = P.ParentID
		, 'Used Workspace Memory' AS counter_name
		, SUM(used_memory_kb) / 1024. AS formatted_value
		, NULL AS shortname
	FROM sys.dm_exec_query_resource_semaphores
		CROSS JOIN (
			SELECT 1220 AS ParentID

			UNION ALL

			SELECT 1110
			) P
	GROUP BY P.ParentID;

	-- Level 3
	INSERT #MemoryPressure (Id, ParentId, counter_name, formatted_value, shortname)
	SELECT
		Id =
		CASE counter_name
			WHEN 'Granted Workspace Memory' THEN 1110
			WHEN 'Stolen Server Memory' THEN 1220
			ELSE 1210
		END
		, ParentId =
			CASE counter_name
				WHEN 'Granted Workspace Memory' THEN 1100 ELSE 1200
			END
		, counter_name
		, formatted_value
		, shortname
		
	FROM #PerformaceValue
	WHERE object_name = 'Memory Manager'
		AND counter_name IN ('Stolen Server Memory', 'Database Cache Memory', 'Free Memory', 'Granted Workspace Memory');

	-- Level 2
	INSERT #MemoryPressure (Id, ParentId, counter_name, formatted_value, shortname)
	SELECT
		Id =
			CASE
				WHEN counter_name = 'Maximum Workspace Memory' THEN 1100 ELSE 1200
			END
		, ParentId = 1000
		, counter_name
		, formatted_value
		, shortname
		
	FROM #PerformaceValue
	WHERE object_name = 'Memory Manager'
		AND counter_name IN ('Total Server Memory', 'Maximum Workspace Memory');

	-- Level 1
	INSERT #MemoryPressure (Id, ParentId, counter_name, formatted_value, shortname)
	SELECT
			  Id = 1000
			, ParentId = NULL
			, counter_name
			, formatted_value
			, shortname
			
	FROM #PerformaceValue
	WHERE object_name = 'Memory Manager' AND counter_name IN ('Target Server Memory');

	-- Level 4 -- 'Other Stolen Server Memory' = 'Stolen Server Memory' - SUM(Children of 'Stolen Server Memory')
	INSERT #MemoryPressure (Id, ParentId, counter_name, formatted_value, shortname)
	SELECT
		  Id = 1222
		, ParentId = 1220
		, counter_name = '<Other Memory Clerks>'
		, formatted_value = (
			SELECT SSM.formatted_value
			FROM #MemoryPressure SSM
			WHERE Id = 1220
			) - SUM(formatted_value)
		, shortname = 'Other Stolen'
		
	FROM #MemoryPressure
	WHERE ParentId = 1220;

	INSERT INTO USAGE.dbo.MemoryPressure
	SELECT ID, counter_name AS [Counter Name], formatted_value AS [Value (MB)], @ExecutionTime
	FROM #MemoryPressure
	WHERE counter_name IN (
		  'Target Server Memory'
		, 'Maximum Workspace Memory'
		, 'Total Server Memory'
		, 'Database Cache Memory'
		, 'Free Memory'
		, 'Stolen Server Memory'
		, '<Other Memory Clerks>'
		, 'SQL Cache Memory'
		, 'Lock Memory'
		, 'Connection Memory'
		, 'Cursor memory usage'
		, 'SQL Plans'
		, 'Object Plans'
		, 'Bound Trees'
		, 'Extended Stored Procedures'
		, 'Temporary Tables & Table Variables'
		)

	/*

	SELECT * FROM USAGE.dbo.MemoryPressure
	ORDER BY Value DESC;

	*/


	/*
		| Step 2
		| Create Step intern Job for execution every 1 min.
	*/
	/*
	DECLARE @dExecutionDate DATETIME = GETDATE()
	IF EXISTS (
	SELECT * FROM USAGE.dbo.MemoryAllocation
	WHERE ([PhysicalMemoryLow] <> 0 OR [VirtualMemoryLow] <> 0)
		AND EventTime > DATEADD(mm, -1, @dExecutionDate)
		)
		BEGIN
			EXEC dbo.sp_BlitzMemoryPressure
		END
	*/

	/*
		| Step 3
		| Prove existent Step in procedure BlitzHealthCheck
	*/
