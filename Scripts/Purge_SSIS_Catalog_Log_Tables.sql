/*
	Script name: Purge SSIS Catalog log tables
	Author: Tim Mitchell (www.TimMitchell.net)
	Date: 12/19/2018

	Purpose: This script will remove most of the operational information from the SSIS catalog. The 
				internal.operations and internal.executions tables, as well as their dependencies, 
				will be purged of all data with an operation created_time value older than the number
				of days specified in the RETENTION_WINDOW setting of the SSIS catalog.
				
		Note that this script was created using SQL Server 2017 (14.0.3048.4). Depending on the SQL Server
				version, the table and/or column names may be different.

  How to use this script
  To use this script, I recommend that you create a separate user-defined stored procedure in the SSISDB database. 
  Although you could simply replace the code in the internal.cleanup_server_retention_window stored procedure, 
  it is a best practice to avoid modifying any of the existing DDL in the SSISDB database. 
  It is much safer to create your own stored procedure for this, preferably in a new schema that you also create to build 
  some logical and functional separation from the built-in SSIS catalog objects. 
  You can then create your own SQL Server Agent job that executes this stored procedure.
  https://www.timmitchell.net/post/2018/12/30/clean-up-the-ssis-catalog/
*/

SET NOCOUNT ON

DECLARE @enable_purge BIT 
DECLARE @retention_period_days SMALLINT

/*
	Query the SSIS catalog database for the retention settings
*/

SELECT @enable_purge = CONVERT(bit, property_value) 
FROM [catalog].[catalog_properties]
WHERE property_name = 'OPERATION_CLEANUP_ENABLED'
        
SELECT @retention_period_days = CONVERT(int, property_value)  
FROM [catalog].[catalog_properties]
WHERE property_name = 'RETENTION_WINDOW'

/*
	If purge is disabled or the retention period is not greater than 0, skip the remaining tasks
  by turning on NOEXEC.
*/

IF NOT (@enable_purge = 1 AND @retention_period_days > 0)
  SET NOEXEC ON 

/*
	Get the working list of execution IDs. This will be the list of IDs we use for the
	delete operation for each table.
*/
IF (OBJECT_ID('tempdb..#executions') IS NOT NULL)
	DROP TABLE #executions

SELECT execution_id
INTO #executions
FROM catalog.executions 
WHERE CAST(created_time AS DATETIME) < DATEADD(DAY, 0 - @retention_period_days, GETDATE())

/***************************************************
	internal.executions and its dependencies
***************************************************/

DELETE tgt
FROM internal.event_message_context tgt
INNER JOIN internal.event_messages em
	ON em.event_message_id = tgt.event_message_id
INNER JOIN #executions ee
	ON ee.execution_id = em.operation_id

RAISERROR ('Deleted data from internal.event_message_context', 10, 1) WITH NOWAIT

GO

/*
	internal.event_messages
*/
DELETE tgt
FROM internal.event_messages tgt
INNER JOIN #executions ee
	ON ee.execution_id = tgt.operation_id

RAISERROR ('Deleted data from internal.event_messages', 10, 1) WITH NOWAIT

GO

/*
	internal.executable_statistics
*/
DELETE tgt
FROM internal.executable_statistics tgt
INNER JOIN #executions ee
	ON ee.execution_id = tgt.execution_id

RAISERROR ('Deleted data from internal.executable_statistics', 10, 1) WITH NOWAIT

GO

/*
	internal.execution_data_statistics is one of the larger tables. Break up the delete to avoid
	log size explosion.
*/

SET ROWCOUNT 1000000

DECLARE @rows INT = 1

WHILE @rows > 0
BEGIN
	DELETE tgt
	FROM internal.execution_data_statistics tgt
	INNER JOIN #executions ee
		ON ee.execution_id = tgt.execution_id

	SET @rows = @@ROWCOUNT
END

SET ROWCOUNT 0

RAISERROR ('Deleted data from internal.execution_data_statistics', 10, 1) WITH NOWAIT

GO

/*
	internal.execution_component_phases is one of the larger tables. Break up the delete to avoid
	log size explosion.
*/

SET ROWCOUNT 1000000

DECLARE @rows INT = 1

WHILE @rows > 0
BEGIN

	DELETE tgt 
	FROM internal.execution_component_phases tgt
	INNER JOIN #executions ee
		ON ee.execution_id = tgt.execution_id

	SET @rows = @@ROWCOUNT
END

SET ROWCOUNT 0

RAISERROR ('Deleted data from internal.execution_component_phases', 10, 1) WITH NOWAIT

GO

/*
	internal.execution_data_taps
*/
DELETE tgt
FROM internal.execution_data_taps tgt
INNER JOIN #executions ee
	ON ee.execution_id = tgt.execution_id

RAISERROR ('Deleted data from internal.execution_data_taps', 10, 1) WITH NOWAIT

GO

/*
	internal.execution_parameter_values is one of the larger tables. Break up the delete to avoid
	log size explosion.
*/

SET ROWCOUNT 1000000

DECLARE @rows INT = 1

WHILE @rows > 0
BEGIN
	DELETE tgt
	FROM internal.execution_parameter_values tgt
	INNER JOIN #executions ee
		ON ee.execution_id = tgt.execution_id
	SET @rows = @@ROWCOUNT
END

SET ROWCOUNT 0

RAISERROR ('Deleted data from internal.execution_parameter_values', 10, 1) WITH NOWAIT

GO

/*
	internal.execution_property_override_values
*/
DELETE tgt
FROM internal.execution_property_override_values tgt
INNER JOIN #executions ee
	ON ee.execution_id = tgt.execution_id

RAISERROR ('Deleted data from internal.execution_property_override_values', 10, 1) WITH NOWAIT

GO

/*
	internal.executions
*/
DELETE tgt
FROM internal.executions tgt
INNER JOIN #executions ee
	ON ee.execution_id = tgt.execution_id

RAISERROR ('Deleted data from internal.executions', 10, 1) WITH NOWAIT

GO

/***************************************************
	internal.operations and its dependencies
***************************************************/

/*
	internal.operation_messages
*/
DELETE tgt
FROM internal.operation_messages tgt
INNER JOIN #executions ee
	ON ee.execution_id = tgt.operation_id

RAISERROR ('Deleted data from internal.operation_messages', 10, 1) WITH NOWAIT

GO

/*
	internal.extended_operation_info
*/
DELETE tgt
FROM internal.extended_operation_info tgt
INNER JOIN #executions ee
	ON ee.execution_id = tgt.operation_id

RAISERROR ('Deleted data from internal.extended_operation_info', 10, 1) WITH NOWAIT

GO

/*
	internal.operation_os_sys_info
*/
DELETE tgt
FROM internal.operation_os_sys_info tgt
INNER JOIN #executions ee
	ON ee.execution_id = tgt.operation_id

RAISERROR ('Deleted data from internal.operation_os_sys_info', 10, 1) WITH NOWAIT

GO

/*
	internal.validations
*/
DELETE tgt
FROM internal.validations tgt
INNER JOIN #executions ee
	ON ee.execution_id = tgt.validation_id

RAISERROR ('Deleted data from internal.validations', 10, 1) WITH NOWAIT

GO
	
/*
	internal.operation_permissions
*/
DELETE tgt
FROM internal.operation_permissions tgt
INNER JOIN #executions ee
	ON ee.execution_id = tgt.[object_id]

RAISERROR ('Deleted data from internal.operation_permissions', 10, 1) WITH NOWAIT

GO
	
/*
	internal.operations
*/
DELETE tgt
FROM internal.operations tgt
INNER JOIN #executions ee
	ON ee.execution_id = tgt.operation_id
	AND tgt.start_time IS NOT NULL
 
RAISERROR ('Deleted data from internal.operations', 10, 1) WITH NOWAIT

GO

SET NOEXEC OFF 

GO
