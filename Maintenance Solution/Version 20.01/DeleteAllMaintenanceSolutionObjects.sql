/*
	| Delete existing Managed Service Operator(s)
*/
IF EXISTS ( SELECT name FROM msdb.dbo.sysoperators WHERE name LIKE N'%INA%' )
	BEGIN
		EXEC msdb.dbo.sp_delete_operator @name = N'INA.MASRV'
		PRINT 'Backup-Operator was successfully deleted.'
	END

/*
	| Delete existing version (Maintenance Solution)
*/

IF OBJECT_ID(N'[msdb].[dbo].[CommandLog]', N'U') IS NOT NULL
BEGIN
	DROP TABLE [dbo].[CommandLog]
END
IF OBJECT_ID(N'[msdb].[dbo].[QueueDatabase]', N'U') IS NOT NULL
BEGIN
	DROP TABLE [dbo].[QueueDatabase]
END
IF OBJECT_ID(N'[msdb].[dbo].[Queue]', N'U') IS NOT NULL
BEGIN
	DROP TABLE [dbo].[Queue]
END
IF EXISTS ( SELECT * FROM sys.objects WHERE type = 'P' AND name = 'CommandExecute' )
BEGIN
	DROP PROCEDURE CommandExecute
END
IF EXISTS ( SELECT * FROM sys.objects WHERE type = 'P' AND name = 'DatabaseBackup' )
BEGIN
	DROP PROCEDURE DatabaseBackup
END
IF EXISTS ( SELECT * FROM sys.objects WHERE type = 'P' AND name = 'DatabaseIntegrityCheck' )
BEGIN
	DROP PROCEDURE DatabaseIntegrityCheck
END
IF EXISTS ( SELECT * FROM sys.objects WHERE type = 'P' AND name = 'IndexOptimize' )
BEGIN
	DROP PROCEDURE IndexOptimize
END
/*
	| End delete existing version (Maintenance Solution)
*/

/*
	| Changes the attributes of a jobs
*/
/*
IF (@jobId IS NOT NULL)
	BEGIN
		EXEC msdb.dbo.sp_delete_job @jobId
	END
*/
IF EXISTS ( SELECT name FROM msdb.dbo.sysjobs WHERE name = N'RCN_BACKUP_SYSTEM_DATABASES' )
	BEGIN
		EXEC msdb.dbo.sp_delete_job @job_name = N'RCN_BACKUP_SYSTEM_DATABASES'
	END
IF EXISTS ( SELECT name FROM msdb.dbo.sysjobs WHERE name = N'RCN_BACKUP_USER_DATABASES_FULL' )
	BEGIN
		EXEC msdb.dbo.sp_delete_job @job_name = N'RCN_BACKUP_USER_DATABASES_FULL'
	END
IF EXISTS ( SELECT name FROM msdb.dbo.sysjobs WHERE name = N'RCN_BACKUP_USER_DATABASES_LOG' )
	BEGIN
		EXEC msdb.dbo.sp_delete_job @job_name = N'RCN_BACKUP_USER_DATABASES_LOG'
	END
IF EXISTS ( SELECT name FROM msdb.dbo.sysjobs WHERE name = N'RCN_CYCLE_LOG' )
	BEGIN
		EXEC msdb.dbo.sp_delete_job @job_name = N'RCN_CYCLE_LOG'
	END
IF EXISTS ( SELECT name FROM msdb.dbo.sysjobs WHERE name = N'RCN_MAINTENANCE_ALL_DATABASES' )
	BEGIN
		EXEC msdb.dbo.sp_delete_job @job_name = N'RCN_MAINTENANCE_ALL_DATABASES'
	END
IF EXISTS ( SELECT name FROM msdb.dbo.sysjobs WHERE name = N'RCN_STOP_EXECUTION_RCN_JOBS' )
	BEGIN
		EXEC msdb.dbo.sp_delete_job @job_name = N'RCN_STOP_EXECUTION_RCN_JOBS'
	END
/*
	| End changes the attributes
*/
