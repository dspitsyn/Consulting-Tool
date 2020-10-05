/*
	| Use this T-SQL script to generate the complete list of tables that need statistics update in a given database
*/
;WITH StatTables AS	(
	SELECT so.schema_id AS 'schema_id', so.name AS 'TableName', so.object_id AS 'object_id', ISNULL(sp.rows,0) AS 'ApproximateRows', ISNULL(sp.modification_counter,0) AS 'RowModCtr'
    FROM sys.objects so (NOLOCK) JOIN sys.stats st (NOLOCK) ON so.object_id=st.object_id
		CROSS APPLY sys.dm_db_stats_properties(so.object_id, st.stats_id) AS sp
    WHERE so.is_ms_shipped = 0 AND st.stats_id<>0
		AND so.object_id NOT IN (SELECT major_id FROM sys.extended_properties (NOLOCK) WHERE name = N'microsoft_database_tools_support')
	)
	, StatTableGrouped AS	(
		SELECT ROW_NUMBER() OVER(ORDER BY TableName) AS seq1
			, ROW_NUMBER() OVER(ORDER BY TableName DESC) AS seq2
			, TableName
			, CAST(MAX(ApproximateRows) AS BIGINT) AS ApproximateRows
			, CAST(MAX(RowModCtr) AS BIGINT) AS RowModCtr, COUNT(*) AS StatCount, schema_id, object_id
		FROM StatTables st
		GROUP BY schema_id,object_id,TableName
		HAVING (MAX(ApproximateRows) > 500 AND MAX(RowModCtr) > (MAX(ApproximateRows)*0.2 + 500 ))
		)
SELECT DB_NAME(DB_ID()) AS db_name
	, seq1 + seq2 - 1 AS no_of_occurences
	, SCHEMA_NAME(stg.schema_id) AS 'schema'
	, stg.TableName AS 'table'
	, CASE OBJECTPROPERTY(stg.object_id, 'TableHasClustIndex')
		WHEN 1 THEN 'Clustered'
        WHEN 0 THEN 'Heap'
        ELSE 'Indexed View'
        END AS clustered_heap
	, CASE objectproperty(stg.object_id, 'TableHasClustIndex')
		WHEN 0 THEN (SELECT COUNT(*) FROM sys.indexes i (NOLOCK) WHERE i.object_id = stg.object_id) - 1
		ELSE (SELECT COUNT(*) FROM sys.indexes i (NOLOCK) WHERE i.object_id = stg.object_id) END AS index_count
	, (SELECT COUNT(*) FROM sys.columns c (NOLOCK) WHERE c.object_id = stg.object_id ) AS column_count
	, stg.StatCount
	, stg.ApproximateRows
	, stg.RowModCtr
	, stg.schema_id
	, stg.object_id
FROM StatTableGrouped stg
