/*
	| File:     Maintenance_Jobs.sql
	| Version:  2001.122003 - January, 2020

	| Summary:  	
	| This script will create maintenance job incl. standard steps (State: 26 January 2020) which can be used in any environment
	| Before execution, please execute the following script: 
	| https://github.com/dspitsyn/Consulting-Tool/blob/master/Maintenance%20Solution/Version%2020.01/MaintenanceSolution.V.2001.sql
	| Any updates will be included in next release.

	| Configure and schedule regular maintenance for all of the following:
	| • Full (and possibly differential) backups
	| • Log backups (for databases in Full recovery model)
	| • CheckDB
	| • Index maintenance
	| Don't forget that your system databases need backup and CheckDB also!
	| Options for seting up maintenance:
	| A. Use free scripts from Ola Hallengren to create customized SQL Server Agent Jobs: htp://ola.hallengren.com/
	| B. Use SQL Server Maintenance Plans if you'd like a graphical user interface, but just keep in mind that they're not as flexible and powerful as Ola's scripts. 
	| For example, they take a shotgun approach to index maintenance – they'll rebuild all of the indexes, every time, whether there's any fragmentation or not. 

	| Version Updates:
		02.03.2020 | Added by Dmitry Spitsyn
			# Insert Step: CLEANUP_OUTPUT_AUDITFILES
		20.01.2020 | Added by Dmitry Spitsyn
			# Delete all PowerShell related variables
		11.01.2020 | Added by Dmitry Spitsyn
			# Supportability regarding SQL collation for SharePoint Databases and TempDB
		30.12.2019 | Added by Dmitry Spitsyn
			# Change existing modules and insert needed parameters for Database Mail account, Prefix for Environment
		13.11.2019 | Added by Dmitry Spitsyn
			# Change existing modules and aproved number of Solution Version
		30.04.2019 | Added by Dmitry Spitsyn
			# Extend check existing modules and prove number of Solution Version
			# Step created to exclude a situation where a database backup would fail, for example due to a network error - specifically "Operating system error 59(An unexpected network error occurred.)"
			# The solution identify only those database backups that failed and retry back them up again.
			# Extend and sort all backup jobs parameters
			# Specify extended parameters for full backups
			# Remove unused variable and all assignments
		04.03.2019 | Added by Dmitry Spitsyn
			# Optimize check existing modules
		  	# Changes in output file for delete short file names
			# Specify MaxDOP value
			# Specify the database order for user databases
			# Include copy-only option, which does not affect the normal sequence of backups
			# Changes in create / delete routine
			# Specify the full backup databases process in parallel
			# Specify extended parameters for full backups
		28.11.2018 | Added by Dmitry Spitsyn
			# Determine Collation setting for SharePoint instances
			# Extend parameter TimeLimit for SharePoint and none SharePoint instances
			# Extend fragmentation level, methods and execution time for SharePoint instances
			# Extend Integritet check for none SharePoint instaces
			# Cleanup parameters for Backup jobs
		11.11.2018 | Added by Dmitry Spitsyn following parameters
			# Set parameter LockTimeout in step: OPTIMIZE_INDEX_USER_DATABASES to 300 seconds
			# Set parameter StatisticsModificationLevel in step OPTIMIZE_INDEX_USER_DATABASES to 5 percent
			# Delete parameter OnlyModifiedStatistics
			# Optimize random time for job execution
			# Set OutputFileIndexOptimize only for USER databases.
			# Include parameters @retry_attempts (2) and @retry_interval (10) in step: OPTIMIZE_INDEX_USER_DATABASES | none SharePoint Instances
		01.09.2018 | Added by Dmitry Spitsyn following steps and parameters
			# Change Backup-Operator to CCMS-Operator (Managed Service)
			# Naming conventions and general rules for Maintenance Solution in BDC (Purpose: adding clarity and uniformity to scripts and functionality)
			# Create Step: ST01: CHECK_INTEGRITY_ALL_DATABASES
			# Create Step: ST02: OPTIMIZE_INDEX_ALL_DATABASES
			# Create Step: ST03: OPTIMIZE_INDEX_MSDB
			# Create Step: ST04: CLEANUP_BACKUP_HISTORY
			# Create Step: ST05: CLEANUP_TABLE_COMMANDLOG
			# Create Step: ST06: CLEANUP_JOBS_HISTORY
			# Create Step: ST07: CLEANUP_MESSAGES
			# Create Step: ST08: CLEANUP_OUTPUT_FILE
			# Create Step: ST09: CHECK_STEPS_ERRORS
			# Create Job: STOP_EXECUTION_MAINTENANCE_JOBS
			# Integration Backup Jobs	
			# Extended event for DeleteMaintenanceSolution
			# Check for existing Solution Version and modules
			# Extended comments
			# Specify dynamically backup directory
			# Specify parameters for all steps
			# Generate random values for execution time
			# Error message for agent job step failure

	SQL Server Version: 2008R2/2012/2014/2016/2017/2019
*/

USE [msdb]

/*
	| Added by Dmitry Spitsyn 01.09.2018
	| Generate random values for execution time, starting from 18:00  (CEST)
	| Defined time format
*/
DECLARE @JobExecutionTime NVARCHAR(MAX) = DATEADD(SECOND, RAND(CAST(NEWID() AS VARBINARY)) * 21600, CAST('18:00:00' AS TIME))
DECLARE @MsgExecutionTime NVARCHAR(MAX) = LEFT(@JobExecutionTime, LEN(@JobExecutionTime) - 8) + ' PM';

DECLARE @OutputFileDirectory NVARCHAR(MAX)
DECLARE @LogToTable NVARCHAR(MAX)
DECLARE @DatabaseName NVARCHAR(MAX)
DECLARE @Version NUMERIC(18,10)
DECLARE @TokenServer NVARCHAR(MAX)
DECLARE @TokenJobID NVARCHAR(MAX)
DECLARE @TokenStepID NVARCHAR(MAX)
DECLARE @TokenDate NVARCHAR(MAX)
DECLARE @TokenTime NVARCHAR(MAX)
DECLARE @JobDescription NVARCHAR(MAX)
DECLARE @JobDescriptionStopExecution NVARCHAR(MAX)
DECLARE @JobDescriptionCyclingErrorLog NVARCHAR(MAX)
DECLARE @MsgNoSchedule NVARCHAR(MAX)
DECLARE @JobCategory NVARCHAR(MAX)
DECLARE @JobOwner NVARCHAR(MAX)
DECLARE @JobNameMaintenanceSolution NVARCHAR(MAX)
DECLARE @JobNameOldCyclingErrorLog VARCHAR(MAX)
DECLARE @JobNameCyclingErrorLog NVARCHAR(MAX)
DECLARE @ServiceAccount NVARCHAR(MAX)
DECLARE @JobNameStopExecution NVARCHAR(MAX)
DECLARE @JobNameBackupSystem NVARCHAR(MAX)
DECLARE @JobNameBackupUser NVARCHAR(MAX)
DECLARE @JobNameBackupUserLog NVARCHAR(MAX)
DECLARE @JobCommandIntegrityCheck NVARCHAR(MAX)
DECLARE @JobCommandIndexOptimize NVARCHAR(MAX)
DECLARE @JobCommandSPSIndexOptimize NVARCHAR(MAX)
DECLARE @JobCommandMSDBIndexOptimize NVARCHAR(MAX)
DECLARE @JobCommandCleanupTableCommandLog NVARCHAR(MAX)
DECLARE @JobCommandPurgeHistory NVARCHAR(MAX)
DECLARE @JobCommandCleanUpJobsHistory NVARCHAR(MAX)
DECLARE @JobCommandCleanUpMessages NVARCHAR(MAX)
DECLARE @JobCommandOutputTFileCleanUp NVARCHAR(MAX)
DECLARE @JobCommandOutputAFileCleanUp NVARCHAR(MAX)
DECLARE @JobCommandCheckStepsErrors NVARCHAR(MAX)
DECLARE @JobCommandStopExecution NVARCHAR(MAX)
DECLARE @JobCommandCyclingErrorLog NVARCHAR(MAX)
DECLARE @JobCommandBackupSystem NVARCHAR(MAX)
DECLARE @JobCommandBackupUser NVARCHAR(MAX)
DECLARE @JobCommandFailedBackups NVARCHAR(MAX)
DECLARE @JobCommandFailedLogBackups NVARCHAR(MAX)
DECLARE @JobCommandBackupUserLog NVARCHAR(MAX)
DECLARE @JobStepIntegrityCheck NVARCHAR(MAX)
DECLARE @JobStepIndexOptimize NVARCHAR(MAX)
DECLARE @JobStepMSDBIndexOptimize NVARCHAR(MAX)
DECLARE @JobStepCleanupCommandLog NVARCHAR(MAX)
DECLARE @JobStepPurgeHistory NVARCHAR(MAX)
DECLARE @JobStepCleanUpJobsHistory NVARCHAR(MAX)
DECLARE @JobStepCleanMessages NVARCHAR(MAX)
DECLARE @JobStepOutputTFileCleanUp NVARCHAR(MAX)
DECLARE @JobStepOutputAFileCleanUp NVARCHAR(MAX)
DECLARE @JobStepCheckStepsErrors NVARCHAR(MAX)
DECLARE @JobStepStopExecution NVARCHAR(MAX)
DECLARE @JobStepCyclingErrorLog NVARCHAR(MAX)
DECLARE @JobStepBackupSystem NVARCHAR(MAX)
DECLARE @JobStepBackupUser NVARCHAR(MAX)
DECLARE @JobStepBackupUserLog NVARCHAR(MAX)
DECLARE @OutputFileIntegrityCheck NVARCHAR(MAX)
DECLARE @OutputFileIndexOptimize NVARCHAR(MAX)
DECLARE @OutputFileMSDBIndexOptimize NVARCHAR(MAX)
DECLARE @OutputFileCleanupCommandLog NVARCHAR(MAX)
DECLARE @OutputFilePurgeHistory NVARCHAR(MAX)
DECLARE @OutputFileCleanUpJobsHistory NVARCHAR(MAX)
DECLARE @OutputFileCleanUpEMessages NVARCHAR(MAX)
DECLARE @OutputFileOutputTFileCleanUp NVARCHAR(MAX)
DECLARE @OutputFileOutputAFileCleanUp NVARCHAR(MAX)
DECLARE @OutputFileCheckStepsErrors NVARCHAR(MAX)
DECLARE @OutputFileStopExecution NVARCHAR(MAX)
DECLARE @OutputFileBackupSystem NVARCHAR(MAX)
DECLARE @OutputFileBackupUser NVARCHAR(MAX)
DECLARE @OutputFileFailedBackups NVARCHAR(MAX)
DECLARE @OutputFileFailedLogBackups NVARCHAR(MAX)
DECLARE @OutputFileBackupUserLog NVARCHAR(MAX)
DECLARE @OutputFileCyclingErrorLog NVARCHAR(MAX)
DECLARE @JobNameOla NVARCHAR(MAX)
DECLARE @JobScheduleID INT
DECLARE @JobScheduleName NVARCHAR(MAX)
DECLARE @JobCommand NVARCHAR(MAX)
DECLARE @BackupDirectory NVARCHAR(MAX)
DECLARE @OutputFile NVARCHAR(MAX)
DECLARE @TokenLogDirectory NVARCHAR(MAX)
DECLARE @OnlyModifiedStatistics NVARCHAR(MAX)
DECLARE @MSOperator NVARCHAR(MAX)
DECLARE @aMessage NVARCHAR(MAX)
DECLARE @Error INT = 0
DECLARE @Flag INT = 0
DECLARE @ROOTKEY NVARCHAR(20)
DECLARE @ErrorMessage NVARCHAR(MAX)
DECLARE @EnvironmentPrefix NVARCHAR(4) = 'RCN_'

DECLARE @Size NCHAR(1) = 0		--# Parameter 1 $(Size)
DECLARE @Schedule NCHAR(2) = 0	--# Parameter 2 $(Schedule)
DECLARE @ScheduleTime NCHAR(6)	--# Parameter 3 $(ScheduleTime)

/*
	| Added by Dmitry Spitsyn 01.09.2018
	| Please check and confirm these values
*/
DECLARE @LockTimeout INT	= 60 		-- used to limit waiting for Locks (seconds)
DECLARE @TimeLimit INT		= 3600		-- used to limit time spent in Index Maintenance (in Seconds, 3600 = 1 hour; 7200 = 2 hours; 10800 = three hours)
DECLARE @CreateBackupJobs BIT = 0		-- change this value to 1 if you need the backup routines (System databases | Full; User Databases | Full and Log)
DECLARE @DeleteMaintenanceSolution BIT = 0	-- change this value to 1 if you need to delete all existing Maintenance Jobs
/*
	SET @BackupDirectory = 'F:\Backup_00\Backup'	-- used to specify backup root directories, which can be local directories or network shares. 
	If needs to specify multiple directories, then the backup files are striped evenly across the directories. 
	Specify multiple directories by using the comma (,). 
	If no directory is specified, then the SQL Server default backup directory will be used.
*/

DECLARE @ManageMailProfileAccount BIT = 0	-- Set this value to 1 to create a new Database Mail account holding information about an SMTP account.

/*
	| All parameters see below must be precisely prooved when input value @ManageMailProfileAccount changed
	| Variables for Database Mail account and information regarding SMTP account
*/

DECLARE @SetProfileName NVARCHAR(MAX) = '<ProfileName>'		--'@ProfileName'
DECLARE @SetAccountName SYSNAME = '<AccountName>'		--'@AccountName'
DECLARE @SetEmailAddress NVARCHAR(128) = '<betriebspost.aus@domainname.de>'
DECLARE @SetReplyToAddress NVARCHAR(128) = '<support@domainname.de>'
DECLARE @SetMailServerName NVARCHAR(MAX) = '<mail.domainname.de>'
DECLARE @SetDisplayName NVARCHAR(128) = @@SERVERNAME + ' - Central SQL Report'

/*
If for some reason, execution of the code returns an error, use the following code to roll back the changes:

EXECUTE msdb.dbo.sysmail_delete_profileaccount_sp @profile_name = @SetProfileName
EXECUTE msdb.dbo.sysmail_delete_principalprofile_sp @profile_name = @SetProfileName
EXECUTE msdb.dbo.sysmail_delete_account_sp @account_name = @SetAccountName
EXECUTE msdb.dbo.sysmail_delete_profile_sp @profile_name = @SetProfileName
*/

SET @LogToTable = 'Y'

SET @Version = CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(MAX)), CHARINDEX('.', CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(MAX))) - 1) + '.' + REPLACE(RIGHT(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(MAX)), LEN(CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(MAX))) - CHARINDEX('.', CAST(SERVERPROPERTY('ProductVersion') AS NVARCHAR(MAX)))), '.', '') AS NUMERIC(18,10))
IF ( SELECT CONVERT(VARCHAR, SERVERPROPERTY('Collation')) ) LIKE 'Latin1_General_CI_AS_KS_WS'
	BEGIN
		SET @JobDescription = 'Maintenance Solution for Sharepoint' + CHAR(13) + CHAR(10) + 'Version: 2001' + CHAR(13) + CHAR(10)
		SET @TimeLimit = @TimeLimit + 3600
	END
ELSE
	BEGIN
		SET @JobDescription = 'Maintenance Solution' + CHAR(13) + CHAR(10) + 'Version: 2001' + CHAR(13) + CHAR(10)
	END

IF @Version >= 9.002047
	BEGIN
		SET @TokenServer	= '$' + '(ESCAPE_SQUOTE(SRVR))'
		SET @TokenJobID 	= '$' + '(ESCAPE_SQUOTE(JOBID))'
		SET @TokenStepID 	= '$' + '(ESCAPE_SQUOTE(STEPID))'
		SET @TokenDate 		= '$' + '(ESCAPE_SQUOTE(STRTDT))'
		SET @TokenTime 		= '$' + '(ESCAPE_SQUOTE(STRTTM))'
	END
ELSE
	BEGIN
		SET @TokenServer 	= '$' + '(SRVR)'
		SET @TokenJobID 	= '$' + '(JOBID)'
		SET @TokenStepID 	= '$' + '(STEPID)'
		SET @TokenDate 		= '$' + '(STRTDT)'
		SET @TokenTime 		= '$' + '(STRTTM)'
	END

IF @Version >= 12
BEGIN
	SET @TokenLogDirectory 	= '$' + '(ESCAPE_SQUOTE(SQLLOGDIR))'
END

SET @OutputFileDirectory = LEFT(CAST(SERVERPROPERTY('ErrorLogFileName') AS NVARCHAR(MAX)), LEN(CAST(SERVERPROPERTY('ErrorLogFileName') AS NVARCHAR(MAX))) - CHARINDEX('\', REVERSE(CAST(SERVERPROPERTY('ErrorLogFileName') AS NVARCHAR(MAX)))))
SET @LogToTable 	= 'Y'
SET @DatabaseName 	= 'msdb'
SET @JobCategory 	= 'Database Maintenance'
SET @JobOwner 		= SUSER_SNAME(0x01)

/*
	| Execution start time changed by Dmitry Spitsyn 20.01.2020
*/
SET @ScheduleTime = REPLACE(CONVERT(VARCHAR(8), @JobExecutionTime, 108), ':', '') + '00'

/*
	| Jobs name convention | added by Dmitry Spitsyn on 01.09.2018
*/
SET @JobNameMaintenanceSolution = @EnvironmentPrefix + 'MAINTENANCE_ALL_DATABASES'
SET @JobScheduleName = 'DAILY'
SET @aMessage = 'Attention: please check executions time for maintenance job if necessary and make sure, that each time after execution this script, all already existing maintenance jobs will be removed and rebuild again.'

/*
	| Create/Update Job for Cycling the SQL Server Error Log
*/
SET @JobStepCyclingErrorLog = 'ST01: Cycling the SQL Server Error Log'
SET @JobCommandCyclingErrorLog = 'EXEC sp_cycle_errorlog;'
IF LEN(@OutputFileCyclingErrorLog) > 200 SET @OutputFileCyclingErrorLog = ''
IF LEN(@OutputFileCyclingErrorLog) > 200 SET @OutputFileCyclingErrorLog = NULL

SET @JobNameCyclingErrorLog = @EnvironmentPrefix + 'CYCLE_LOG'
SET @JobDescriptionCyclingErrorLog = N'Automatically rotating the SQL Server Error Log'
IF EXISTS ( SELECT 1 FROM msdb.dbo.sysjobs WHERE [name] LIKE '%CYCLE_LOG%' )
	BEGIN
	SET @JobNameOldCyclingErrorLog = ( SELECT name FROM msdb.dbo.sysjobs WHERE [name] LIKE '%CYCLE_LOG%' )
		EXEC dbo.sp_update_job
			  @job_name = @JobNameOldCyclingErrorLog
			, @new_name = @JobNameCyclingErrorLog
		GOTO SkipCreateCyclingErrorLog
	END
ELSE
	BEGIN
		EXEC msdb.dbo.sp_add_job 
			  @job_name = @JobNameCyclingErrorLog
			, @description = @JobDescriptionCyclingErrorLog
			, @category_name = @JobCategory
			, @owner_login_name = @JobOwner
			, @enabled = 1
			, @notify_level_eventlog = 2
		EXEC msdb.dbo.sp_add_jobstep 
			  @job_name = @JobNameCyclingErrorLog
			, @step_name = @JobStepCyclingErrorLog
			, @subsystem = 'TSQL'
			, @command = @JobCommandCyclingErrorLog
			, @output_file_name = @OutputFileCyclingErrorLog
			, @database_name = @DatabaseName
			, @on_success_action = 1
			, @on_fail_action = 2
			, @step_id = 1
		EXEC msdb.dbo.sp_add_jobserver @job_name = @JobNameCyclingErrorLog
		EXEC msdb.dbo.sp_add_jobschedule  
			  @job_name = @JobNameCyclingErrorLog
			, @name = @JobScheduleName
			, @enabled = 1
			, @freq_type = 4
			, @freq_interval = 1
			, @freq_subday_type = 1
			, @active_start_date = 20200201
			, @active_end_date = 99991231
			, @active_start_time = 60000
			, @active_end_time = 235959
			, @schedule_id = @JobScheduleID OUTPUT			
		PRINT 'Standard job ''' + @JobNameCyclingErrorLog + ''' created.'
	END
SkipCreateCyclingErrorLog:

/*	
	| Name convention for Managed Service Team as Operator | added by Dmitry Spitsyn 21.07.2018
	| Operator name will be changed in all new installations from "Backup-Operator" to
	| "xyz.MASRV" (Managed Service)
*/
/*
	| Delete existing operators

IF EXISTS ( SELECT name FROM msdb.dbo.sysoperators WHERE name LIKE N'%%' )
	BEGIN
		EXEC msdb.dbo.sp_delete_operator @name = N'Backup-Operators'
		PRINT 'Backup-Operator was successfully deleted.'
	END
*/
SET @MSOperator = N'INA.MASRV'
IF EXISTS ( SELECT name FROM msdb.dbo.sysoperators WHERE name = @MSOperator )
	BEGIN
		GOTO SkipOperator
	END
	ELSE
	BEGIN
		EXEC msdb.dbo.sp_add_operator 
			  @name = @MSOperator
			, @weekday_pager_start_time = 0
			, @weekday_pager_end_time = 235959
			, @saturday_pager_start_time = 0
			, @saturday_pager_end_time = 235959
			, @sunday_pager_start_time = 0
			, @sunday_pager_end_time = 235959
			, @pager_days = 127
			, @email_address = N'<support@domainname.de>'
			, @pager_address = N''
			, @enabled = 1
		PRINT @MSOperator + ' were successfully created.'
	END
SkipOperator:

/*
	| Create Database Mail profile
*/
IF @ManageMailProfileAccount = 1
	BEGIN
		----------------------------------------------------------------------------
		-- Begin DB Mail Setting
		----------------------------------------------------------------------------
		USE master
		EXEC sp_configure 'show advanced options', 1; 
		RECONFIGURE WITH OVERRIDE;
		EXEC sp_configure 'Database Mail XPs', 1;
		RECONFIGURE;

		/*
			| Configure a Database Mail profile with user defined name 
			| added by Dmitry Spitsyn 14.06.2019
		*/

		IF NOT EXISTS( SELECT * FROM msdb.dbo.sysmail_profile WHERE  name = @SetProfileName )
			BEGIN 
				EXEC msdb.dbo.sysmail_add_profile_sp  
					  @profile_name = @SetProfileName
					, @description = 'Profile used for sending outgoing notifications.' 
			END

		/*
			| Create a new Database Mail account holding information about an SMTP account
		*/
		IF NOT EXISTS( SELECT * FROM msdb.dbo.sysmail_account WHERE  name = @SetAccountName )
		BEGIN 
			EXEC msdb.dbo.sysmail_add_account_sp
				  @account_name = @SetAccountName		-- The name of the account to add.
				, @description = '<Application Betriebspost>'	--  Is a description for the account.
				, @email_address = @SetEmailAddress		-- The e-mail address to send the message from.
				, @display_name = @SetDisplayName		-- The display name to use on e-mail messages from this account.
				, @replyto_address = @SetReplyToAddress	-- The address that responses to messages from this account are sent to. 
				, @mailserver_name = @SetMailServerName	-- The name or IP address of the SMTP mail server to use for this account.
				, @port = 25							-- The port number for the e-mail server.  | User defined port :: 465
				, @enable_ssl = 1						-- Specifies whether Database Mail encrypts communication using Secure Sockets Layer. | 0 - not enabled / 1 - enabled
				, @username = 'elv_bpaus'				-- The user name to use to log on to the e-mail server.
				, @password = 'getpassword'				-- The password to use to log on to the e-mail server.
		END

		/*
			| Grant permission for a database user or role to use this Database Mail profile 
		*/  
		EXEC msdb.dbo.sysmail_add_principalprofile_sp  
			  @profile_name = @SetProfileName
			, @principal_name = 'public'
			, @is_default = 1 -- 0 - not default | 1 - default

		/*
			| Create a new Database Mail account holding information about an SMTP account
		*/
		/*
		EXEC msdb.dbo.sysmail_add_account_sp  
			  @account_name = @SetAccountName		-- The name of the account to add.
			, @description = 'ELVIS Betriebspost'	--  Is a description for the account.
			, @email_address = @SetEmailAddress		-- The e-mail address to send the message from.
			, @display_name = @SetDisplayName		-- The display name to use on e-mail messages from this account.
			, @replyto_address = @SetReplyToAddress	-- The address that responses to messages from this account are sent to. 
			, @mailserver_name = @SetMailServerName	-- The name or IP address of the SMTP mail server to use for this account.
			, @port = 25							-- The port number for the e-mail server.  | User defined port :: 465
			, @enable_ssl = 1						-- Specifies whether Database Mail encrypts communication using Secure Sockets Layer. | 0 - not enabled / 1 - enabled
			, @username = 'elv_bpaus'				-- The user name to use to log on to the e-mail server.
			, @password = 'getpassword'				-- The password to use to log on to the e-mail server.
		*/
		/*
			| Add the Database Mail account to the Database Mail profile 
		*/  
		EXEC msdb.dbo.sysmail_add_profileaccount_sp  
			  @profile_name = @SetProfileName
			, @account_name = @SetAccountName
			, @sequence_number = 1

		IF EXISTS (
			SELECT [sysmail_server].[account_id]
				, [sysmail_account].[name] AS [Account Name]
				, [servertype]
				, [servername] AS [SMTP Server Address]
				, [Port]
			FROM [msdb].[dbo].[sysmail_server]
				INNER JOIN [msdb].[dbo].[sysmail_account] ON [sysmail_server].[account_id] = [sysmail_account].[account_id]
			WHERE [sysmail_account].[name] = @SetAccountName
			)
		PRINT 'Database Mail with account ''' + @SetAccountName + ''' and SMTP Server ''' + @SetMailServerName + ''' successfully configured.' --+ CHAR(13) + CHAR(10) + 
		RAISERROR('Functionality must be check before used in production.', 16, 1) WITH NOWAIT

		/*
			| Task to prove Database Mail configuration
		*/

		/*
		EXEC msdb.dbo.sp_send_dbmail
			  @profile_name = @SetProfileName	--'ProfileName_Notifications'
			, @recipients = @SetAccountName		--'Use a valid e-mail address'
			, @body = 'The database mail configuration was completed successfully.'
			, @subject = 'Automated Success Message';
		GO
		*/

	END

/*
	| Added by Dmitry Spitsyn 30.04.2019
	| Specify descriptions for backup jobs if backup directory is none standard
	| Points attention for service account rights on this directory
*/
SET @MsgNoSchedule = N'This Job does not scheduled for execution by default.' 
DECLARE @JobDescriptionWithNoSchedule NVARCHAR(MAX)
SELECT @ServiceAccount = RCN.service_account
FROM sys.dm_server_services AS RCN WHERE RCN.servicename LIKE ('SQL Server (%')
IF @BackupDirectory IS NOT NULL
	BEGIN
		SET @JobDescriptionWithNoSchedule = @JobDescription + @MsgNoSchedule + CHAR(13) + CHAR(10)
		+ 'Standard directory for backup was extra specified: ''' + @BackupDirectory + '''.' + CHAR(13) + CHAR(10)
		+ 'Make sure that service account: ''' + @ServiceAccount + ''' has a full rights on this directory.' 
	END
ELSE
	BEGIN
		SET @JobDescriptionWithNoSchedule = @JobDescription + @MsgNoSchedule
	END

/*
	| Added by Dmitry Spitsyn 01.09.2018
	| Extended by Dmitry Spitsyn 28.11.2018
	| https://support.microsoft.com/de-de/help/2008668/supportability-regarding-sql-collation-for-sharepoint-databases-and-te
	| Step 01: Check Database Integrity Task to check the allocation and structural integrity of user, system tables, and indexes in the database 
	| Defined limit the number of processors to use in parallel plan execution
	| Defined time (in seconds) after which no commands are executed
	| Defined the time (in seconds) that a command waits for a lock to be released
	| Defined the integrity check, 2 parameters only for integrity checks of very large databases
	| Defined weekday for execution | limit the checks to the physical structures of the database | extended check on the weekends
*/
SET @JobStepIntegrityCheck = 'ST01: CHECK_INTEGRITY_ALL_DATABASES'
SET @JobCommandIntegrityCheck = 'SET DATEFIRST 1;' + CHAR(13) + CHAR(10)
	+ 'IF DATEPART(dw, GETDATE()) IN (1, 2, 3, 4, 5)' + CHAR(13) + CHAR(10)
	+ 'BEGIN' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'EXEC [msdb].[dbo].[DatabaseIntegrityCheck]' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ '  @Databases = ''ALL_DATABASES''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ CASE WHEN @LockTimeout > 0 THEN ', @LockTimeout = ' + CONVERT(NVARCHAR(14), @LockTimeout) ELSE '' END + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ CASE WHEN @LogToTable = 'Y' THEN ', @LogToTable = ''Y''' ELSE '' END + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ CASE WHEN (SELECT CONVERT(VARCHAR, SERVERPROPERTY('Collation'))) NOT LIKE 'Latin1_General_CI_AS_KS_WS' THEN ', @TimeLimit = 7200' ELSE ', @TimeLimit = ' + CONVERT(NVARCHAR(14), @TimeLimit) END + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @CheckCommands = ''CHECKDB''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
 	+ ', @PhysicalOnly = ''Y''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
 	+ ', @MaxDOP = 1' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @DatabaseOrder = ''REPLICA_LAST_GOOD_CHECK_ASC''' + CHAR(13) + CHAR(10)
	+ 'END' + CHAR(13) + CHAR(10)
IF ( SELECT CONVERT(VARCHAR, SERVERPROPERTY('Collation')) ) NOT LIKE 'Latin1_General_CI_AS_KS_WS'
	BEGIN
		SET @JobCommandIntegrityCheck = @JobCommandIntegrityCheck 
		+ 'ELSE' + CHAR(13) + CHAR(10)
		+ 'IF DATEPART(dw, GETDATE()) IN (6, 7)' + CHAR(13) + CHAR(10)
		+ 'BEGIN' + CHAR(13) + CHAR(10) + CHAR(9)
		+ 'EXEC [msdb].[dbo].[DatabaseIntegrityCheck]' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
		+ '  @Databases = ''ALL_DATABASES''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
		+ CASE WHEN @LockTimeout > 0 THEN ', @LockTimeout = ' + CONVERT(NVARCHAR(14), @LockTimeout) ELSE '' END + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
		+ CASE WHEN @LogToTable = 'Y' THEN ', @LogToTable = ''Y''' ELSE '' END + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
		+ ', @TimeLimit = ' + CONVERT(NVARCHAR(14), @TimeLimit) + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
		+ ', @CheckCommands = ''CHECKDB''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
 		+ ', @PhysicalOnly = ''Y''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
 		+ ', @MaxDOP = 1' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
		+ ', @DatabaseOrder = ''REPLICA_LAST_GOOD_CHECK_ASC''' + CHAR(13) + CHAR(10)
		+ 'END'
	END
SET @OutputFileIntegrityCheck = @OutputFileDirectory + '\' + 'CHECK_INTEGRITY_ALL_DATABASES_' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFileIntegrityCheck) > 200 SET @OutputFileIntegrityCheck = @OutputFileDirectory + '\' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFileIntegrityCheck) > 200 SET @OutputFileIntegrityCheck = NULL

/*
	| Added by Dmitry Spitsyn 01.09.2018
	| Extended by Dmitry Spitsyn 28.11.2018
	| Extended by Dmitry Spitsyn 30.04.2019
	| Extended by Dmitry Spitsyn 11.01.2020
	| Step 02: Reorganize or rebuild indexes depending on fragmentation level and update modified column and index statistics
	| Supportability regarding SQL collation for SharePoint Databases and TempDB
	| Defined limit (in a percent) for fragmentation level
	| Defined time (in minutes) that an online index rebuild operation will wait for low priority locks
	| Defined the time (in seconds) that a command waits for a lock to be released
	| Standard definition of fragmentation level
	| Use incremental statistics and update the statistics only if any rows have been modified
	| Set a size, in pages
*/
SET @JobStepIndexOptimize = 'ST02: OPTIMIZE_INDEX_ALL_DATABASES'
SET @JobCommandIndexOptimize = CASE WHEN (SELECT CONVERT(VARCHAR, SERVERPROPERTY('Collation'))) NOT LIKE 'Latin1_General_CI_AS_KS_WS' THEN 'SET DATEFIRST 1;' + CHAR(13) + CHAR(10)
	+ 'IF DATEPART(dw, GETDATE()) IN (1, 2, 3, 4, 5, 6, 7)' + CHAR(13) + CHAR(10)
	+ 'BEGIN' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'CREATE TABLE #SPSDB (databasename SYSNAME PRIMARY KEY CLUSTERED);' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'INSERT INTO #SPSDB (databasename)' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'EXEC sp_msforeachdb N''USE [?];' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'SELECT DISTINCT db_name()' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'FROM sys.extended_properties AS p' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'WHERE class_desc = ''''DATABASE'''' AND name = ''''isSharePointDatabase'''' AND value = 1;'';' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'DECLARE @UserDatabases NVARCHAR(MAX) = '''';' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'SELECT @UserDatabases = @UserDatabases + d.name + '', ''' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'FROM sys.databases d LEFT JOIN #SPSDB s ON (d.name = s.DatabaseName)' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'WHERE d.database_id != 2 AND s.DatabaseName IS NULL;' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'IF @UserDatabases = '''' SET @UserDatabases = ''ALL_DATABASES'';' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'ELSE SET @UserDatabases = LEFT(@UserDatabases, LEN(@UserDatabases) - 1);' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'DROP TABLE #SPSDB;' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'EXEC msdb.dbo.IndexOptimize' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ '  @Databases = @UserDatabases' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @FragmentationLow = NULL' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @FragmentationMedium = ''INDEX_REORGANIZE,INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @FragmentationHigh = ''INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @FragmentationLevel1 = 5' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @FragmentationLevel2 = 30' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @PadIndex = ''N''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @Indexes = ''ALL_INDEXES''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @UpdateStatistics = ''ALL''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @OnlyModifiedStatistics = ''N''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @StatisticsSample = 100' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @LogToTable = ''Y'';' + CHAR(13) + CHAR(10)
	+ 'END' + CHAR(13) + CHAR(10)
	ELSE
	  'SET DATEFIRST 1;' + CHAR(13) + CHAR(10)
	+ 'IF DATEPART(dw, GETDATE()) = 6' + CHAR(13) + CHAR(10)
	+ 'BEGIN' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'EXEC [msdb].[dbo].[IndexOptimize]' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ '  @Databases = ''USER_DATABASES''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @FragmentationLow = NULL' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @FragmentationMedium = ''INDEX_REORGANIZE''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @FragmentationHigh = ''INDEX_REBUILD_ONLINE,INDEX_REBUILD_OFFLINE''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @DatabaseOrder = ''DATABASE_SIZE_ASC''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @FragmentationLevel1 = 10' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @FragmentationLevel2 = 40' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @UpdateStatistics = ''ALL''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ CASE WHEN @OnlyModifiedStatistics = 'Y' THEN ', @OnlyModifiedStatistics = ''Y''' ELSE ', @StatisticsModificationLevel = ''5''' END + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @TimeLimit = ' + CONVERT(NVARCHAR(14), @TimeLimit) + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @LockTimeout = 300' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
 	+ ', @MaxDOP = 1' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @LogToTable = ''Y''' + CHAR(13) + CHAR(10)
	+ 'END' + CHAR(13) + CHAR(10)
	+ 'ELSE' + CHAR(13) + CHAR(10)
	+ 'IF DATEPART(dw, GETDATE()) = 7' + CHAR(13) + CHAR(10)
	+ 'BEGIN' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'EXEC [msdb].[dbo].[IndexOptimize]' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ '  @Databases = ''USER_DATABASES''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @FragmentationLow = NULL' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @FragmentationMedium = NULL' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @FragmentationHigh = NULL' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @UpdateStatistics = ''ALL''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @StatisticsSample = 100' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ CASE WHEN (SELECT CONVERT(VARCHAR, SERVERPROPERTY('Collation'))) NOT LIKE 'Latin1_General_CI_AS_KS_WS' THEN ', @TimeLimit = 10800' ELSE ', @TimeLimit = ' + CONVERT(NVARCHAR(14), @TimeLimit) END + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
 	+ ', @MaxDOP = 1' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @LogToTable = ''Y''' + CHAR(13) + CHAR(10)
	+ 'END'
	END
SET @OutputFileIndexOptimize = @OutputFileDirectory + '\' + 'OPTIMIZE_INDEX_USER_DATABASES_' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFileIndexOptimize) > 200 SET @OutputFileIndexOptimize = @OutputFileDirectory + '\' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFileIndexOptimize) > 200 SET @OutputFileIndexOptimize = NULL

/*
	| Added by Dmitry Spitsyn 28.11.2018
	| Reducing fragmentation for a tables and its indexes on SharePoint instances
*/
SET @JobCommandSPSIndexOptimize = 'SET DATEFIRST 1;' + CHAR(13) + CHAR(10)
	+ 'IF DATEPART(dw, GETDATE()) = 6' + CHAR(13) + CHAR(10)
	+ 'BEGIN' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'EXEC [msdb].[dbo].[IndexOptimize]' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ '  @Databases = ''USER_DATABASES''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @FragmentationLow = NULL' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @FragmentationMedium = NULL' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @FragmentationHigh = NULL' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @UpdateStatistics = ''ALL''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @OnlyModifiedStatistics = ''Y''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @TimeLimit = ' + CONVERT(NVARCHAR(14), @TimeLimit) + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
 	+ ', @MaxDOP = 1' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @LogToTable = ''Y''' + CHAR(13) + CHAR(10)
	+ 'END' + CHAR(13) + CHAR(10)
	+ 'ELSE' + CHAR(13) + CHAR(10)
	+ 'IF DATEPART(dw, GETDATE()) = 7' + CHAR(13) + CHAR(10)
	+ 'BEGIN' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'EXEC [msdb].[dbo].[IndexOptimize]' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ '  @Databases = ''USER_DATABASES''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @FragmentationLow = ''INDEX_REORGANIZE''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @FragmentationMedium = ''INDEX_REBUILD_ONLINE''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @FragmentationHigh = ''INDEX_REBUILD_OFFLINE''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @DatabaseOrder = ''DATABASE_SIZE_ASC''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @FragmentationLevel1 = 10' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @FragmentationLevel2 = 55' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @UpdateStatistics = ''ALL''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ CASE WHEN @OnlyModifiedStatistics = 'Y' THEN ', @OnlyModifiedStatistics = ''Y''' ELSE ', @StatisticsModificationLevel = ''5''' END + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @TimeLimit = ' + CONVERT(NVARCHAR(14), @TimeLimit) + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @LockTimeout = 300' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
 	+ ', @MaxDOP = 1' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ ', @LogToTable = ''Y''' + CHAR(13) + CHAR(10)
	+ 'END'
SET @OutputFileIndexOptimize = @OutputFileDirectory + '\' + 'OPTIMIZE_INDEX_USER_DATABASES_' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFileIndexOptimize) > 200 SET @OutputFileIndexOptimize = @OutputFileDirectory + '\' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFileIndexOptimize) > 200 SET @OutputFileIndexOptimize = NULL

/*
	| Added by Dmitry Spitsyn 01.09.2018
	| Step 03: CleanUp data on a regular basis to keep msdb at a reasonable size
	| Defined maintain level for indexes and statistics on objects that are created by internal SQL Server components
*/
SET @JobStepMSDBIndexOptimize = 'ST03: OPTIMIZE_INDEX_MSDB'
SET @JobCommandMSDBIndexOptimize = 'EXEC [msdb].[dbo].[IndexOptimize]' + CHAR(13) + CHAR(10) + CHAR(9)
	+ '  @Databases = ''msdb''' + CHAR(13) + CHAR(10) + CHAR(9)
	+ ', @FragmentationLow = ''INDEX_REORGANIZE''' + CHAR(13) + CHAR(10) + CHAR(9)
	+ ', @FragmentationMedium = ''INDEX_REORGANIZE''' + CHAR(13) + CHAR(10) + CHAR(9)
	+ ', @FragmentationHigh = ''INDEX_REORGANIZE''' + CHAR(13) + CHAR(10) + CHAR(9)
	+ ', @UpdateStatistics = ''ALL''' + CHAR(13) + CHAR(10) + CHAR(9)
	+ ', @Indexes = ''msdb.dbo.backupset''' + CHAR(13) + CHAR(10) + CHAR(9)
	+ ', @MSShippedObjects = ''Y''' + CHAR(13) + CHAR(10) + CHAR(9)
 	+ ', @MaxDOP = 1' + CHAR(13) + CHAR(10) + CHAR(9)
	+ ', @LogToTable = ''Y'''
SET @OutputFileMSDBIndexOptimize = @OutputFileDirectory + '\' + 'OPTIMIZE_INDEX_MSDB_' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFileMSDBIndexOptimize) > 200 SET @OutputFileMSDBIndexOptimize = @OutputFileDirectory + '\' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFileMSDBIndexOptimize) > 200 SET @OutputFileMSDBIndexOptimize = NULL

/*
	| Added by Dmitry Spitsyn 01.09.2018
	| Step 04: The following step executes the procedure to remove backup history records for all jobs older than 30 days
*/
SET @JobStepPurgeHistory = 'ST04: CLEANUP_BACKUP_HISTORY'
SET @JobCommandPurgeHistory = 'DECLARE @CleanupDate DATETIME' + CHAR(13) + CHAR(10) 
	+ 'SET @CleanupDate = DATEADD(dd, -30, GETDATE())' + CHAR(13) + CHAR(10) 
	+ 'EXEC [msdb].[dbo].[sp_delete_backuphistory] @oldest_date = @CleanupDate'
SET @OutputFilePurgeHistory = @OutputFileDirectory + '\' + 'CLEANUP_BACKUP_HISTORY_' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFilePurgeHistory) > 200 SET @OutputFilePurgeHistory = @OutputFileDirectory + '\' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFilePurgeHistory) > 200 SET @OutputFilePurgeHistory = NULL

/*
	| Added by Dmitry Spitsyn 01.09.2018
	| Step 05: The following step remove all history records in Table CommandLog older than 30 days
*/
SET @JobStepCleanupCommandLog = 'ST05: CLEANUP_TABLE_COMMANDLOG'
SET @JobCommandCleanupTableCommandLog = 'DELETE FROM [msdb].[dbo].[CommandLog] WHERE DATEDIFF(dd, StartTime, GETDATE()) > 30'
SET @OutputFileCleanupCommandLog = @OutputFileDirectory + '\' + 'CLEANUP_TABLE_COMMANDLOG_' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFileCleanupCommandLog) > 200 SET @OutputFileCleanupCommandLog = @OutputFileDirectory + '\' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFileCleanupCommandLog) > 200 SET @OutputFileCleanupCommandLog = NULL

/*
	| Added by Dmitry Spitsyn 01.09.2018
	| Step 06: The following step for clearing out jobs history data older than 30 days
*/
SET @JobStepCleanUpJobsHistory = 'ST06: CLEANUP_JOB_HISTORY'
SET @JobCommandCleanUpJobsHistory = 'DECLARE @CleanupDate DATETIME' + CHAR(13) + CHAR(10) 
	+ 'SET @CleanupDate = DATEADD(dd, -30, GETDATE())' + CHAR(13) + CHAR(10) 
	+ 'EXEC [msdb].[dbo].[sp_purge_jobhistory] @oldest_date = @CleanupDate'
SET @OutputFileCleanUpJobsHistory = @OutputFileDirectory + '\' + 'CLEANUP_JOBS_HISTORY_' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFileCleanUpJobsHistory) > 200 SET @OutputFileCleanUpJobsHistory = @OutputFileDirectory + '\' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFileCleanUpJobsHistory) > 200 SET @OutputFileCleanUpJobsHistory = NULL

/*
	| Added by Dmitry Spitsyn 01.09.2018
	| Step 07: The following step delete all Mail history records older than 30 days
*/
SET @JobStepCleanMessages = 'ST07: CLEANUP_MESSAGES'
SET @JobCommandCleanUpMessages = 'DECLARE @DateBefore DATETIME' + CHAR(13) + CHAR(10) 
	+ 'SET @DateBefore = DATEADD(DAY, -30, GETDATE())' + CHAR(13) + CHAR(10) 
	+ 'EXEC [msdb].[dbo].[sysmail_delete_mailitems_sp] @sent_before = @DateBefore, @sent_status = ''sent''' + CHAR(13) + CHAR(10)
	+ 'EXEC [msdb].[dbo].[sysmail_delete_log_sp] @logged_before = @DateBefore'
SET @OutputFileCleanUpEMessages = @OutputFileDirectory + '\' + 'CLEANUP_MESSAGES_' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFileCleanUpEMessages) > 200 SET @OutputFileCleanUpEMessages = @OutputFileDirectory + '\' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFileCleanUpEMessages) > 200 SET @OutputFileCleanUpEMessages = NULL

/*
	| Added by Dmitry Spitsyn 01.09.2018
	| Step 08: Delete *.txt files older than 30 days in the Output File Directory
	| Extend Output File name
*/
SET @JobStepOutputTFileCleanUp = 'ST08: CLEANUP_OUTPUT_TXTFILES'
SET @JobCommandOutputTFileCleanUp = 'cmd /q /c "For /F "tokens=1 delims=" %v In (''ForFiles /P "' 
	+ COALESCE(@OutputFileDirectory, @TokenLogDirectory) + '" /m *_*_*.txt /d -30 2^>^&1'') do if EXIST "' 
	+ COALESCE(@OutputFileDirectory, @TokenLogDirectory) + '"\%v echo del "' 
	+ COALESCE(@OutputFileDirectory, @TokenLogDirectory) + '"\%v& del "' 
	+ COALESCE(@OutputFileDirectory, @TokenLogDirectory) + '"\%v"'
SET @OutputFileOutputTFileCleanUp = COALESCE(@OutputFileDirectory, @TokenLogDirectory) + '\' + 'CLEANUP_OUTPUT_TFILES_' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFileOutputTFileCleanUp) > 200 SET @OutputFileOutputTFileCleanUp = COALESCE(@OutputFileDirectory, @TokenLogDirectory) + '\' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFileOutputTFileCleanUp) > 200 SET @OutputFileOutputTFileCleanUp = NULL

/*
	| Added by Dmitry Spitsyn 02.03.2020
	| Step 09: Delete *.sqlaudit files older than 60 days in the Output File Directory
	| Extend Output File name
*/
SET @JobStepOutputAFileCleanUp = 'ST09: CLEANUP_OUTPUT_AUDITFILES'
SET @JobCommandOutputAFileCleanUp = 'cmd /q /c "For /F "tokens=1 delims=" %v In (''ForFiles /P "' 
	+ COALESCE(@OutputFileDirectory, @TokenLogDirectory) + '" /m *.sqlaudit /d -60 2^>^&1'') do if EXIST "' 
	+ COALESCE(@OutputFileDirectory, @TokenLogDirectory) + '"\%v echo del "' 
	+ COALESCE(@OutputFileDirectory, @TokenLogDirectory) + '"\%v& del "' 
	+ COALESCE(@OutputFileDirectory, @TokenLogDirectory) + '"\%v"'
SET @OutputFileOutputAFileCleanUp = COALESCE(@OutputFileDirectory, @TokenLogDirectory) + '\' + 'CLEANUP_OUTPUT_AFILES_' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFileOutputAFileCleanUp) > 200 SET @OutputFileOutputAFileCleanUp = COALESCE(@OutputFileDirectory, @TokenLogDirectory) + '\' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFileOutputAFileCleanUp) > 200 SET @OutputFileOutputAFileCleanUp = NULL

/*
	| Added by Dmitry Spitsyn 01.09.2018
	| Step 09: The following step will prove state of all previous tasks
*/
SET @JobStepCheckStepsErrors = 'ST10: CHECK_STEPS_ERRORS'
SET @JobCommandCheckStepsErrors = 'IF EXISTS (' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'SELECT step_name FROM [msdb].[dbo].[sysjobsteps]' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'WHERE last_run_outcome = 0 '
	+ 'AND last_run_date <> 0 '
	+ 'AND step_name LIKE (''ST%''))' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'BEGIN' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ 'DECLARE @sJobName NVARCHAR(50), @sJobStepID NVARCHAR(2), @sJobStepName NVARCHAR(50), @sRunDuration NVARCHAR(20), @sLastRun NVARCHAR(20), @sMessage NVARCHAR(2048)' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ 'DECLARE cErrorMessage' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ 'CURSOR STATIC READ_ONLY FOR' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ 'SELECT [sJob].[name]' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9)
	+ ', [sJStp].[step_id]' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9)
	+ ', [sJStp].[step_name]' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9)
	+ ', STUFF(' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)
	+ 'STUFF(RIGHT(''000000'' + CAST([sJStp].[last_run_duration] AS VARCHAR(6)),  6)' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)
	+ ', 3, 0, '':'')' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)	
	+ ', 6, 0, '':'')' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9)
	+ ', CASE [sJStp].[last_run_date]'  + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)
	+ 'WHEN 0 THEN NULL'  + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)
	+ 'ELSE' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)
	+ 'CAST(' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)
	+ 'CAST([sJStp].[last_run_date] AS CHAR(8))' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)
	+ '+ '' '''  + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)
	+ '+ STUFF('  + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)
	+ 'STUFF(RIGHT(''000000'' + CAST([sJStp].[last_run_time] AS VARCHAR(6)),  6)'  + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)
	+ ', 3, 0, '':'')'  + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)
	+ ', 6, 0, '':'')'  + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)
	+ 'AS DATETIME)'  + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9)
	+ 'END'  + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ 'FROM [msdb].[dbo].[sysjobsteps] AS [sJStp]'  + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9)
	+ 'INNER JOIN [msdb].[dbo].[sysjobs] AS [sJob] ON [sJStp].[job_id] = [sJob].[job_id]'  + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ 'WHERE sJStp.last_run_outcome = 0 AND sJStp.step_name LIKE (''ST0%'') AND sJStp.step_name NOT LIKE (''%CHECK_STEPS_ERRORS%'') AND sJob.name = ''' + @JobNameMaintenanceSolution + ''''  + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ 'OPEN cErrorMessage' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ 'FETCH NEXT FROM cErrorMessage INTO @sJobName, @sJobStepID, @sJobStepName, @sRunDuration, @sLastRun' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ 'WHILE @@FETCH_STATUS = 0' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9)
	+ 'BEGIN' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)
	+ 'SELECT @sMessage = '''' + CHAR(13) + CHAR(10) + ''The Step "'' + @sJobStepName + ''" (ID:'' + @sJobStepID + '')''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)
	+ '+ '' is part of Maintenance Job "'' + @sJobName + ''" failed on '' + @sLastRun + '' after '' + @sRunDuration + '' min./sec. of execution.''' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)
	+ 'RAISERROR(@sMessage, 16, 1)' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9) + CHAR(9)
	+ 'FETCH NEXT FROM cErrorMessage INTO @sJobName, @sJobStepID, @sJobStepName, @sRunDuration, @sLastRun' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9) + CHAR(9)
	+ 'END' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ 'CLOSE cErrorMessage' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ 'DEALLOCATE cErrorMessage' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'END'
SET @OutputFileCheckStepsErrors = @OutputFileDirectory + '\' + 'CHECK_STEPS_ERRORS_' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFileCleanUpEMessages) > 200 SET @OutputFileCleanUpEMessages = @OutputFileDirectory + '\' + @TokenJobID + '_' + @TokenStepID + '_' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFileCleanUpEMessages) > 200 SET @OutputFileCleanUpEMessages = NULL

/*
	| Added by Dmitry Spitsyn 01.09.2018
	| Task stops execution all Maintenance jobs if any currently running
*/
SET @JobStepStopExecution = 'ST01: STOP_EXECUTION_MAINTENANCE_JOB'
SET @JobCommandStopExecution = 'DECLARE @RunningJobName VARCHAR(255)' + CHAR(13) + CHAR(10)
	+ 'DECLARE crRunningJobs CURSOR STATIC READ_ONLY FOR' + CHAR(13) + CHAR(10)
	+ 'SELECT sj.name' + CHAR(13) + CHAR(10)
	+ 'FROM [msdb].[dbo].[sysjobactivity] AS sja' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'INNER JOIN [msdb].[dbo].[sysjobs] AS sj ON sja.job_id = sj.job_id' + CHAR(13) + CHAR(10)
	+ 'WHERE sja.start_execution_date IS NOT NULL' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'AND sja.stop_execution_date IS NULL' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'AND sj.name LIKE ''' + @EnvironmentPrefix + '%''' + CHAR(13) + CHAR(10)
	+ 'OPEN crRunningJobs' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'FETCH NEXT FROM crRunningJobs INTO @RunningJobName' + CHAR(13) + CHAR(10)
	+ 'WHILE @@FETCH_STATUS = 0' + CHAR(13) + CHAR(10)
	+ 'BEGIN' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'BEGIN TRY' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ 'EXEC [msdb].[dbo].[sp_stop_job] @job_name = @RunningJobName' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'END TRY' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'BEGIN CATCH' + CHAR(13) + CHAR(10) + CHAR(9) + CHAR(9)
	+ 'PRINT ERROR_MESSAGE()' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'END CATCH' + CHAR(13) + CHAR(10) + CHAR(9)
	+ 'FETCH NEXT FROM crRunningJobs INTO @RunningJobName' + CHAR(13) + CHAR(10)
	+ 'END' + CHAR(13) + CHAR(10)
	+ 'CLOSE crRunningJobs' + CHAR(13) + CHAR(10)
	+ 'DEALLOCATE crRunningJobs'
SET @OutputFileStopExecution = @OutputFileDirectory + '\' + 'STOP_EXECUTION_' + @EnvironmentPrefix + 'JOBS_' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFileStopExecution) > 200 SET @OutputFileStopExecution = @OutputFileDirectory + '\' + @TokenDate + '_' + @TokenTime + '.txt'
IF LEN(@OutputFileStopExecution) > 200 SET @OutputFileStopExecution = NULL

/*
	| Added by Dmitry Spitsyn 01.09.2018
*/
SET @JobNameStopExecution = @EnvironmentPrefix + 'STOP_EXECUTION_' + @EnvironmentPrefix + 'JOBS'
SET @JobDescriptionStopExecution = N'Job can be started to stop running Maintenance Job.' + CHAR(13) + CHAR(10)
	+ N'Some long-running Transact-SQL statements such as BACKUP, RESTORE, and some DBCC commands can take a long time to finish.' + CHAR(13) + CHAR(10) + @MsgNoSchedule
IF EXISTS ( SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobNameStopExecution )
	BEGIN
		GOTO SkipCreateStopJob
	END
ELSE
	BEGIN
		IF EXISTS ( SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobNameStopExecution )
			EXEC msdb.dbo.sp_delete_job
				  @job_name = @JobNameStopExecution
				, @delete_unused_schedule = 1
			EXEC msdb.dbo.sp_add_job 
				  @job_name = @JobNameStopExecution
				, @description = @JobDescriptionStopExecution
				, @category_name = @JobCategory
				, @owner_login_name = @JobOwner
			EXEC msdb.dbo.sp_add_jobstep 
				  @job_name = @JobNameStopExecution
				, @step_name = @JobStepStopExecution
				, @subsystem = 'TSQL'
				, @command = @JobCommandStopExecution
				, @output_file_name = @OutputFileStopExecution
				, @database_name = @DatabaseName
				, @on_success_action = 1
				, @on_fail_action = 2
			EXEC msdb.dbo.sp_add_jobserver @job_name = @JobNameStopExecution
			--PRINT 'Standard job ''' + @JobNameStopExecution + ''' created. ' + @MsgNoSchedule
	END
SkipCreateStopJob:

/*
	| Added by Dmitry Spitsyn on 01.09.2018
	| Delete Maintenance job only if exists
*/
IF @DeleteMaintenanceSolution = 0
	BEGIN
		GOTO SkipDelete
	END
	ELSE
	BEGIN
		IF EXISTS ( SELECT name FROM msdb.dbo.sysjobs
			WHERE description LIKE '%Maintenance Solution%' )
		BEGIN
			DECLARE csrjobs
			CURSOR FAST_FORWARD FOR
			SELECT name FROM msdb.dbo.sysjobs
			WHERE description LIKE '%Maintenance Solution%'
				OPEN csrjobs
				FETCH NEXT FROM csrjobs INTO @JobNameOla
				WHILE @@FETCH_STATUS = 0
					BEGIN
						EXEC msdb.dbo.sp_delete_job @job_name = @JobNameOla, @delete_unused_schedule = 1
						FETCH NEXT FROM csrjobs INTO @JobNameOla
					END
				CLOSE csrjobs
			DEALLOCATE csrjobs
		PRINT 'Maintenance Solution were successfully deleted. All other actions were skipped.' + CHAR(13) + CHAR(10) + 'To proceed further with script, you have to set parameter DeleteMaintenanceSolution back to ''0'''
		GOTO TheEnd
		END
		ELSE
		BEGIN
			PRINT 'Job ''' + @JobNameMaintenanceSolution + ''' does not exists.' + CHAR(13) + CHAR(10) + 'To proceed further with script, you have to set parameter DeleteMaintenanceSolution back to ''0'''
			GOTO TheEnd
		END
	END
SkipDelete:

/*
	| Added by Dmitry Spitsyn on 01.09.2018
	| The following step will change process while installation
*/
IF EXISTS ( SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobNameMaintenanceSolution )
BEGIN
	PRINT '''' + @JobNameMaintenanceSolution + ''' job already exists and cannot be changed.' + CHAR(13) + CHAR(10) 
		+ 'If needed, you may delete this job manually or set parameter DeleteMaintenanceSolution to ''1'''
	SET @Flag = 1
	GOTO SkipCreateJob
END
ELSE
BEGIN
	IF NOT EXISTS ( SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobNameMaintenanceSolution )
		EXEC msdb.dbo.sp_add_job 
			  @job_name = @JobNameMaintenanceSolution
			, @description = @JobDescription
			, @category_name = @JobCategory
			, @owner_login_name = @JobOwner
		PRINT 'Standard Maintenance job ''' + @JobNameMaintenanceSolution + ''' were created and will be executed at: ' + @MsgExecutionTime + CHAR(13) + CHAR(10) + @aMessage

	-- Step 1
	-- Changes by Dmitry Spitsyn in step 'ST01: CHECK_INTEGRITY_ALL_DATABASES'

	IF @Size = '0' OR @Size = '1'
		EXEC msdb.dbo.sp_add_jobstep
			  @job_name = @JobNameMaintenanceSolution
			, @step_name = @JobStepIntegrityCheck
			, @subsystem = 'TSQL'
			, @command = @JobCommandIntegrityCheck
			, @output_file_name = @OutputFileIntegrityCheck
			, @database_name = @DatabaseName
			, @on_success_action = 3
			, @on_fail_action = 3

	-- Step 2
	-- Changes by Dmitry Spitsyn in step 'ST02: OPTIMIZE_INDEX_ALL_DATABASES' for SharePoint application

	IF ( SELECT CONVERT(VARCHAR, SERVERPROPERTY('Collation')) ) LIKE 'Latin1_General_CI_AS_KS_WS'
		BEGIN
		IF @Size = '0' OR @Size = '2'
			EXEC msdb.dbo.sp_add_jobstep 
				  @job_name = @JobNameMaintenanceSolution
				, @step_name = @JobStepIndexOptimize
				, @subsystem = 'TSQL'
				, @command = @JobCommandSPSIndexOptimize
				, @output_file_name = @OutputFileIndexOptimize
				, @database_name = @DatabaseName
				, @on_success_action = 3
				, @retry_attempts = 2
				, @retry_interval = 10
				, @on_fail_action = 3
		PRINT 'According to Collation on Instance level, there are databases for SharePoint application.'
		END
	ELSE
		BEGIN

		-- Step 2
		-- Changes by Dmitry Spitsyn in step 'ST02: OPTIMIZE_INDEX_ALL_DATABASES'

		IF @Size = '0' OR @Size = '2'
			EXEC msdb.dbo.sp_add_jobstep 
				  @job_name = @JobNameMaintenanceSolution
				, @step_name = @JobStepIndexOptimize
				, @subsystem = 'TSQL'
				, @command = @JobCommandIndexOptimize
				, @output_file_name = @OutputFileIndexOptimize
				, @database_name = @DatabaseName
				, @on_success_action = 3
				, @retry_attempts = 2
				, @retry_interval = 10
				, @on_fail_action = 3
		END

		-- Step 3
		-- Changes by Dmitry Spitsyn in step 'ST03: OPTIMIZE_INDEX_MSDB'

		EXEC msdb.dbo.sp_add_jobstep 
			  @job_name = @JobNameMaintenanceSolution
			, @step_name = @JobStepMSDBIndexOptimize
			, @subsystem = 'TSQL'
			, @command = @JobCommandMSDBIndexOptimize
			, @output_file_name = @OutputFileMSDBIndexOptimize
			, @database_name = @DatabaseName
			, @on_success_action = 3
			, @retry_attempts = 0
			, @retry_interval = 0 
			, @on_fail_action = 3

		-- Step 4
		-- Changes by Dmitry Spitsyn in step 'ST04: CLEANUP_BACKUP_HISTORY'

		EXEC msdb.dbo.sp_add_jobstep 
			  @job_name = @JobNameMaintenanceSolution
			, @step_name = @JobStepPurgeHistory
			, @subsystem = 'TSQL'
			, @command = @JobCommandPurgeHistory
			, @output_file_name = @OutputFilePurgeHistory
			, @database_name = @DatabaseName
			, @on_success_action = 3
			, @on_fail_action = 3

		-- Step 5
		-- Changes by Dmitry Spitsyn in step 'ST05: CLEANUP_TABLE_COMMANDLOG'

		EXEC msdb.dbo.sp_add_jobstep 
			  @job_name = @JobNameMaintenanceSolution
			, @step_name = @JobStepCleanupCommandLog
			, @subsystem = 'TSQL'
			, @command = @JobCommandCleanupTableCommandLog
			, @output_file_name = @OutputFileCleanupCommandLog
			, @database_name = @DatabaseName
			, @on_success_action = 3
			, @on_fail_action = 3

		-- Step 6
		-- Changes by Dmitry Spitsyn in step 'ST06: CLEANUP_JOB_HISTORY'

		EXEC msdb.dbo.sp_add_jobstep 
			  @job_name = @JobNameMaintenanceSolution
			, @step_name = @JobStepCleanUpJobsHistory
			, @subsystem = 'TSQL'
			, @command = @JobCommandCleanUpJobsHistory
			, @output_file_name = @OutputFileCleanUpJobsHistory
			, @database_name = @DatabaseName
			, @on_success_action = 3
			, @on_fail_action = 3

		-- Step 7
		-- Changes by Dmitry Spitsyn in step 'ST07: CLEANUP_MESSAGES'

		EXEC msdb.dbo.sp_add_jobstep 
			  @job_name = @JobNameMaintenanceSolution
			, @step_name = @JobStepCleanMessages
			, @subsystem = 'TSQL'
			, @command = @JobCommandCleanUpMessages
			, @output_file_name = @OutputFileCleanUpEMessages
			, @database_name = @DatabaseName
			, @on_success_action = 3
			, @on_fail_action = 3

		-- Step 8
		-- Changes by Dmitry Spitsyn in step 'ST08: CLEANUP_OUTPUT_TXTFILES'

		EXEC msdb.dbo.sp_add_jobstep 
			  @job_name = @JobNameMaintenanceSolution
			, @step_name = @JobStepOutputTFileCleanUp
			, @subsystem = 'CMDEXEC'
			, @command = @JobCommandOutputTFileCleanUp
			, @output_file_name = @OutputFileOutputTFileCleanUp
			, @database_name = @DatabaseName
			, @on_success_action = 3
			, @on_fail_action = 3

		-- Step 9
		-- Changes by Dmitry Spitsyn in step 'ST09: CLEANUP_OUTPUT_AUDITFILES'

		EXEC msdb.dbo.sp_add_jobstep 
			  @job_name = @JobNameMaintenanceSolution
			, @step_name = @JobStepOutputAFileCleanUp
			, @subsystem = 'CMDEXEC'
			, @command = @JobCommandOutputAFileCleanUp
			, @output_file_name = @OutputFileOutputAFileCleanUp
			, @database_name = @DatabaseName
			, @on_success_action = 3
			, @on_fail_action = 3

		-- Step 10
		-- Changes by Dmitry Spitsyn in step 'ST10: CHECK_STEPS_ERRORS'

		EXEC msdb.dbo.sp_add_jobstep 
			  @job_name = @JobNameMaintenanceSolution
			, @step_name = @JobStepCheckStepsErrors
			, @subsystem = 'TSQL'
			, @command = @JobCommandCheckStepsErrors
			, @output_file_name = @OutputFileCheckStepsErrors
			, @database_name = @DatabaseName
			, @on_success_action = 1
			, @on_fail_action = 2
		EXEC msdb.dbo.sp_add_jobserver @job_name = @JobNameMaintenanceSolution

		EXEC msdb.dbo.sp_add_jobschedule 
			  @job_name = @JobNameMaintenanceSolution
			, @name = @JobScheduleName
			, @enabled = 1
			, @freq_type = 4
			, @freq_interval = 1
			, @freq_subday_type = 1
			, @freq_subday_interval = 0
			, @freq_relative_interval = 0
			, @freq_recurrence_factor = 1
			, @active_start_date = 20180716
			, @active_end_date = 99991231
			, @active_start_time = @ScheduleTime
			, @active_end_time = 235959
			, @schedule_id = @JobScheduleID OUTPUT
END

SkipCreateJob:

/*
	| Added by Dmitry Spitsyn on 01.09.2018
	| Verify the backup to make additional checking on the data to increase the probability of detecting errors
	| No sub-directory structure for backup databases
	| Specifying the file name for databases
	| BACKUP verifies that the data read from the database is consistent with any checksum or torn-page indication that is present in the database
	| If the backup operation encounters a page error during verification, the backup fails
*/
IF @CreateBackupJobs = 1
	BEGIN
	SET @JobNameBackupSystem = @EnvironmentPrefix + 'BACKUP_SYSTEM_DATABASES'
	SET @JobCommandBackupSystem = 'EXEC [msdb].[dbo].[DatabaseBackup]' + CHAR(13) + CHAR(10) + CHAR(9)
		+ '  @Databases = ''SYSTEM_DATABASES''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @FileName = ''{DatabaseName}_{Year}.{Month}.{Day}_{Hour}.{Minute}.{Second}.{FileExtension}''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @DirectoryStructure = ''{DatabaseName}{DirectorySeparator}{BackupType}_{Partial}_{CopyOnly}''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @CleanupMode = ''BEFORE_BACKUP''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @FileExtensionFull = ''bak''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @BackupType = ''FULL''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @CleanupTime = 336' + CHAR(13) + CHAR(10) + CHAR(9)
		+ CASE WHEN @LogToTable = 'Y' THEN ', @LogToTable = ''Y''' ELSE '' END + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @Directory = ' + ISNULL('''' + REPLACE(@BackupDirectory, '''', '''''') + '''', 'NULL')  + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @CheckSum = ''Y''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @Compress = ''Y''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @CopyOnly = ''Y''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @Verify = ''Y''' + CHAR(13) + CHAR(10) + CHAR(9)
	SET @OutputFileBackupSystem = COALESCE(@OutputFileDirectory, @TokenLogDirectory) + '\' + 'BACKUP_SYSTEM_DATABASES_' + @TokenDate + '_' + @TokenTime + '.txt'
	IF LEN(@OutputFileBackupSystem) > 200 SET @OutputFileBackupSystem = COALESCE(@OutputFileDirectory, @TokenLogDirectory) + '\' + @TokenDate + '_' + @TokenTime + '.txt'
	IF LEN(@OutputFileBackupSystem) > 200 SET @OutputFileBackupSystem = NULL

	IF EXISTS ( SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobNameBackupSystem )
		BEGIN
			GOTO SkipCreateBSDJob
		END
	ELSE
		BEGIN
			EXEC msdb.dbo.sp_add_job 
				  @job_name = @JobNameBackupSystem
				, @description = @JobDescriptionWithNoSchedule				
				, @category_name = @JobCategory
				, @owner_login_name = @JobOwner
			EXEC msdb.dbo.sp_add_jobstep 
				  @job_name = @JobNameBackupSystem
				, @step_name = @JobNameBackupSystem
				, @subsystem = 'TSQL'
				, @command = @JobCommandBackupSystem
				, @database_name = @DatabaseName
				, @output_file_name = @OutputFileBackupSystem
			EXEC msdb.dbo.sp_add_jobserver @job_name = @JobNameBackupSystem
			PRINT 'Backup job ''' + @JobNameBackupSystem + ''' created. ' + @MsgNoSchedule
		END
	SkipCreateBSDJob:

/*
	| Added by Dmitry Spitsyn on 05.09.2018
	| Extended by Dmitry Spitsyn on 11.04.2019
	| Extended by Dmitry Spitsyn on 30.04.2019
	| Specify the database order by the database size 
	| Specify that the backup is a copy-only backup, which does not affect the normal sequence of backups
	| Specify the time, in hours | one (1) week), after which the backup files are deleted
	| Specify Parameters for directory structure
	| Specify that the old backup files will be deleted before the backup has been performed
	| Enable verify the backup
	| Enable compress the backup
	| Enable backup checksums
*/
	SET @JobNameBackupUser = @EnvironmentPrefix + 'BACKUP_USER_DATABASES_FULL'
	SET @JobCommandBackupUser = 'EXEC [msdb].[dbo].[DatabaseBackup]' + CHAR(13) + CHAR(10) + CHAR(9)
		+ '  @Databases = ''USER_DATABASES''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @FileName = ''{DatabaseName}_{Year}.{Month}.{Day}_{Hour}.{Minute}.{Second}.{FileExtension}''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @DirectoryStructure = ''{DatabaseName}{DirectorySeparator}{BackupType}_{Partial}_{CopyOnly}''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @DatabaseOrder = ''DATABASE_SIZE_DESC''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @CleanupMode = ''BEFORE_BACKUP''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @FileExtensionFull = ''bak''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @BackupType = ''FULL''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @CleanupTime = 168' + CHAR(13) + CHAR(10) + CHAR(9)
		+ CASE WHEN @LogToTable = 'Y' THEN ', @LogToTable = ''Y''' ELSE '' END + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @Directory = ' + ISNULL('''' + REPLACE(@BackupDirectory, '''', '''''') + '''', 'NULL')  + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @CheckSum = ''Y''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @Compress = ''Y''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @CopyOnly = ''Y''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @Verify = ''Y''' + CHAR(13) + CHAR(10) + CHAR(9)
	SET @OutputFileBackupUser = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + 'BACKUP_USER_DATABASES_' + @TokenDate + '_' + @TokenTime + '.txt'
	IF LEN(@OutputFileBackupUser) > 200 SET @OutputFileBackupUser = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + @TokenDate + '_' + @TokenTime + '.txt'
	IF LEN(@OutputFileBackupUser) > 200 SET @OutputFileBackupUser = NULL

/*
	| Added by Dmitry Spitsyn 30.04.2019
	| Inserted step ST02: IDENTIFY FAILED FULL BACKUPS
*/	
	SET @JobCommandFailedBackups = 'DECLARE @SQL VARCHAR(MAX), @FailedBackups NVARCHAR(MAX), @BackupType VARCHAR(4)' + CHAR(13) + CHAR(10)
		+ 'SET @BackupType = ''FULL'';' + CHAR(13) + CHAR(10)
		+ 'WITH cteRowNumber' + CHAR(13) + CHAR(10)
		+ 'AS (SELECT [DatabaseName]' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', [ErrorNumber]' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', ROW_NUMBER() OVER(PARTITION BY [DatabaseName]' + CHAR(13) + CHAR(10)
		+ 'ORDER BY ID DESC) AS RowNum' + CHAR(13) + CHAR(10)
		+ 'FROM [msdb].[dbo].[CommandLog]' + CHAR(13) + CHAR(10)
		+ 'WHERE [Command] LIKE ''%_'' + @BackupType + ''_%'' AND [CommandType] = ''BACKUP_DATABASE'')' + CHAR(13) + CHAR(10) + CHAR(9)
		+ 'SELECT @FailedBackups = COALESCE(@FailedBackups + '', '', '''') + [DatabaseName]' + CHAR(13) + CHAR(10)
		+ 'FROM cteRowNumber' + CHAR(13) + CHAR(10)
		+ 'WHERE RowNum = 1 AND [ErrorNumber] <> 0' + CHAR(13) + CHAR(10)
		+ 'ORDER BY [DatabaseName];' + CHAR(13) + CHAR(10) 
		+ 'SELECT @SQL = ''EXEC [msdb].[dbo].[DatabaseBackup]' + CHAR(13) + CHAR(10) + CHAR(9)
		+ '  @Databases = '''''' + @FailedBackups + ''''''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @Directory = ' + ISNULL('''' + REPLACE(@BackupDirectory, '''', '''''') + '''''', 'NULL') + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @DatabaseOrder = ''''DATABASE_SIZE_DESC''''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @BackupType = '''''' + @BackupType + ''''''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @FileName = ''''{DatabaseName}_{Year}.{Month}.{Day}_{Hour}.{Minute}.{Second}.{FileExtension}''''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @DirectoryStructure = ''''{DatabaseName}{DirectorySeparator}{BackupType}_{Partial}_{CopyOnly}''''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @CleanupMode = ''''BEFORE_BACKUP''''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @FileExtensionFull = ''''BAK''''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @CleanupTime = 24' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @LogToTable =  ''''Y''''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @Compress = ''''Y''''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @CopyOnly = ''''Y''''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @CheckSum = ''''Y''''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @Verify = ''''Y'''''';' + CHAR(13) + CHAR(10)
		+ 'EXEC (@SQL);'
	SET @OutputFileFailedBackups = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + 'FAILED_BACKUPS_USER_DATABASES_' + @TokenDate + '_' + @TokenTime + '.txt'
	IF LEN(@OutputFileBackupUser) > 200 SET @OutputFileBackupUser = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + @TokenDate + '_' + @TokenTime + '.txt'
	IF LEN(@OutputFileBackupUser) > 200 SET @OutputFileBackupUser = NULL

	IF EXISTS (SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobNameBackupUser)
		BEGIN
			GOTO SkipCreateBUDJob
		END
	ELSE
		BEGIN
			EXEC msdb.dbo.sp_add_job 
				  @job_name = @JobNameBackupUser
				, @description = @JobDescriptionWithNoSchedule
				, @category_name = @JobCategory
				, @owner_login_name = @JobOwner
			EXEC msdb.dbo.sp_add_jobstep 
				  @job_name = @JobNameBackupUser
				, @step_name = N'ST01: BACKUP USER DATABASES FULL'
				, @step_id = 1
				, @on_success_action = 3
				, @on_fail_action = 3
				, @subsystem = 'TSQL'
				, @command = @JobCommandBackupUser
				, @database_name = @DatabaseName
				, @output_file_name = @OutputFileBackupUser
			EXEC msdb.dbo.sp_add_jobstep 
				  @job_name = @JobNameBackupUser
				, @step_name = N'ST02: IDENTIFY FAILED FULL BACKUPS'
				, @step_id = 2
				, @on_success_action = 1
				, @on_fail_action = 2
				, @subsystem = 'TSQL'
				, @command = @JobCommandFailedBackups
				, @database_name = @DatabaseName
				, @output_file_name = @OutputFileFailedBackups
			EXEC msdb.dbo.sp_add_jobserver @job_name = @JobNameBackupUser
			PRINT 'Backup job ''' + @JobNameBackupUser + ''' created. ' + @MsgNoSchedule
		END
	SkipCreateBUDJob:

/*
	| Added by Dmitry Spitsyn on 01.09.2018
	| Disabling option to do more frequent log backups of databases with high activity (every half an hour or if 5 GB of log has been generated since the last log backup)
	| Change the backup type dynamically if transaction log backup cannot be performed
	| Extended by Dmitry Spitsyn on 30.04.2019
	| Inserted step ST01: BACKUP USER DATABASES LOG
*/
	SET @JobNameBackupUserLog = @EnvironmentPrefix + 'BACKUP_USER_DATABASES_LOG'
	SET @JobCommandBackupUserLog = 'EXEC [msdb].[dbo].[DatabaseBackup]' + CHAR(13) + CHAR(10) + CHAR(9)
		+ '  @Databases = ''USER_DATABASES''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @FileName = ''{DatabaseName}_{Year}.{Month}.{Day}_{Hour}.{Minute}.{Second}.{FileExtension}''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @DirectoryStructure = ''{DatabaseName}{DirectorySeparator}{BackupType}_{Partial}_{CopyOnly}''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @LogSizeSinceLastLogBackup = 5120' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @TimeSinceLastLogBackup = 1800' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @ChangeBackupType = ''Y''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @FileExtensionLog = ''TRN''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @BackupType = ''LOG''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @CleanupTime = 24' + CHAR(13) + CHAR(10) + CHAR(9)
		+ CASE WHEN @LogToTable = 'Y' THEN ', @LogToTable = ''Y''' ELSE '' END + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @Directory = ' + ISNULL('''' + REPLACE(@BackupDirectory, '''', '''''') + '''', 'NULL') + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @CheckSum = ''Y''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @Compress = ''Y''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @Verify = ''Y''' + CHAR(13) + CHAR(10) + CHAR(9)
	SET @OutputFileBackupUserLog = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + 'BACKUP_USER_DATABASES_LOG_' + @TokenDate + '_' + @TokenTime + '.txt'
	IF LEN(@OutputFileBackupUserLog) > 200 SET @OutputFileBackupUserLog = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + @TokenDate + '_' + @TokenTime + '.txt'
	IF LEN(@OutputFileBackupUserLog) > 200 SET @OutputFileBackupUserLog = NULL

/*
	| Added by Dmitry Spitsyn 30.04.2019
	| Inserted step ST02: IDENTIFY FAILED LOG BACKUPS
*/	
	SET @JobCommandFailedLogBackups = 'DECLARE @SQL VARCHAR(MAX), @FailedBackups NVARCHAR(MAX), @BackupType VARCHAR(4)' + CHAR(13) + CHAR(10)
		+ 'SET @BackupType = ''LOG'';' + CHAR(13) + CHAR(10)
		+ 'WITH cteRowNumber' + CHAR(13) + CHAR(10)
		+ 'AS (SELECT [DatabaseName]' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', [ErrorNumber]' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', ROW_NUMBER() OVER(PARTITION BY [DatabaseName]' + CHAR(13) + CHAR(10)
		+ 'ORDER BY ID DESC) AS RowNum' + CHAR(13) + CHAR(10)
		+ 'FROM [msdb].[dbo].[CommandLog]' + CHAR(13) + CHAR(10)
		+ 'WHERE [Command] LIKE ''%_'' + @BackupType + ''_%'' AND [CommandType] = ''BACKUP_LOG'')' + CHAR(13) + CHAR(10) + CHAR(9)
		+ 'SELECT @FailedBackups = COALESCE(@FailedBackups + '', '', '''') + [DatabaseName]' + CHAR(13) + CHAR(10)
		+ 'FROM cteRowNumber' + CHAR(13) + CHAR(10)
		+ 'WHERE RowNum = 1 AND [ErrorNumber] <> 0' + CHAR(13) + CHAR(10)
		+ 'ORDER BY [DatabaseName];' + CHAR(13) + CHAR(10) 
		+ 'SELECT @SQL = ''EXEC [msdb].[dbo].[DatabaseBackup]' + CHAR(13) + CHAR(10) + CHAR(9)
		+ '  @Databases = '''''' + @FailedBackups + ''''''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @Directory = ' + ISNULL('''' + REPLACE(@BackupDirectory, '''', '''''') + '''''', 'NULL') + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @BackupType = '''''' + @BackupType + ''''''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @FileName = ''''{DatabaseName}_{Year}.{Month}.{Day}_{Hour}.{Minute}.{Second}.{FileExtension}''''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @DirectoryStructure = ''''{DatabaseName}{DirectorySeparator}{BackupType}_{Partial}_{CopyOnly}''''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @CleanupMode = ''''BEFORE_BACKUP''''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @FileExtensionFull = ''''TRN''''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @CleanupTime = 24' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @LogToTable =  ''''Y''''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @CheckSum = ''''Y''''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @Compress = ''''Y''''' + CHAR(13) + CHAR(10) + CHAR(9)
		+ ', @Verify = ''''Y'''''';' + CHAR(13) + CHAR(10)
		+ 'EXEC (@SQL);'
	SET @OutputFileFailedLogBackups = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + 'FAILED_LOG_BACKUPS_USER_DATABASES_' + @TokenDate + '_' + @TokenTime + '.txt'
	IF LEN(@OutputFileBackupUser) > 200 SET @OutputFileBackupUser = COALESCE(@OutputFileDirectory,@TokenLogDirectory) + '\' + @TokenDate + '_' + @TokenTime + '.txt'
	IF LEN(@OutputFileBackupUser) > 200 SET @OutputFileBackupUser = NULL
		
	IF EXISTS ( SELECT * FROM msdb.dbo.sysjobs WHERE [name] = @JobNameBackupUserLog )
		BEGIN
			GOTO SkipCreateBUDLJob
		END
	ELSE
		BEGIN
			EXEC msdb.dbo.sp_add_job 
				  @job_name = @JobNameBackupUserLog
				, @description = @JobDescriptionWithNoSchedule
				, @category_name = @JobCategory
				, @owner_login_name = @JobOwner
			EXEC msdb.dbo.sp_add_jobstep 
				  @job_name = @JobNameBackupUserLog
				, @step_name = N'ST01: BACKUP USER DATABASES LOG'
				, @step_id = 1
				, @on_success_action = 3
				, @on_fail_action = 3
				, @subsystem = 'TSQL'
				, @command = @JobCommandBackupUserLog
				, @database_name = @DatabaseName
				, @output_file_name = @OutputFileBackupUserLog
			EXEC msdb.dbo.sp_add_jobstep 
				  @job_name = @JobNameBackupUserLog
				, @step_name = N'ST02: IDENTIFY FAILED LOG BACKUPS'
				, @step_id = 2
				, @on_success_action = 1
				, @on_fail_action = 2
				, @subsystem = 'TSQL'
				, @command = @JobCommandFailedLogBackups
				, @database_name = @DatabaseName
				, @output_file_name = @OutputFileFailedLogBackups
			EXEC msdb.dbo.sp_add_jobserver @job_name = @JobNameBackupUserLog
			PRINT 'Backup job ''' + @JobNameBackupUserLog + ''' created. ' + @MsgNoSchedule
		END
	SkipCreateBUDLJob:
	END

/*
	| Added by Dmitry Spitsyn on 01.09.2018
	| Extended by Dmitry Spitsyn on 30.04.2019
	| Check existing modules and Solution Version
*/
IF ( SELECT COUNT(SPECIFIC_NAME)
	FROM INFORMATION_SCHEMA.ROUTINES
	WHERE ROUTINE_DEFINITION LIKE '%2020-01-26 14:06:53%' 
		AND ROUTINE_TYPE = 'PROCEDURE'
		) <> 4
		BEGIN
			SET @ErrorMessage = 'The Job ''' + @EnvironmentPrefix + 'MAINTENANCE_ALL_DATABASES'' depends on the missing object ''' + @EnvironmentPrefix + 'Maintenance_Solution'' and/or verify current version of all existing procedures.'
			IF @Flag <> 1 SET @ErrorMessage = @ErrorMessage + CHAR(13) + CHAR(10)
			+ 'The modul will still be created; however, it cannot run successfully until all objects are exists.'
			RAISERROR(@ErrorMessage, 16, 1) WITH NOWAIT
			SET @Error = @@ERROR
		END
TheEnd:
GO
