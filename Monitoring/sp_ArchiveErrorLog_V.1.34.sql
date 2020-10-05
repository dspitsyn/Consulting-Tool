USE [USAGE]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

	IF OBJECT_ID('dbo.ArchiveErrorLog') IS NULL
		EXEC ('CREATE PROCEDURE dbo.ArchiveErrorLog AS RETURN 0;');
	GO

	ALTER PROCEDURE [dbo].[ArchiveErrorLog]
		  @Version VARCHAR(10) = NULL OUTPUT
		, @VersionDate DATETIME = NULL OUTPUT
	AS
	BEGIN;
	SET NOCOUNT ON;
	SET ARITHABORT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;

		EXEC sp_cycle_errorlog
		IF @@Error = 0

	SELECT @Version = '1.34', @VersionDate = '20200927';

	/*
		| Archive Engine Error Log
	*/
	IF NOT EXISTS ( SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'LogArchive' )
		BEGIN
			CREATE TABLE [dbo].[LogArchive] (
				  [LogArchiveID] INT IDENTITY(1, 1) NOT NULL
				, [LogDate] DATETIME NULL
				, [ProcessInfo] VARCHAR(50) NULL
				, [Text] VARCHAR(MAX) NULL
			) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
		END

	IF NOT EXISTS ( SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'ErrorArchive' )
		BEGIN
			CREATE TABLE [dbo].[ErrorArchive] (
				  [ErrorID] INT IDENTITY(1, 1) NOT NULL
				, [ErrorDate] DATETIME NULL
				, [ProcessInfo] VARCHAR(50) NULL
				, [Text] VARCHAR(MAX) NULL
			) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
		END;

	/*
		| Archive Agent Error Log
	*/
	IF NOT EXISTS ( SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'AgentLogArchive' )
		BEGIN
			CREATE TABLE AgentLogArchive (
				  [LogDate] DATETIME NULL
				, [ErrorLevel] VARCHAR(10) NULL
				, [Text] VARCHAR(MAX) NULL
				)
		END;

	DROP TABLE IF EXISTS #AgentLogArchive;
	CREATE TABLE #AgentLogArchive (
		  [LogDate] DATETIME NULL
		, [ErrorLevel] VARCHAR(50) NULL
		, [Text] VARCHAR(MAX) NULL
		)
		BEGIN
			INSERT INTO #AgentLogArchive ( [LogDate], [ErrorLevel], [Text] )
			EXEC xp_readerrorlog 0,2
			INSERT INTO [USAGE].[dbo].[AgentLogArchive] ( [LogDate], [ErrorLevel], [Text] )
			SELECT [LogDate], [ErrorLevel], [Text] FROM #AgentLogArchive 
			WHERE [Text] LIKE '%Error%' OR [Text] LIKE '%Fehler%'
				AND LogDate >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
				AND LogDate < DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)
		END;
	
	/*
		| Archive SQL Server Logs
	*/
	DROP TABLE IF EXISTS TempLogArchive;
	CREATE TABLE TempLogArchive (
		  [LogArchiveID] INT IDENTITY(1, 1) NOT NULL
		, [LogDate] DATETIME NULL
		, [ProcessInfo] VARCHAR(50) NULL
		, [Text] VARCHAR(MAX) NULL
		)
		BEGIN
			INSERT INTO TempLogArchive ( [LogDate], [ProcessInfo], [Text] )
			EXEC xp_readerrorlog 1
			INSERT INTO [USAGE].[dbo].[LogArchive] ( [LogDate], [ProcessInfo], [Text] )
			SELECT [LogDate], [ProcessInfo], [Text] FROM TempLogArchive
			WHERE [Text] LIKE '%Error%'
				OR [Text] LIKE '%filegroup is full%'
				OR [Text] LIKE '%voll ist%'
				AND LogDate >= DATEADD(DAY, DATEDIFF(DAY, 1, GETDATE()), 0)
				AND LogDate < DATEADD(DAY, DATEDIFF(DAY, 0, GETDATE()), 0)

			INSERT INTO [USAGE].[dbo].[ErrorArchive] ( [ErrorDate], [ProcessInfo], [Text] )
			SELECT [LogDate], [ProcessInfo], [Text] FROM TempLogArchive
			WHERE 	[Text] LIKE '%Login failed%' 
				OR	[Text] LIKE '%filegroup is full%' 
				OR	[Text] LIKE '%voll ist%' 
				OR	[Text] LIKE '%failed%'
				OR	[Text] LIKE '%memory allocation failure%'
				OR	[Text] LIKE '%unable to run%'
				OR	[Text] LIKE '%terminating a system%'
				OR	[Text] LIKE '%Dispatcher was unable%'
				OR	[Text] LIKE '%insufficient system memory%'
			GROUP BY [Text], [LogDate], [ProcessInfo]
		END;

	/*
		| 11.1 Detecting SQL Server Deadlocks
	*/
	DROP TABLE IF EXISTS TempDeadlocks;
	CREATE TABLE TempDeadlocks (
		  [EventTime] DATETIME
		, [DeadlockGraph] XML
		);
	
		BEGIN			
			DECLARE @FileName NVARCHAR(250)
			SELECT @FileName = REPLACE(c.column_value, '.xel', '*.xel')
			FROM sys.dm_xe_sessions s
				JOIN sys.dm_xe_session_object_columns c ON s.address = c.event_session_address
			WHERE column_name = 'filename' AND s.name = 'system_health'

			INSERT INTO TempDeadlocks (EventTime, DeadlockGraph)
			SELECT CAST(event_data AS XML).value('(event/@timestamp)[1]','DATETIME') --AS event_timestamp
				, CAST(event_data AS XML).query('(event/data[@name="xml_report"]/value/deadlock)[1]') --AS deadlock_graph
			FROM sys.fn_xe_file_target_read_file (@FileName, NULL, NULL, NULL)
			WHERE object_name LIKE '%deadlock%'
			ORDER BY 1 DESC
    			OPTION(MAXDOP 1);
		END;
	END;
GO
