	--------------------------------------------------------------------------------
	USE msdb
	GO
	--------------------------------------------------------------------------------

	IF OBJECT_ID('dbo.sp_BlitzHealth') IS NULL
		EXEC ('CREATE PROCEDURE dbo.sp_BlitzHealth AS RETURN 0;');
	GO

	ALTER PROCEDURE dbo.sp_BlitzHealth
		  @EmailProfile NVARCHAR(10) = NULL
		, @EmailRecipients NVARCHAR(MAX) = NULL
		, @Help TINYINT = 0
		, @Debug TINYINT = 0
		, @Server VARCHAR(100) = NULL
		, @Version VARCHAR(10) = NULL OUTPUT
		, @VersionDate DATETIME = NULL OUTPUT
		, @VersionCheckMode BIT = 0 WITH EXECUTE AS CALLER
		, RECOMPILE
	AS
	BEGIN;
	SET NOCOUNT ON;
	SET ARITHABORT ON;
	SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
	
	SET LOCK_TIMEOUT 10000;

	SELECT @Version = '4.67', @VersionDate = '20201004 11:08:10';

	IF(@VersionCheckMode = 1)

	BEGIN
		RETURN;
	END;

	IF @Help = 1

	BEGIN

		PRINT '
			Version: 2010.400410 - Oktober, 2020
			Summary:
				Following solution introduced in order for SQL Server DBAs to streamline, prioritize, and simplify SQL Server monitoring.

			Version Updates:
				26.09.2020: | Added by Dmitry Spitsyn
					# 11.1 - Detecting SQL Server Deadlocks
				26.09.2020: | Added by Dmitry Spitsyn
					# 10.8 - Extend detecting SQL and None SQL Server CPU Pressure
				22.09.2020: | Added by Dmitry Spitsyn
					# 1.1 - Split check for Updates into 2nd step
				15.09.2020: | Added by Dmitry Spitsyn
					# 4.3-4.8 - Diagnose potential memory pressure
				08.09.2020: | Added by Dmitry Spitsyn
					# 10.9 - Diagnose potential CPU pressure
				29.08.2020: | Added by Dmitry Spitsyn
					# Overview of RAM usage
				03.08.2020: | Added by Dmitry Spitsyn
					# 10.8 - Extend Memory Allocation query
				31.07.2020: | Added by Dmitry Spitsyn
					# Detect Data files changes
				22.07.2020: | Added by Dmitry Spitsyn
					# Extend final result check according to flag
				17.07.2020: | Added by Dmitry Spitsyn
					# Extend No Error Message
				09.07.2020: | Added by Dmitry Spitsyn
					# Plan Cache Erased Recently deleted (10.7)
				06.07.2020: | Added by Dmitry Spitsyn
					# Definition critical sign in Mail Title
				30.06.2020: | Added by Dmitry Spitsyn
					# 4.2 - Determine Severity 17 - Fehler 1105
				28.06.2020: | Added by Dmitry Spitsyn
					# 10.8 - Determine Memory Allocation
				27.06.2020: | Added by Dmitry Spitsyn
					# 10.7 - Determine CPU Utilization > 60
					# 10.1 - Min. User connections = 100
				18.06.2020: | Added by Dmitry Spitsyn
					# 10.6 - Determine Statistics Updated Asynchronously
					# 10.5 - Determine Auto-Update Statistics Disabled
					# 10.4 - Determine Auto-Create Statistics Disabled
					# 10.3 - Determine Auto-Shrink Enabled
					# 10.2 - Determine Auto-Close Enabled
				15.06.2020: | Added by Dmitry Spitsyn
					# 10.1 - Determine user connections and connection memory
				01.06.2020: | Added by Dmitry Spitsyn
					# Format HTML Mail with CSS
				27.05.2020: | Added by Dmitry Spitsyn
					# 9.1 - Determine Errors Logged in the Default Trace
				18.05.2020: | Added by Dmitry Spitsyn
					# 8.4 - Determine sysoperator changes
				16.05.2020: | Added by Dmitry Spitsyn
					# 8.1 - Determine failed mails
					# 8.2 - Determine new Datenbank-E-Mail-Account
					# 8.3 - Determine new Datenbank-E-Mail-Profile
				15.05.2020: | Added by Dmitry Spitsyn
					# 7.1 - Determine failed jobs
				12.05.2020: | Added by Dmitry Spitsyn
					# 6.1 - Capture errors in SQL Agent Error Log
				10.05.2020: | Added by Dmitry Spitsyn
					# 5.1 - Determine deactivated jobs
				04.05.2020: | Added by Dmitry Spitsyn
					# 07.05.2020 - Mails will only be sent if @Flag = 1 (disabled)
					# 07.05.2020 - Logins errors explicitly as "current" errors defined
				04.05.2020: | Added by Dmitry Spitsyn
					# 4.1 - Determine failed logins
					# 3.1 - Check Volume free space for all LUNS that have database files on the current instance
				03.05.2020: | Added by Dmitry Spitsyn
					# 2.1 - Prove local full backups user databases within past 6 hours
					# 2.2 - Prove local full backups system databases within past 24 hours
					# 1.1 - Ensure Latest SQL Server Service Packs and Hotfixes are Installed

			SQL Server Version: 2012/2016/2017/2019
		';

	RETURN
	END

	--------------------------------------------------------------------------------
	--| HTML Preparation
	--------------------------------------------------------------------------------
	--| Declaring Variables
	--------------------------------------------------------------------------------
	DECLARE @TableHTML VARCHAR(MAX)
		, @InternTableHTML VARCHAR(MAX)
		, @dExecutionDate DATETIME = GETDATE()
		, @CUDate DATETIME = '20200910 00:00:00'
		, @Overdue DATETIME
		, @FromDate DATETIME
		, @ToDate DATETIME
		, @StringToExecute NVARCHAR(4000)
		, @ServerName VARCHAR(100)
		, @SetMailSubject VARCHAR(100)
		, @sRestartSqlServer NVARCHAR(255) = 'Letzter Restart des SQL Servers: %s um %s Uhr<br>'
		, @sRestartSqlDate NVARCHAR(255) = (SELECT FORMAT(create_date, 'D', 'de-de') FROM sys.databases WHERE database_id = 2)
		, @sRestartSqlTimePoint NVARCHAR(255) = (SELECT CONVERT(VARCHAR(8), create_date, 108) FROM sys.databases WHERE database_id = 2)
		, @ActiveClusterPartner NVARCHAR(128) = (SELECT NodeName FROM sys.dm_os_cluster_nodes WHERE is_current_owner = 1)
		, @CPUPressure DECIMAL(20,2) = (SELECT CAST(100.0 * SUM(signal_wait_time_ms) / SUM(wait_time_ms) AS NUMERIC(20,2)) FROM sys.dm_os_wait_stats)
		, @sNeustartBetriebsystem NVARCHAR(255) = 'Letzter Start des Betriebsystems: %s um %s Uhr<br>'
		, @sNeustartBetriebsystemDatum NVARCHAR(255)
		, @sNeustartBetriebsystemPoint NVARCHAR(255) 
		, @sAktuellerBesitzer NVARCHAR(255) = 'Aktueller Besitzer der SQL Server-Failoverclusterressource: %s<br>'
		, @sReportErstellt NVARCHAR(255) = 'Report V.%s erstellt am %s um %s Uhr<br>'
		, @sDatabaseBackupState NVARCHAR(256) = 'Die vollständige Datenbanksicherung %s erfolgte zuletzt am %s.'
		, @sDatabaseFullSystem NVARCHAR(256) = 'Die System Datenbank %s wurde zuletzt am %s gesichert.'
		, @sMountPointSize NVARCHAR(256) = 'Festplatte %s hat weniger als %s GB Speicherplatz frei.'
		, @sCPUSQLUtilization NVARCHAR(256) = 'Hohe SQL CPU-Auslastung von %s Prozent wurde am %s um %s Uhr festgestellt.'
		, @sNoneCPUSQLUtilization NVARCHAR(256) = 'Hohe Betriebssystem CPU-Auslastung von %s Prozent wurde am %s um %s Uhr festgestellt.'
		, @sCPUPressure NVARCHAR(256) = 'Die aktuellen Wartezeiten betragen %s Prozent und referenzieren auf Wartung eines Threads durch eine CPU. Dies ist ein Indikator für den CPU-Druck.<br>'
		, @sSpeicherauslastung NVARCHAR(MAX) = 'Indikator weist auf unzureichende physischen Speicher (%s MB) am %s um %s Uhr aus. Mehrere Faktoren können zu Verschlechterung der Speicherleistung führen.<br>'
		, @sJobDeaktivated NVARCHAR(256) = 'Der Job %s ist seit %s um %s Uhr deaktiviert.'
		, @sLoginError NVARCHAR(256) = 'Fehlgeschlagene Anmeldung am %s um %s'
		, @sSeverityError NVARCHAR(256) = 'Unzureichende Ressourcen festgestellt am %s um %s'
		, @sErrorState NVARCHAR(256) = 'Fehler am %s um %s aufgetretten: <br>%s'
		, @sJobError NVARCHAR(MAX) = 'Der Job %s ist am %s um %s Uhr fehlgeschlagen.<br>'
		, @sMailError NVARCHAR(256) = 'Die Datenbank-E-Mail hat versucht, die E-Mail am %s um %s zu senden, aber der SMTP-Mailserver war nicht erreichbar.<br>Die Ursache des Problems muss identifiziert werden.'
		, @sUserConnections NVARCHAR(256) = 'Hohe Anzahl von Benutzerverbindungen (%i) und Arbeitsspeicherverwendung (%s MB).<br>Dies kann nicht nur ein Leistungsproblem, sondern auch ein Sicherheitsproblem sein.'
		, @aUserConnections NVARCHAR(256) = '%i maximale gleichzeitigen Benutzerverbindungen innerhalb letzten 24 Stunden registriert am %s'
		, @sMailProfile NVARCHAR(256) = 'Ein neues E-Mail-Profile wurde am %s um %s vom % erstellt.'
		, @sMailAccount NVARCHAR(256) = 'Ein neues E-Mail-Konto wurde am %s um %s vom %s erstellt.'
		, @sOperatorChanges NVARCHAR(256) = 'Der Operatorstatus %s wurde aktiviert.<br>Die Ursache für diese Änderungen ist unbekannt.'
		, @sApplicationError NVARCHAR(256) = 'Applikation: %s, %s <br>%s'
		, @sSessionError NVARCHAR(256) = 'Abbruch der Benutzersession %s am %s um %s'
		, @sUnableRunSystemTask NVARCHAR(MAX) = 'Folgender Fehler ist %i Mal am %s zwischen %s und %s aufgetretten: <br>%s'
		, @DataFileChanges NVARCHAR(MAX) = 'Datendatei %s wurde am %s um %s automatisch gewachsen.'
		, @InstanceCount NVARCHAR(MAX)
		, @sInstanceCount NVARCHAR(256) = 'Auf dem Server %s sind %s SQL Instanzen installiert:<br>'
		, @account_name NVARCHAR(10) = 'elv_bpaus'
		, @BetaVersion BIT = 0
		, @FileName NVARCHAR(250)
		, @sBetaVersion NVARCHAR(256) = '<br>Beta Version: ' + @Version + ' | ' + CONVERT(VARCHAR(20), @VersionDate)
		, @curr_tracefilename NVARCHAR(500)
		, @base_tracefilename NVARCHAR(500)
		, @TimePointMaxUserConnections VARCHAR(64)
		, @MaxUserConnections INT
		, @CounterName NVARCHAR(64)
		, @WarningSignSubject NVARCHAR(4)
		, @HTMLStyle NVARCHAR(MAX) = ''
		, @RootPath NVARCHAR(256)
		, @LogoPath NVARCHAR(256)
		, @ErrorPath NVARCHAR(256)
		, @WarningPath NVARCHAR(256)
		, @TraceFileIssue BIT
		, @Flag TINYINT = 0
		, @indx INT
	--------------------------------------------------------------------------------
	--| END Declaring Variables
	--------------------------------------------------------------------------------
	IF (
		  @EmailProfile IS NULL
		OR @EmailRecipients IS NULL
		)
		BEGIN
			RAISERROR('Es wurde keine Aktion für diese gespeicherte Prozedur ausgewählt.', 0, 1) WITH NOWAIT
			RETURN;
		END;

	SET @ServerName = ISNULL(@Server, @@SERVERNAME);

	IF (SELECT CONVERT(sysname, SERVERPROPERTY('InstanceName'))) LIKE '%DEV%'
		BEGIN
			SET @RootPath = 'H:\MSSQL14.ELVISDEV\'
		END
	ELSE IF (SELECT CONVERT(sysname, SERVERPROPERTY('InstanceName'))) LIKE '%REF%'
		BEGIN
			SET @RootPath = 'I:\MSSQL14.ELVISREF\'
		END
	ELSE IF (SELECT CONVERT(sysname, SERVERPROPERTY('InstanceName'))) LIKE '%PRO%'
		BEGIN
			SET @RootPath = 'Q:\MSSQL14.ELVISPRO\'
		END
	
	SET @LogoPath = @RootPath + 'MSSQL\REPORTS\images\intellinova_logo5.png'

	SET @sNeustartBetriebsystemDatum = (SELECT FORMAT(DATEADD(SECOND, (ms_ticks/1000)*(-1), @dExecutionDate), 'D', 'de-de') FROM sys.dm_os_sys_info)
	SET @sNeustartBetriebsystemPoint = (SELECT CONVERT(VARCHAR(8), (DATEADD(SECOND, (ms_ticks/1000)*(-1), @dExecutionDate)), 108) FROM sys.dm_os_sys_info)
	SET @FromDate = DATEADD(hh, -24, @dExecutionDate)
	SET @ToDate = @dExecutionDate
	SET @Overdue = (SELECT DATEADD(DAY, 21, @CUDate))

	DROP TABLE IF EXISTS #UserConnections;
	CREATE TABLE #UserConnections (
		  CounterName NVARCHAR(64)
		, MaxUserConnections INT
		, TimePoint VARCHAR(64)
		)
		BEGIN
			INSERT INTO #UserConnections (CounterName, MaxUserConnections, TimePoint)
			SELECT counter_name AS [Counter Name]
				, cntr_value AS [Counter Value]
				, (
					SELECT TOP 1 FORMAT(CheckDate, 'D', 'de-de') + ' ' + CONVERT(VARCHAR(8), CheckDate, 108)
					FROM USAGE.[dbo].[BlitzFirst_PerfmonStats] WHERE cntr_value IN (
						SELECT MAX(cntr_value) FROM USAGE.[dbo].[BlitzFirst_PerfmonStats]
						WHERE counter_name = 'User Connections'
						)
					ORDER BY CheckDate DESC
					) AS [Check Point]
			FROM USAGE.[dbo].[BlitzFirst_PerfmonStats]
			WHERE counter_name IN (
				  'Connection Memory (KB)'
				, 'User Connections'
				) AND CheckDate IN (
					SELECT TOP 1 CheckDate
					FROM USAGE.[dbo].[BlitzFirst_PerfmonStats] WHERE cntr_value IN (
						SELECT MAX(cntr_value) FROM USAGE.[dbo].[BlitzFirst_PerfmonStats]
						WHERE counter_name = 'User Connections'
						)
					ORDER BY CheckDate DESC
					)
		END;
	
	SELECT @MaxUserConnections = (
		SELECT TOP 1 cntr_value
		FROM USAGE.[dbo].[BlitzFirst_PerfmonStats] WHERE cntr_value IN (
			SELECT MAX(cntr_value) FROM USAGE.[dbo].[BlitzFirst_PerfmonStats]
			WHERE counter_name = 'User Connections'
			)
		ORDER BY CheckDate ASC
		)

	SET @TimePointMaxUserConnections = (SELECT CONVERT(VARCHAR(64), TimePoint) FROM #UserConnections WHERE CounterName = 'User Connections')
	SET @CounterName = (SELECT MaxUserConnections/1024 FROM #UserConnections WHERE CounterName = 'Connection Memory (KB)')

	DROP TABLE IF EXISTS #Instances;
	CREATE TABLE #Instances (
          Instance_Number NVARCHAR(MAX)
		, Instance_Name NVARCHAR(MAX)
		, Data_Field NVARCHAR(MAX)
        );

	INSERT INTO #Instances (Instance_Number, Instance_Name, Data_Field)
	EXEC master.sys.xp_regread 
		  @rootkey = 'HKEY_LOCAL_MACHINE'
		, @key = 'SOFTWARE\Microsoft\Microsoft SQL Server'
		, @value_name = 'InstalledInstances'

	IF (SELECT COUNT(*) FROM #Instances) > 1
		BEGIN
            SELECT @InstanceCount = COUNT(*) FROM #Instances
		END

	SET @HTMLStyle +=
		
		-- 
		+ N'<style type="text/css">'

		+ N'table.intern thead	{
				background-color: #FFFFFF;
				}'

		+ N'table.intern caption	{
				background-color: #FFFFFF;
				font-size: 12px;
				font-weight: 400;
				}'

		+ N'table.intern	{
				background-color: #FFFFFF;
				border-collapse: collapse;
				font-family: Arial, Verdana, Tahoma;
				}'

		+ N'table.intern th	{
				text-align: center;
				}'

		+ N'table.intern tbody td	{
				font-size: 10px;
				}'

		+ N'table.intern td	{
				text-align: center;
				}'
				
		+ N'table.intern tr	{
				text-align: center;
				}'

		-- Counter and Name titles
		+ N'table.intern thead th	{
				font-size: 12px;
				font-weight: 400;
				color: #000000;
				background-color: #FFFFFF;
				text-align: left;
			}'

		+ N'table.technZustand	{
				background-color: white;
				border-collapse: collapse;
				border-color: white;
				color: black;
				font-family: Arial, Verdana, Tahoma;
				font-size: 12px;
				font-weight: 400;
				vertical-align: middle;
				}'
		
		-- 
		+ N'table.technZustand th	{
                background-color: #F8F8F8;
                font-weight: 700;
                height: 20px;
                padding-left: 5px;
                text-align: left;
				}'

		-- Format Title of Report
        + N'table.technZustandTitle td	{
				font-family: Arial, Verdana, Tahoma;
				font-size: 14px;
				color: #5C5C5C;
				font-weight: bold;
                padding: 5px 5px 10px 0px;
				}'
		
		-- 
        + N'table.technZustandTitle tr {
				}'

		-- Format Title of Table
        + N'table.technZustandColNames td	{
				font-family: Arial, Verdana, Tahoma;
				font-size: 12px;
				color: #5C5C5C;
				font-weight: 700;
				background-color: #CCCCCC;
                padding: 5px 5px 5px 5px;
				text-align: center; 
				vertical-align: middle;
				border-color: #D3D3D3;
				border-collapse: collapse;
				}'

        -- Format Table Content
		+ N'table.technZustandContent td	{
				font-family: Arial, Verdana, Tahoma;
				font-size: 11px;
				color: #000000;
				background-color: #FFFFFF;
				font-weight: normal;
                padding: 5px 5px 5px 5px;
				text-align: left; 
				vertical-align: middle;
				border-color: #D3D3D3;
				border-collapse: collapse;
				}'
		
        -- Format Table Content (Yellow sign)
		+ N'table.technZustandContent th	{
				font-family: Arial, Verdana, Tahoma;
				font-size: 11px;
				font-weight: bold;
				color: #FF4500;
				background-color: #FFFF00;
                padding: 5px 5px 5px 5px;
				text-align: center;
				vertical-align: middle;
				border-color: #D3D3D3;
				border-collapse: collapse;
				}'

		-- End Format
		+ N'</style>';

	DROP TABLE IF EXISTS #TrafficLight;
	CREATE TABLE #TrafficLight (
		  [Flag] TINYINT
		, [WarningSignSubject] NVARCHAR(4)
		)
		BEGIN
			INSERT INTO #TrafficLight (
				  [Flag]
				, [WarningSignSubject]
				)
			VALUES ( 0, 'GRÜN' ), ( 1, 'GELB' ), ( 2, 'ROT' );
		END;

	DROP TABLE IF EXISTS #GetTrafficLight;
	CREATE TABLE #GetTrafficLight (
		  [ID] INT
		, [Flag] TINYINT
		)

	DROP TABLE IF EXISTS #TraceGetTable;
	CREATE TABLE #TraceGetTable (
		  TextData NVARCHAR(4000)
		, DatabaseName NVARCHAR(256)
		, EventClass INT
		, Severity INT
		, StartTime DATETIME
		, EndTime DATETIME
		, Duration BIGINT
		, NTUserName NVARCHAR(256)
		, NTDomainName NVARCHAR(256)
		, HostName NVARCHAR(256)
		, ApplicationName NVARCHAR(256)
		, LoginName NVARCHAR(256)
		, DBUserName NVARCHAR(256)
		);

	/*	
		| (1.1) Ensure Latest SQL Server Service Packs and Hotfixes are Installed
	*/
	DROP TABLE IF EXISTS #Versions;
	CREATE TABLE #Versions (
		  [Name] NVARCHAR(28)
		, [Service Pack] NVARCHAR(8)
	)
	BEGIN
		INSERT INTO #Versions (
			  [Name]
			, [Service Pack]
			)
		SELECT
			CASE
				WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('ProductVersion')) LIKE '14.0%' THEN 'SQL Server 2017'
				ELSE 'unknown' END
			, CASE																						-- | Build			| Extended support ends
				WHEN CONVERT(VARCHAR(128), SERVERPROPERTY ('ProductVersion')) LIKE '14.0%' THEN 'CU22'	-- | (14.0.3356.20	| 2027/10/12)
				ELSE 'unknown' END;
	END;

	SET @TableHTML = @HTMLStyle +
	'
	<main>
	<table class = "technZustandTitle" height = "50" cellSpacing = "0" cellPadding = "0" width = "100%" border = "0">
		<tr>
			<td>

				Technischer Zustand ' + CONVERT(VARCHAR(100), @SERVERNAME) +
				CASE WHEN @BetaVersion = 1 THEN @sBetaVersion ELSE '' END +

			'</td>

			<td align = "right" width = "50%" bgcolor = "#FFFFFF" height = "50" style = "padding: 5px 5px 5px 5px;">

				<a href = "" title = ""><img src = "cid:intellinova_logo5.png" width = "50" height = "50"></a>

			</td>
		</tr>
	</table>

	<table class = "technZustandColNames" height = "50" cellSpacing = "0" cellPadding = "0" width = "100%" border = "1">
		<tr>
			<td width = "20%" height = "50">
				Name
			</td>
			<td width = "10%" height = "50">
				IST-Zustand
			</td>
			<td width = "10%" height = "50">
				SOLL-Zustand
			</td>
			<td width = "10%" height = "50">
				Ziel erreicht
			</td>
			<td width = "50%" height = "50">
				Details
			</td>
		</tr>
	</table>

	<table class = "technZustandContent" height = "50" cellSpacing = "0" cellPadding = "0" width = "100%" border = "1">
		<tr>
			<td width = "50%" height = "30" colspan = "4">' +
				
				'Instanzname: ''' + ISNULL(CAST(SERVERPROPERTY('InstanceName') AS NVARCHAR(100)), '(default instance)') + '''' +

			'</td>
			<td width = "50%" height = "30">' +

				FORMATMESSAGE(@sNeustartBetriebsystem, @sNeustartBetriebsystemDatum, @sNeustartBetriebsystemPoint) +
				FORMATMESSAGE(@sRestartSqlServer, @sRestartSqlDate, @sRestartSqlTimePoint)	+
				FORMATMESSAGE(@sAktuellerBesitzer, @ActiveClusterPartner) +
				FORMATMESSAGE(@sInstanceCount, @ActiveClusterPartner, @InstanceCount) +
				FORMATMESSAGE(@sReportErstellt, @Version, FORMAT(@dExecutionDate, 'D', 'de-de'), CONVERT(VARCHAR(8), @dExecutionDate, 108)) +

			'</td>
		</tr>'

	/*
		| (2.1) Prove local full backups user databases within past 6 hours
	*/
	DROP TABLE IF EXISTS #LastFullBackup6;
	CREATE TABLE #LastFullBackup6 (
		  [DatabaseName] VARCHAR(50)
		, [LastFullBackup] DATETIME
		, [NoBackupSinceHours] INT
		);

	INSERT INTO #LastFullBackup6
	SELECT
		  msdb.dbo.backupset.database_name
		, MAX(msdb.dbo.backupset.backup_finish_date)
		, DATEDIFF(hh, MAX(msdb.dbo.backupset.backup_finish_date), @dExecutionDate)
	FROM msdb.dbo.backupset
	WHERE msdb.dbo.backupset.type = 'D'
		AND msdb.dbo.backupset.database_name NOT IN ('master','msdb','model','usage','DISTRIBUTION')
	GROUP BY msdb.dbo.backupset.database_name
	HAVING (MAX(msdb.dbo.backupset.backup_finish_date) < DATEADD(hh, -6, @dExecutionDate))
		AND (MAX(msdb.dbo.backupset.backup_finish_date) > DATEADD(hh, -24, @dExecutionDate))

	IF 6 < (SELECT TOP 1 (DATEDIFF(hh, [LastFullBackup], @dExecutionDate)) FROM #LastFullBackup6)

		SET @Flag = 1
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (21, @Flag);

		BEGIN
			SELECT @TableHTML =  @TableHTML +
				'<tr>
					<td width = "20%" height = "30">' +
				
						'Fehlt Vollsicherung (Benutzerdatenbanken)' +
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
				
						'-' +
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
				
						'Warnung'  + 
				
					'</td>' +
					'<th width = "10%" height = "30">' + 
				
					'</th>' +
					'<td width = "50%" height = "30">' + 
						
						FORMATMESSAGE(@sDatabaseBackupState, '''' + CAST([DatabaseName] AS VARCHAR(50)) + '''', FORMAT([LastFullBackup], 'D', 'de-de')) +
					
					'</td>
				</tr>'
			FROM #LastFullBackup6
		END;

	/*
		| (2.2) Prove local full backups system databases within past 72 hours
	*/
	DROP TABLE IF EXISTS #LastFullBackup72;
	CREATE TABLE #LastFullBackup72 (
		  [DatabaseName] VARCHAR(50)
		, [LastFullBackup] DATETIME
		, [NoBackupSinceHours] INT
		);

		INSERT INTO #LastFullBackup72
		SELECT
			  msdb.dbo.backupset.database_name
			, MAX(msdb.dbo.backupset.backup_finish_date)
			, DATEDIFF(hh, MAX(msdb.dbo.backupset.backup_finish_date), @dExecutionDate)
		FROM msdb.dbo.backupset
		WHERE msdb.dbo.backupset.type = 'D'
			AND DB_NAME() IN ('master','msdb','model','usage','DISTRIBUTION')
		GROUP BY msdb.dbo.backupset.database_name
		HAVING (MAX(msdb.dbo.backupset.backup_finish_date) < @FromDate )
			AND (MAX(msdb.dbo.backupset.backup_finish_date) > DATEADD(hh, -72, @dExecutionDate))

	IF 72 < (SELECT TOP 1 (DATEDIFF(hh, [LastFullBackup], @dExecutionDate)) FROM #LastFullBackup72)

		SET @Flag = 1
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (21, @Flag);

		BEGIN
			SELECT @TableHTML =  @TableHTML +
				'<tr>
					<td width = "20%" height = "30">' + 
				
						'Fehlt Vollsicherung (System Datenbanken)' + 
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
				
						'-' + 
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
				
						'Warnung'  + 
					
					'</td>' +
					'<th width = "10%" height = "30">' + 
				
					'</th>' +
					'<td width = "50%" height = "30">' + 
				
						FORMATMESSAGE(@sDatabaseFullSystem, '''' + CAST([DatabaseName] AS VARCHAR(50)) + '''', FORMAT([LastFullBackup], 'D', 'de-de')) +
					
					'</td>' +
				'</tr>'
			FROM #LastFullBackup72
		END;

	/*
		| (3.1) Prove free space on all mount points
		| Check for Volume size for all LUNS that have database files on the current instance
	*/
	DROP TABLE IF EXISTS #FreeSpace;
	CREATE TABLE #FreeSpace (
		  [ValumeName] VARCHAR(50)
		, [AvailableSize] DECIMAL(4,2)
		);

		INSERT INTO #FreeSpace
		SELECT DISTINCT vs.volume_mount_point
			, CONVERT(DECIMAL(18,2), vs.available_bytes/1073741824.0)
		FROM sys.master_files AS F WITH (NOLOCK)
			CROSS APPLY sys.dm_os_volume_stats(f.database_id, F.[file_id]) AS VS
		WHERE (CONVERT(DECIMAL(18,2), VS.available_bytes/1073741824.0)) BETWEEN 2 AND 5

	IF EXISTS (SELECT 1 FROM #FreeSpace)

		SET @Flag = 1
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (31, @Flag);

		BEGIN
			SELECT @TableHTML =  @TableHTML +
				'<tr>
					<td width = "20%" height = "30">' +
				
						'Mount Point freier Speicherplatz' +
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
				
						'Warnung' +
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
				
						'-'  +
					
					'</td>' +
					'<th width = "10%" height = "30">' +
				
					'</th>' +
					'<td width = "50%" height = "30">' +
					
						FORMATMESSAGE(@sMountPointSize, '''' + CAST([ValumeName] AS VARCHAR(50)) + '''', CAST([AvailableSize] AS VARCHAR(50))) +
					
					'</td>' +
				'</tr>'
			FROM #FreeSpace
		END;

	/*
		| (3.2) Prove critical free space on all mount points (< 2 GB)
		| Check for Volume size for all LUNS that have database files on the current instance
	*/
	DROP TABLE IF EXISTS #FreeSpaceCritical;
	CREATE TABLE #FreeSpaceCritical (
		  [ValumeName] VARCHAR(50)
		, [AvailableSize] DECIMAL(4,2)
		);

		INSERT INTO #FreeSpaceCritical
		SELECT DISTINCT vs.volume_mount_point, CONVERT(DECIMAL(18,2), vs.available_bytes/1073741824.0)
		FROM sys.master_files AS F WITH (NOLOCK)
			CROSS APPLY sys.dm_os_volume_stats(f.database_id, F.[file_id]) AS VS
		WHERE (CONVERT(DECIMAL(18,2), VS.available_bytes/1073741824.0)) < 2

	IF EXISTS (SELECT 1 FROM #FreeSpaceCritical)

		SET @Flag = 2
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (32, @Flag);

		BEGIN
			SELECT @TableHTML =  @TableHTML +
				'<tr>
					<td width = "20%" height = "30">' + 
				
						'Mount Point freier Speicherplatz' + 
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
				
						'Warnung' +
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
					
						'-'  +
					
					'</td>' +
					'<th style = "background-color: #FF0000" width = "10%" height = "30">' +

					'</th>' +
					'<td width = "50%" height = "30">' + 
					
						FORMATMESSAGE(@sMountPointSize, '''' + CAST([ValumeName] AS VARCHAR(50)) + '''', CAST([AvailableSize] AS VARCHAR(50))) +
					
					'</td>' +
				'</tr>'
			FROM #FreeSpaceCritical
		END;

	/*
		| (3.3) Check data files growth
	*/
	IF @BetaVersion = 1
	BEGIN
		DROP TABLE IF EXISTS #DataFileAutoGrow;
		CREATE TABLE #DataFileAutoGrow (
			  [DatabaseName] NVARCHAR(64)
			, [FileName] NVARCHAR(64)
			, [StartTime] DATETIME
			, [StepNumber] NVARCHAR(256)
			)
			
			SELECT @curr_tracefilename = [path] FROM sys.traces WHERE is_default = 1;
			SET @curr_tracefilename = REVERSE(@curr_tracefilename);

			IF @curr_tracefilename IS NOT NULL
				BEGIN
					SELECT @indx = PATINDEX('%\%', @curr_tracefilename) ;
					SET @curr_tracefilename = REVERSE(@curr_tracefilename) ;
					SET @base_tracefilename = LEFT( @curr_tracefilename, LEN(@curr_tracefilename) - @indx) + '\log.trc';
				END;
			
		BEGIN
			INSERT INTO #DataFileAutoGrow (
					[DatabaseName]
				, [FileName]
				, [StartTime]
				, [StepNumber]
				)
			SELECT
					DatabaseName
				, [Filename]
				, StartTime
				, SUBSTRING(RIGHT(ApplicationName, 2), 1, 1) AS [StepNumber]
			FROM ::fn_trace_gettable(@base_tracefilename, DEFAULT) t
				INNER JOIN sys.trace_events AS te ON t.EventClass = te.trace_event_id
			WHERE(trace_event_id >= 92 AND trace_event_id <= 95)
		END;

		IF EXISTS (SELECT 1 FROM #DataFileAutoGrow WHERE [StartTime] > @FromDate
			AND (EXISTS (SELECT 1 FROM #FreeSpaceCritical) OR EXISTS (SELECT 1 FROM #FreeSpace)))

			SET @Flag = 1
			INSERT INTO #GetTrafficLight ([ID], [Flag])
			VALUES (33, @Flag);

			BEGIN
				SELECT @TableHTML =  @TableHTML +
					'<tr>
						<td width = "20%" height = "30">' +
				
							'Übersicht über die Aktivitäten des automatischen [' + CAST([DatabaseName] AS NVARCHAR(64)) + '] Datenbank Wachstums' +
					
						'</td>
						<td style = "text-align: center" width = "10%" height = "30">' +
				
							'Warnung' +
					
						'</td>
						<td style = "text-align: center" width = "10%" height = "30">' +
					
							'-'  +
					
						'</td>' +
						'<th width = "10%" height = "30">' +
				
						'</th>' +
						'<td width = "50%" height = "30">' + 
					
							FORMATMESSAGE(@DataFileChanges, '''' + CAST([FileName] AS NVARCHAR(64)) + '''', FORMAT([StartTime], 'D', 'de-de'), CONVERT(VARCHAR(8), [StartTime], 108)) +
					
						'</td>' +
					'</tr>'
				FROM #DataFileAutoGrow
				WHERE StartTime > @FromDate
				ORDER BY StartTime DESC
			END;
	END;

	/*
		| (4.1) Determine failed logins
	*/
	IF EXISTS (
		SELECT 1 FROM [USAGE].[dbo].[ErrorArchive] 
		WHERE [ErrorDate] >= DATEADD(DAY, DATEDIFF(DAY, 1, @dExecutionDate), 0)
			AND [Text] LIKE '%login failed%'
			)

		SET @Flag = 1
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (41, @Flag);

		BEGIN
			SELECT TOP 1 @TableHTML =  @TableHTML +
				'<tr>
					<td width = "20%" height = "30">' + 
					
						FORMATMESSAGE(@sLoginError, FORMAT([ErrorDate], 'D', 'de-de'), CONVERT(VARCHAR(8), [ErrorDate], 108)) +
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
				
						'Warnung' + 
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
				
						'-'  +
					
					'</td>' +
					'<th width = "10%" height = "30">' +
				
					'</th>' +
					'<td width = "50%" height = "30">' +
				
						[Text] +
					
					'</td>' +
				'</tr>'
			FROM [USAGE].[dbo].[ErrorArchive]
			WHERE [ErrorDate] >= DATEADD(DAY, DATEDIFF(DAY, 1, @dExecutionDate), 0)
				AND [Text] LIKE '%login failed%'
		END;

	/*
		| (4.2) Determine Severity 17 - Fehler 1105
	*/
	IF EXISTS (	
		SELECT 1 FROM [USAGE].[dbo].[ErrorArchive] 
		WHERE [ErrorDate] >= DATEADD(DAY, DATEDIFF(DAY, 1, @dExecutionDate), 0)
			AND [Text] LIKE '%filegroup is full%' OR [Text] LIKE '%voll ist%'
		)

		SET @Flag = 1
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (42, @Flag);

		BEGIN
			SELECT @TableHTML =  @TableHTML +
				'<tr>
					<td width = "20%" height = "30">' + 
					
						FORMATMESSAGE(@sSeverityError, FORMAT([ErrorDate], 'D', 'de-de'), CONVERT(VARCHAR(8), [ErrorDate], 108)) +
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
				
						'Fehler' + 
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
				
						'-'  +
					
					'</td>' +
					'<th width = "10%" height = "30">' +
				
					'</th>' +
					'<td width = "50%" height = "30">' +
				
						[Text] +
					
					'</td>' +
				'</tr>'
			FROM [USAGE].[dbo].[ErrorArchive]
			WHERE [ErrorDate] >= DATEADD(DAY, DATEDIFF(DAY, 1, @dExecutionDate), 0)
				AND [Text] LIKE '%filegroup is full%' OR [Text] LIKE '%voll ist%'
		END;

	/*
		| (4.3) Error message "SQL Server was unable to run a new system task"
	*/
	IF EXISTS (	
		SELECT 1 FROM [USAGE].[dbo].[ErrorArchive] 
		WHERE [ErrorDate] >= DATEADD(DAY, DATEDIFF(DAY, 1, @dExecutionDate), 0)
			AND [Text] LIKE '%unable to run%'
		)

		SET @Flag = 2
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (43, @Flag);

		BEGIN
			SELECT DISTINCT @TableHTML =  @TableHTML +
				'<tr>
					<td width = "20%" height = "30">' + 
					
						'Performance SQL Server' +
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
				
						'Fehler' + 
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
				
						'-'  +
					
					'</td>' +
					'<th style = "background-color: #FF0000" width = "10%" height = "30">' +
				
					'</th>' +
					'<td width = "50%" height = "30">' +
						
						FORMATMESSAGE(@sUnableRunSystemTask
							, (SELECT COUNT(Text) FROM USAGE.dbo.TempLogArchive WHERE [Text] LIKE '%unable to run%'), FORMAT([LogDate], 'D', 'de-de')
							, (SELECT TOP 1 CONVERT(VARCHAR(8), [LogDate], 108) FROM USAGE.dbo.TempLogArchive WHERE [Text] LIKE '%unable to run%' ORDER BY LogArchiveID ASC)
							, (SELECT TOP 1 CONVERT(VARCHAR(8), [LogDate], 108) FROM USAGE.dbo.TempLogArchive WHERE [Text] LIKE '%unable to run%' ORDER BY LogArchiveID DESC), [Text]) +

					'</td>' +
				'</tr>'
			FROM USAGE.dbo.TempLogArchive
			WHERE [LogDate] >= DATEADD(DAY, DATEDIFF(DAY, 1, @dExecutionDate), 0)
				AND [Text] LIKE '%unable to run%'
		END;

	/*
		| (4.4) Error message 28709
	*/
	IF EXISTS (	
		SELECT 1 FROM [USAGE].[dbo].[ErrorArchive] 
		WHERE [ErrorDate] >= DATEADD(DAY, DATEDIFF(DAY, 1, @dExecutionDate), 0)
			AND [Text] LIKE '%28709%'
		)

		SET @Flag = 2
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (44, @Flag);

		BEGIN
			SELECT DISTINCT @TableHTML =  @TableHTML +
				'<tr>
					<td width = "20%" height = "30">' + 
					
						'Performance SQL Server' +
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
				
						'Fehler' + 
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
				
						'-'  +
					
					'</td>' +
					'<th style = "background-color: #FF0000" width = "10%" height = "30">' +
				
					'</th>' +
					'<td width = "50%" height = "30">' +
						
						FORMATMESSAGE(@sUnableRunSystemTask
							, (SELECT COUNT(Text) FROM USAGE.dbo.TempLogArchive WHERE [Text] LIKE '%28709%'), FORMAT([LogDate], 'D', 'de-de')
							, (SELECT TOP 1 CONVERT(VARCHAR(8), [LogDate], 108) FROM USAGE.dbo.TempLogArchive WHERE [Text] LIKE '%28709%' ORDER BY LogArchiveID ASC)
							, (SELECT TOP 1 CONVERT(VARCHAR(8), [LogDate], 108) FROM USAGE.dbo.TempLogArchive WHERE [Text] LIKE '%28709%' ORDER BY LogArchiveID DESC), [Text]) +

					'</td>' +
				'</tr>'
			FROM USAGE.dbo.TempLogArchive
			WHERE [LogDate] >= DATEADD(DAY, DATEDIFF(DAY, 1, @dExecutionDate), 0)
				AND [Text] LIKE '%Failed to start%'
		END;

	/*
		| (4.5) Error message "SQL Server is terminating a system or background task"
	*/
	IF EXISTS (	
		SELECT 1 FROM [USAGE].[dbo].[ErrorArchive] 
		WHERE [ErrorDate] >= DATEADD(DAY, DATEDIFF(DAY, 1, @dExecutionDate), 0)
			AND [Text] LIKE '%terminating a system%'
		)

		SET @Flag = 2
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (45, @Flag);

		BEGIN
			SELECT DISTINCT @TableHTML =  @TableHTML +
				'<tr>
					<td width = "20%" height = "30">' + 
					
						'Performance SQL Server' +
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
				
						'Fehler' + 
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
				
						'-'  +
					
					'</td>' +
					'<th style = "background-color: #FF0000" width = "10%" height = "30">' +
				
					'</th>' +
					'<td width = "50%" height = "30">' +
						
						FORMATMESSAGE(@sUnableRunSystemTask
							, (SELECT COUNT(Text) FROM USAGE.dbo.TempLogArchive WHERE [Text] LIKE '%terminating a system%'), FORMAT([LogDate], 'D', 'de-de')
							, (SELECT TOP 1 CONVERT(VARCHAR(8), [LogDate], 108) FROM USAGE.dbo.TempLogArchive WHERE [Text] LIKE '%terminating a system%' ORDER BY LogArchiveID ASC)
							, (SELECT TOP 1 CONVERT(VARCHAR(8), [LogDate], 108) FROM USAGE.dbo.TempLogArchive WHERE [Text] LIKE '%terminating a system%' ORDER BY LogArchiveID DESC), [Text]) +

					'</td>' +
				'</tr>'
			FROM USAGE.dbo.TempLogArchive
			WHERE [LogDate] >= DATEADD(DAY, DATEDIFF(DAY, 1, @dExecutionDate), 0)
				AND [Text] LIKE '%terminating a system%'
		END;

	/*
		| (4.6) Error message "Dispatcher was unable to create new thread"
	*/
	IF EXISTS (	
		SELECT 1 FROM [USAGE].[dbo].[ErrorArchive] 
		WHERE [ErrorDate] >= DATEADD(DAY, DATEDIFF(DAY, 1, @dExecutionDate), 0)
			AND [Text] LIKE '%Dispatcher was unable%'
		)

		SET @Flag = 2
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (46, @Flag);

		BEGIN
			SELECT DISTINCT @TableHTML =  @TableHTML +
				'<tr>
					<td width = "20%" height = "30">' + 
					
						'Performance SQL Server' +
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
				
						'Fehler' + 
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
				
						'-'  +
					
					'</td>' +
					'<th style = "background-color: #FF0000" width = "10%" height = "30">' +
				
					'</th>' +
					'<td width = "50%" height = "30">' +
						
						FORMATMESSAGE(@sUnableRunSystemTask
							, (SELECT COUNT(Text) FROM USAGE.dbo.TempLogArchive WHERE [Text] LIKE '%terminating a system%'), FORMAT([LogDate], 'D', 'de-de')
							, (SELECT TOP 1 CONVERT(VARCHAR(8), [LogDate], 108) FROM USAGE.dbo.TempLogArchive WHERE [Text] LIKE '%Dispatcher was unable%' ORDER BY LogArchiveID ASC)
							, (SELECT TOP 1 CONVERT(VARCHAR(8), [LogDate], 108) FROM USAGE.dbo.TempLogArchive WHERE [Text] LIKE '%Dispatcher was unable%' ORDER BY LogArchiveID DESC), [Text]) +

					'</td>' +
				'</tr>'
			FROM USAGE.dbo.TempLogArchive
			WHERE [LogDate] >= DATEADD(DAY, DATEDIFF(DAY, 1, @dExecutionDate), 0)
				AND [Text] LIKE '%Dispatcher was unable%'
		END;

	/*
		| (4.7) Error message "There is insufficient system memory in resource pool 'default' to run this query"
	*/
	IF EXISTS (	
		SELECT 1 FROM [USAGE].[dbo].[ErrorArchive] 
		WHERE [ErrorDate] >= DATEADD(DAY, DATEDIFF(DAY, 1, @dExecutionDate), 0)
			AND [Text] LIKE '%insufficient system memory%'
		)

		SET @Flag = 2
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (47, @Flag);

		BEGIN
			SELECT DISTINCT @TableHTML =  @TableHTML +
				'<tr>
					<td width = "20%" height = "30">' + 
					
						'Performance Betriebssystem' +
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
				
						'Fehler' + 
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
				
						'-'  +
					
					'</td>' +
					'<th style = "background-color: #FF0000" width = "10%" height = "30">' +
				
					'</th>' +
					'<td width = "50%" height = "30">' +
						
						FORMATMESSAGE(@sUnableRunSystemTask
							, (SELECT COUNT(Text) FROM USAGE.dbo.TempLogArchive WHERE [Text] LIKE '%terminating a system%'), FORMAT([LogDate], 'D', 'de-de')
							, (SELECT TOP 1 CONVERT(VARCHAR(8), [LogDate], 108) FROM USAGE.dbo.TempLogArchive WHERE [Text] LIKE '%insufficient system memory%' ORDER BY LogArchiveID ASC)
							, (SELECT TOP 1 CONVERT(VARCHAR(8), [LogDate], 108) FROM USAGE.dbo.TempLogArchive WHERE [Text] LIKE '%insufficient system memory%' ORDER BY LogArchiveID DESC), [Text]) +

					'</td>' +
				'</tr>'
			FROM USAGE.dbo.TempLogArchive
			WHERE [LogDate] >= DATEADD(DAY, DATEDIFF(DAY, 1, @dExecutionDate), 0)
				AND [Text] LIKE '%insufficient system memory%'
		END;

	/*
		| (4.8) Error message "There is memory allocation failure during connection establishment"
	*/
	IF EXISTS (	
		SELECT 1 FROM [USAGE].[dbo].[ErrorArchive] 
		WHERE [ErrorDate] >= DATEADD(DAY, DATEDIFF(DAY, 1, @dExecutionDate), 0)
			AND [Text] LIKE '%memory allocation failure%'
		)

		SET @Flag = 2
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (48, @Flag);

		BEGIN
			SELECT DISTINCT @TableHTML =  @TableHTML +
				'<tr>
					<td width = "20%" height = "30">' + 
					
						'Performance SQL Server' +
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
				
						'Fehler' + 
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
				
						'-'  +
					
					'</td>' +
					'<th style = "background-color: #FF0000" width = "10%" height = "30">' +
				
					'</th>' +
					'<td width = "50%" height = "30">' +
						
						FORMATMESSAGE(@sErrorState, FORMAT([LogDate], 'D', 'de-de'), CONVERT(VARCHAR(8), [LogDate], 108), [Text]) +

					'</td>' +
				'</tr>'
			FROM USAGE.dbo.TempLogArchive
			WHERE [LogDate] >= DATEADD(DAY, DATEDIFF(DAY, 1, @dExecutionDate), 0)
				AND [Text] LIKE '%memory allocation failure%'
		END;

	/*
		| (5.1) Determine deactivated jobs
	*/
	IF EXISTS (SELECT 1 FROM dbo.sysjobs WHERE enabled = 0)

		SET @Flag = 1
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (51, @Flag);

		BEGIN
			SELECT @TableHTML =  @TableHTML +
				'<tr>
					<td width = "20%" height = "30">' +
				
						'Agent Job deaktiviert' +
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
				
						'Warnung' +
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
				
						'-'  +
					
					'</td>' +
					'<th width = "10%" height = "30">' +
				
					'</th>' +
					'<td width = "50%" height = "30">' +
				
						FORMATMESSAGE(@sJobDeaktivated, '''' + [name] + '''', FORMAT(date_modified, 'D', 'de-de'), CONVERT(VARCHAR(8), date_modified, 108)) +
					
					'</td>' +
				'</tr>'
			FROM dbo.sysjobs WHERE enabled = 0
		END;

	/*
		| (6.1) Determine Errors in Agent Log
	*/
	IF EXISTS (
		SELECT 1 FROM [USAGE].[dbo].[AgentLogArchive]
		WHERE [Text] NOT LIKE '%Fehlerprotokoll%'
			AND LogDate >= DATEADD(DAY, DATEDIFF(DAY, 1, @dExecutionDate), 0)
			AND LogDate < DATEADD(DAY, DATEDIFF(DAY, 0, @dExecutionDate), 0)
		)

		SET @Flag = 1
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (61, @Flag);

		BEGIN
			SELECT DISTINCT @TableHTML =  @TableHTML +
				'<tr>
					<td width = "20%" height = "30">' + 
					
						'SQL Agent Error Log' +
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
					
						'Warnung' + 
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
					
						'-'  + 
						
					'</td>' +
					'<th width = "10%" height = "30">' +
					
					'</th>' +
					'<td width = "50%" height = "30">' +
						
						FORMATMESSAGE(@sErrorState, FORMAT(LogDate, 'D', 'de-de'), CONVERT(VARCHAR(8), LogDate, 108), [Text]) +
						
					'</td>' +
				'</tr>'
			FROM [USAGE].[dbo].[AgentLogArchive]
			WHERE [Text] NOT LIKE '%Fehlerprotokoll%'
				AND LogDate >= DATEADD(DAY, DATEDIFF(DAY, 1, @dExecutionDate), 0)
				AND LogDate < DATEADD(DAY, DATEDIFF(DAY, 0, @dExecutionDate), 0)
		END;

	/*
		| (7.1) Determine failed jobs
	*/
	DROP TABLE IF EXISTS #FailedJobs;
	CREATE TABLE #FailedJobs (
		  [JobName] VARCHAR(50)
		, [StepID] SMALLINT
		, [FailedRunDate] DATETIME
		, [Description] VARCHAR(MAX)
		);
	
	INSERT INTO #FailedJobs
	SELECT
		  Jobs.name
		, JobHistory.step_id
		, JobHistory.FailedRunDate
		, CAST(JobHistory.LastError AS VARCHAR(250)) AS LastError
	FROM msdb.dbo.sysjobs Jobs
		CROSS APPLY (
			SELECT TOP 1 JobHistory.step_id
				, JobHistory.run_date
				, CASE JobHistory.run_date WHEN 0 THEN NULL ELSE
					  CONVERT(DATETIME
					, STUFF(STUFF(CAST(JobHistory.run_date AS NCHAR(8)), 7, 0, '-'), 5, 0, '-') + N' ' 
					+ STUFF(STUFF(SUBSTRING(CAST(1000000 + JobHistory.run_time AS NCHAR(7)), 2, 6), 5, 0, ':'), 3, 0, ':')
					, 120) END AS [FailedRunDate]
					, [Message] AS LastError
			FROM msdb.dbo.sysjobhistory JobHistory
			WHERE Run_status = 0 AND Jobs.job_id = JobHistory.job_id
			ORDER BY [FailedRunDate] DESC, step_id DESC) JobHistory
	WHERE Jobs.enabled = 1
		AND JobHistory.FailedRunDate >= @FromDate AND JobHistory.FailedRunDate <= @ToDate
		AND NOT EXISTS (
		SELECT [LastSuccessfulrunDate]
		FROM (
			SELECT CASE JobHistory.run_date WHEN 0 THEN NULL ELSE
				  CONVERT(DATETIME
				, STUFF(STUFF(CAST(JobHistory.run_date as nchar(8)), 7, 0, '-'), 5, 0, '-') + N' '
				+ STUFF(STUFF(SUBSTRING(CAST(1000000 + JobHistory.run_time AS NCHAR(7)), 2, 6), 5, 0, ':'), 3, 0, ':')
				, 120) END AS [LastSuccessfulrunDate]
			FROM msdb.dbo.sysjobhistory JobHistory
			WHERE Run_status = 1 AND Jobs.job_id = JobHistory.job_id) JobHistory2
		WHERE JobHistory2.[LastSuccessfulrunDate] > JobHistory.[FailedRunDate])
			AND NOT EXISTS (
			SELECT Session_id
			FROM msdb.dbo.sysjobactivity JobActivity
			WHERE Jobs.job_id = JobActivity.job_id
				AND stop_execution_date IS NULL
				AND SESSION_id = (SELECT MAX(Session_ID)
		FROM msdb.dbo.sysjobactivity JobActivity
		WHERE Jobs.job_id = JobActivity.job_id)
		)
		AND Jobs.Name != 'syspolicy_purge_history'
	ORDER BY name

	IF EXISTS (SELECT 1 FROM #FailedJobs)

		SET @Flag = 1
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (71, @Flag);

		BEGIN
			SELECT @TableHTML =  @TableHTML +
				'<tr>
					<td width = "20%" height = "30">' +
					
						'SQL Agent Job ist fehlerhaft' +
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
					
						'Warnung' +
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
					
						'-'  +
						
					'</td>' +
					'<th width = "10%" height = "30">' +
					
					'</th>' +
					'<td width = "50%" height = "30">' +
						
						FORMATMESSAGE(@sJobError + (SELECT TOP 1 [Description] FROM #FailedJobs), '''' + [JobName] + '''', FORMAT([FailedRunDate], 'D', 'de-de'), CONVERT(VARCHAR(8), [FailedRunDate], 108)) +
						
					'</td>' +
				'</tr>'
			FROM #FailedJobs
		END;

	/*
		| (8.1) Determine failed mails
	*/
	IF EXISTS (
		SELECT 1 FROM sysmail_faileditems
		WHERE sent_date >= DATEADD(DAY, DATEDIFF(DAY, 1, @dExecutionDate), 0)
			AND sent_date < DATEADD(DAY, DATEDIFF(DAY, 0, @dExecutionDate), 0)
		)

		SET @Flag = 1
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (81, @Flag);

		BEGIN
			SELECT @TableHTML =  @TableHTML +
				'<tr>
					<td width = "20%" height = "30">' + 
					
						'SMTP-Mailserver nicht erreichbar' + 
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
					
						'Warnung' +
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
					
						'-'  + 
						
					'</td>' +
					'<th width = "10%" height = "30">' + 
					
					'</th>' +
					'<td width = "50%" height = "30">' + 
						
						FORMATMESSAGE(@sMailError, FORMAT(sent_date, 'D', 'de-de'), CONVERT(VARCHAR(8), sent_date, 108)) +
						
					'</td>' +
				'</tr>'
			FROM sysmail_faileditems
			WHERE sent_date >= DATEADD(DAY, DATEDIFF(DAY, 1, @dExecutionDate), 0)
				AND sent_date < DATEADD(DAY, DATEDIFF(DAY, 0, @dExecutionDate), 0)
		END;

	/*
		| (8.2) Determine new Datenbank-E-Mail-Account
	*/
	IF EXISTS (SELECT 1 FROM msdb.dbo.sysmail_account WHERE name <> @account_name
			AND last_mod_datetime >= DATEADD(DAY, DATEDIFF(DAY, 1, @dExecutionDate), 0)
			AND last_mod_datetime < DATEADD(DAY, DATEDIFF(DAY, 0, @dExecutionDate), 0)
		)

		SET @Flag = 1
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (82, @Flag);

		BEGIN
			SELECT @TableHTML =  @TableHTML +
				'<tr>
					<td width = "20%" height = "30">' + 
					
						'Neues Mail Konto eingetragen' + 
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
					
						'Warnung' + 
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
					
						'-'  + 
						
					'</td>' +
					'<th width = "10%" height = "30">' +
					
					'</th>' +
					'<td width = "50%" height = "30">' +
						
						FORMATMESSAGE(@sMailAccount, FORMAT(last_mod_datetime, 'D', 'de-de'), CONVERT(VARCHAR(8), last_mod_datetime, 108), last_mod_user) +
						
					'</td>' +
				'</tr>'
			FROM msdb.dbo.sysmail_account WHERE name <> @account_name
				AND last_mod_datetime >= DATEADD(DAY, DATEDIFF(DAY, 1, @dExecutionDate), 0)
				AND last_mod_datetime < DATEADD(DAY, DATEDIFF(DAY, 0, @dExecutionDate), 0)
		END;

	/*
		| (8.3) Determine new Datenbank-E-Mail-Profile
	*/
	IF EXISTS (SELECT 1 FROM msdb.dbo.sysmail_profile WHERE name <> @EmailProfile
			AND last_mod_datetime >= DATEADD(DAY, DATEDIFF(DAY, 1, @dExecutionDate), 0)
			AND last_mod_datetime < DATEADD(DAY, DATEDIFF(DAY, 0, @dExecutionDate), 0)
		)

		SET @Flag = 1
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (83, @Flag);

		BEGIN
			SELECT @TableHTML =  @TableHTML +
				'<tr>
					<td width = "20%" height = "30">' + 
					
						'Neues Mail Profile eingetragen' + 
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
					
						'Warnung' +
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' + 
					
						'-'  + 
						
					'</td>' +
					'<th width = "10%" height = "30">' +
					
					'</th>' +
					'<td width = "50%" height = "30">' +
						
						FORMATMESSAGE(@sMailProfile, FORMAT(last_mod_datetime, 'D', 'de-de'), CONVERT(VARCHAR(8), last_mod_datetime, 108), last_mod_user) +
											
					'</td>' +
				'</tr>'
			FROM msdb.dbo.sysmail_profile WHERE name <> @EmailProfile
				AND last_mod_datetime >= DATEADD(DAY, DATEDIFF(DAY, 1, @dExecutionDate), 0)
				AND last_mod_datetime < DATEADD(DAY, DATEDIFF(DAY, 0, @dExecutionDate), 0)
		END;

	/*
		| (8.4) Determine sysoperator changes
	*/
	DECLARE @Find INT
	DECLARE @OperatorName VARCHAR(100)

	SET @OperatorName = (SELECT name FROM [msdb].[dbo].[sysoperators] WHERE Enabled = 1)
	SET @Find = (
		SELECT COUNT(*)
		FROM msdb.dbo.sysoperators
		WHERE [NAME] <> @OperatorName AND [enabled] <> 0
		)

	IF @Find <> 0

		SET @Flag = 1
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (84, @Flag);

		BEGIN
			SELECT @TableHTML =  @TableHTML +
				'<tr>
					<td width = "20%" height = "30">' +
					
						'Der Operatorstatus wurde geändert' +
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
					
						'Warnung' +
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
					
						'-'  +
						
					'</td>' +
					'<th width = "10%" height = "30">' +
					
					'</th>' +
					'<td width = "50%" height = "30">' +
						
						FORMATMESSAGE(@sOperatorChanges, '''' + name + '''') +
						
					'</td>' +
				'</tr>'
			FROM msdb.dbo.sysoperators
			WHERE [NAME] <> @OperatorName AND [enabled] <> 0
		END;

	/*
		| 9.1 Errors Logged in the Default Trace
	*/
	BEGIN TRY
						
		INSERT INTO #TraceGetTable ( 
			  TextData
			, DatabaseName
			, EventClass
			, Severity
			, StartTime
			, EndTime
			, Duration
			, NTUserName
			, NTDomainName
			, HostName
			, ApplicationName
			, LoginName
			, DBUserName
			)
		SELECT TOP 20000
			  CONVERT(NVARCHAR(4000), t.TextData)
			, t.DatabaseName
			, t.EventClass
			, t.Severity
			, t.StartTime
			, t.EndTime
			, t.Duration
			, t.NTUserName
			, t.NTDomainName
			, t.HostName
			, t.ApplicationName
			, t.LoginName
			, t.DBUserName
		FROM sys.fn_trace_gettable(@base_tracefilename, DEFAULT) t
		WHERE
		(
			t.EventClass = 22
			AND t.Severity >= 17
			AND t.StartTime > @FromDate
		)
		OR
		(
			t.EventClass IN (92, 93)
			AND t.StartTime > @FromDate
			AND t.Duration > 15000000
		)
		OR
		(
			t.EventClass IN (94, 95, 116)
		)

		SET @TraceFileIssue = 0

	END TRY

	BEGIN CATCH

		SET @TraceFileIssue = 1
						
	END CATCH

	IF EXISTS (SELECT 1 FROM #TraceGetTable t WHERE t.EventClass = 22)

		SET @Flag = 1
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (91, @Flag);

		BEGIN
			SELECT @TableHTML =  @TableHTML +

				'<tr>
					<td width = "20%" height = "30">' + 
						
						FORMATMESSAGE(@sSessionError, ''' + t.LoginName + ''', FORMAT(t.StartTime, 'D', 'de-de'), CONVERT(VARCHAR(8), t.StartTime, 108)) +
					
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
					
						'Warnung' +
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
					
						'-'  +
						
					'</td>' +
					'<th width = "10%" height = "30">' +
					
					'</th>' +
					'<td width = "50%" height = "30">' + 
						
						FORMATMESSAGE(@sApplicationError, t.ApplicationName, SUBSTRING(t.TextData, 36, 43), SUBSTRING(t.TextData, 116, 1000)) +

					'</td>' +
				'</tr>'

			FROM #TraceGetTable t
			WHERE t.EventClass = 22
		END;

	/*
		| 10.1 Determine user connections and connection memory
	*/
	IF 100 < @MaxUserConnections
		BEGIN
		SET @Flag = 1
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (101, @Flag);

			SELECT @TableHTML =  @TableHTML +

				'<tr>
					<td width = "20%" height = "30">' +
					
						'Hohe Anzahl von Benutzerverbindungen' +
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
					
						'Warnung' +
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
					
						'-'  +
						
					'</td>' +
					'<th width = "10%" height = "30">' +
					
					'</th>' +
					'<td width = "50%" height = "30">' +
						
						FORMATMESSAGE(@sUserConnections, @MaxUserConnections, @CounterName) +
						
					'</td>' +
				'</tr>'
		END;

	/*
		| 10.2 Determine Auto-Close Enabled
	*/
	IF EXISTS (
		SELECT 1 FROM sys.databases
		WHERE is_auto_close_on = 1
		)
		BEGIN
		SET @Flag = 1
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (102, @Flag);

			SELECT @TableHTML =  @TableHTML +

				'<tr>
					<td width = "20%" height = "30">' +
					
						'Performance SQL Server' +
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
					
						'Warnung' +
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
					
						'-'  +
						
					'</td>' +
					'<th width = "10%" height = "30">' +
					
					'</th>' +
					'<td width = "50%" height = "30">' +
						
						'Option ''Auto-Close'' auf der Datenbank [' + [name] + '] ist aktiviert. Diese Option bei Datenbanken kann zu einer Leistungseinbuße führen.' +
						
					'</td>' +
				'</tr>'

			FROM sys.databases
			WHERE is_auto_close_on = 1
		END;

	/*
		| 10.3 Determine Auto-Shrink Enabled
	*/
	IF EXISTS (
		SELECT 1 FROM sys.databases
		WHERE is_auto_shrink_on = 1
		)
		BEGIN
		SET @Flag = 1
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (103, @Flag);

			SELECT @TableHTML =  @TableHTML +
				'<tr>
					<td width = "20%" height = "30">' +
					
						'Performance' +
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
					
						'Warnung' +
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
					
						'-'  +
						
					'</td>' +
					'<th width = "10%" height = "30">' +
					
					'</th>' +
					'<td width = "50%" height = "30">' +
						
						'Option ''Auto-Shrink'' auf der Datenbank [' + [name] + '] ist aktiviert. Diese Option bei Datenbanken kann zu einer Leistungseinbuße führen.' +
						
					'</td>' +
				'</tr>'

			FROM sys.databases
			WHERE is_auto_shrink_on = 1
		END;

	/*
		| 10.4 Determine Auto-Create Stats Disabled
	*/
	IF EXISTS (
		SELECT 1 FROM sys.databases
		WHERE is_auto_create_stats_on = 0
		)
		BEGIN
		SET @Flag = 1
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (104, @Flag);

			SELECT @TableHTML =  @TableHTML +
				'<tr>
					<td width = "20%" height = "30">' +
					
						'Performance SQL Server' +
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
					
						'Warnung' +
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
					
						'-'  +
						
					'</td>' +
					'<th width = "10%" height = "30">' +
					
					'</th>' +
					'<td width = "50%" height = "30">' +
						
						'Option ''Auto-Create-Statistics'' auf der Datenbank [' + [name] + '] ist deaktiviert. Diese Option bei Datenbanken kann zu einer Leistungseinbuße führen.' +
						
					'</td>' +
				'</tr>'

			FROM sys.databases
			WHERE is_auto_create_stats_on = 0
		END;

	/*
		| 10.5 Determine Auto-Update Stats Disabled
	*/
	IF EXISTS (
		SELECT 1 FROM sys.databases
		WHERE is_auto_update_stats_on = 0
		)
		BEGIN
		SET @Flag = 1
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (105, @Flag);

			SELECT @TableHTML =  @TableHTML +
				'<tr>
					<td width = "20%" height = "30">' +
					
						'Performance SQL Server' +
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
					
						'Warnung' +
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
					
						'-'  +
						
					'</td>' +
					'<th width = "10%" height = "30">' +
					
					'</th>' +
					'<td width = "50%" height = "30">' +
						
						'Option ''Auto-Update-Statistics'' auf der Datenbank [' + [name] + '] ist deaktiviert. Diese Option bei Datenbanken kann zu einer Leistungseinbuße führen.' +
						
					'</td>' +
				'</tr>'

			FROM sys.databases
			WHERE is_auto_update_stats_on = 0
		END;

	/*
		| 10.6 Determine Statistics Updated Asynchronously
	*/
	IF EXISTS (
		SELECT 1 FROM sys.databases
		WHERE is_auto_update_stats_async_on = 1
		)
		BEGIN
		SET @Flag = 1
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (106, @Flag);

			SELECT @TableHTML =  @TableHTML +
				'<tr>
					<td width = "20%" height = "30">' +
					
						'Performance SQL Server' +
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
					
						'Warnung' +
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
					
						'-'  +
						
					'</td>' +
					'<th width = "10%" height = "30">' +
					
					'</th>' +
					'<td width = "50%" height = "30">' +
						
						'Option ''Auto-Update-Statistics-Async'' auf der Datenbank [' + [name] + '] ist aktiviert. Diese Option bei Datenbanken kann zu einer Leistungseinbuße führen.' +
						
					'</td>' +
				'</tr>'

			FROM sys.databases
			WHERE is_auto_update_stats_async_on = 1
		END;

	/*
		| 10.7 Determine SQL CPU Utilization
	*/
	DROP TABLE IF EXISTS #CPUUtilization;
	CREATE TABLE #CPUUtilization (
		  SQLCPUUtilization TINYINT
		, SystemIdleProcess TINYINT
		, OtherProcessCPUUtilization TINYINT
		, EventTime DATETIME
		)
	CREATE CLUSTERED INDEX cx_eventtime ON #CPUUtilization (EventTime);

		BEGIN
			INSERT INTO #CPUUtilization (SQLCPUUtilization, SystemIdleProcess, OtherProcessCPUUtilization, EventTime)
			SELECT DISTINCT
				  [SQLCPUUtilization]
				, [SystemIdleProcess]
				, [OtherProcessCPUUtilization]
				, [EventTime]
			FROM [USAGE].[dbo].[CPUUtilization]
			WHERE [SQLCPUUtilization] >= 60 OR OtherProcessCPUUtilization > 70
		END;

	IF EXISTS (SELECT 1 FROM #CPUUtilization WHERE [SQLCPUUtilization] > 60 AND [EventTime] >= @FromDate AND [EventTime] <= @ToDate)
		BEGIN
			SET @Flag = 1
			INSERT INTO #GetTrafficLight ([ID], [Flag])
			VALUES (107, @Flag);

				SELECT @TableHTML =  @TableHTML +
					'<tr>
						<td width = "20%" height = "30">' +
					
							'SQL Server Performance' +
						
						'</td>
						<td style = "text-align: center" width = "10%" height = "30">' +
					
							'Warnung' +
						
						'</td>
						<td style = "text-align: center" width = "10%" height = "30">' +
					
							'-'  +
						
						'</td>' +
						'<th width = "10%" height = "30">' +
					
						'</th>' +
						'<td width = "50%" height = "30">' +
						
							FORMATMESSAGE(@sCPUSQLUtilization, CAST([SQLCPUUtilization] AS VARCHAR(10)), FORMAT([EventTime], 'D', 'de-de'), CONVERT(VARCHAR(8), [EventTime], 108)) +
						
						'</td>' +
					'</tr>'
				FROM #CPUUtilization
				WHERE [SQLCPUUtilization] > 60 AND [EventTime] >= @FromDate AND [EventTime] <= @ToDate
				ORDER BY [EventTime] DESC
		END;

	/*
		| 10.8 Determine None SQL CPU Utilization
	*/
	IF EXISTS (SELECT 1 FROM #CPUUtilization WHERE [OtherProcessCPUUtilization] > 70)	-- AND [EventTime] >= @FromDate AND [EventTime] <= @ToDate)
		BEGIN
			SET @Flag = 1
			INSERT INTO #GetTrafficLight ([ID], [Flag])
			VALUES (108, @Flag);

				SELECT @TableHTML =  @TableHTML +
					'<tr>
						<td width = "20%" height = "30">' +
					
							'Performance Betriebssystem' +
						
						'</td>
						<td style = "text-align: center" width = "10%" height = "30">' +
					
							'Warnung' +
						
						'</td>
						<td style = "text-align: center" width = "10%" height = "30">' +
					
							'-'  +
						
						'</td>' +
						'<th width = "10%" height = "30">' +
					
						'</th>' +
						'<td width = "50%" height = "30">' +
						
							FORMATMESSAGE(@sNoneCPUSQLUtilization, CAST([OtherProcessCPUUtilization] AS VARCHAR(10)), FORMAT([EventTime], 'D', 'de-de'), CONVERT(VARCHAR(8), [EventTime], 108)) +
						
						'</td>' +
					'</tr>'
				FROM #CPUUtilization
				WHERE [OtherProcessCPUUtilization] > 70 --AND [EventTime] >= @FromDate AND [EventTime] <= @ToDate
				ORDER BY [EventTime] DESC
		END;

	/*
		| 10.9 Determining Current Memory Allocation
	*/
	DROP TABLE IF EXISTS #MemoryAllocation;
	CREATE TABLE #MemoryAllocation (
		  [PhysicalMemoryUsedBySQL] NVARCHAR(64)
		, [PhysicalMemoryLow] BIT
		, [VirtualMemoryLow] BIT
		, [EventTime] DATETIME
		)
	CREATE CLUSTERED INDEX cx_eventtime ON #MemoryAllocation (EventTime);

		BEGIN
			INSERT INTO #MemoryAllocation (PhysicalMemoryUsedBySQL, PhysicalMemoryLow, VirtualMemoryLow, EventTime)
			SELECT
				  [PhysicalMemoryUsedBySQL]
				, [PhysicalMemoryLow]
				, [VirtualMemoryLow]
				, [EventTime]
			FROM USAGE.dbo.MemoryAllocation
			WHERE ([PhysicalMemoryLow] <> 0 OR [VirtualMemoryLow] <> 0)
				AND [EventTime] >= @FromDate AND [EventTime] <= @ToDate
		END;

		IF EXISTS (SELECT 1 FROM #MemoryAllocation)

			BEGIN
			SET @Flag = 1
			INSERT INTO #GetTrafficLight ([ID], [Flag])
			VALUES (109, @Flag);

				SELECT TOP 1 @TableHTML =  @TableHTML +

					'<tr>
						<td width = "20%" height = "30">' +
					
							'Performance SQL Server' +
						
						'</td>
						<td style = "text-align: center" width = "10%" height = "30">' +
					
							'Warnung' +
						
						'</td>
						<td style = "text-align: center" width = "10%" height = "30">' +
					
							'-'  +
						
						'</td>' +
						'<th width = "10%" height = "30">' +
					
						'</th>' +
						'<td width = "50%" height = "30">' +
					
							FORMATMESSAGE(@sSpeicherauslastung, [PhysicalMemoryUsedBySQL], FORMAT([EventTime], 'D', 'de-de'), CONVERT(VARCHAR(8), [EventTime], 108)) +

							'<table class = "intern" height = "30" cellSpacing = "0" cellPadding = "0" width = "100%" border = "0">' +

								(
								SELECT
									(SELECT 'Arbeitsspeicherverwendung' FOR XML PATH(''), TYPE) AS 'caption',
									(SELECT 'Counter' AS th, 'Value (MB)' AS th FOR XML RAW('tr'), ELEMENTS, TYPE) AS 'thead',
									(
									SELECT [Counter Name] AS td, [Value] AS td FROM [USAGE].[dbo].[MemoryPressure] ORDER BY Value DESC
									FOR XML RAW('tr'), ELEMENTS, TYPE
									) AS 'tbody'
									FOR XML PATH(''), ROOT('table')
								) +

							'</table>
						</td>
					</tr>'
				FROM #MemoryAllocation
				WHERE [EventTime] >= @FromDate AND [EventTime] <= @ToDate
				ORDER BY [EventTime] DESC
			END;

	/*
		| 10.10 - Diagnose potential CPU pressure based on https://docs.microsoft.com/en-us/previous-versions/technet-magazine/dn383732(v=msdn.10)?redirectedfrom=MSDN
		| Total waits are wait_time_ms (high signal waits indicate CPU pressure)
		| A high percentage signal is a sign of CPU pressure. "High" often refers to more than 25 percent, but it depends on your system.
		| Because signal waits are time spent waiting for a CPU to service a thread, if you record total signal waits above roughly 15 percent, that’s a good indicator of CPU pressure.
		| If response times are slow and you find no significant waits, or mainly signal waits, you know you need to focus on CPU.
		| Manually clear out the wait statistics, without restarting the server, by issuing a database consistency checking:
		| DBCC SQLPERF('sys.dm_os_wait_stats', CLEAR);
	*/
	IF 20 < @CPUPressure
	BEGIN
		SET @Flag = 1
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (110, @Flag);

		DROP TABLE IF EXISTS #CausesOfWaits;
		CREATE TABLE #CausesOfWaits (
				[WaitType] NVARCHAR(64)
			, [WaitTime] DECIMAL(20,2)
			, [Prozent] DECIMAL(10,2)
			, [RunningProzent] DECIMAL(10,2)
			)
		
		INSERT INTO #CausesOfWaits (WaitType, WaitTime, Prozent, RunningProzent)
		SELECT TOP 1 wait_type
			, wait_time_ms / 1000. AS wait_time_s 
			, 100. * wait_time_ms / SUM(wait_time_ms) OVER ( ) AS pct 
			, ROW_NUMBER() OVER ( ORDER BY wait_time_ms DESC ) AS rn 
		FROM sys.dm_os_wait_stats 
		WHERE wait_type NOT IN ( 'CLR_SEMAPHORE'
			, 'SP_SERVER_DIAGNOSTICS_SLEEP'
			, 'QDS_PERSIST_TASK_MAIN_LOOP_SLEEP'
			, 'DIRTY_PAGE_POLL'
			, 'BROKER_EVENTHANDLER'
			, 'BROKER_RECEIVE_WAITFOR'
			, 'HADR_FILESTREAM_IOMGR_IOCOMPLETION'
			, 'LAZYWRITER_SLEEP'
			, 'RESOURCE_QUEUE'
			, 'SLEEP_TASK'
			, 'SLEEP_SYSTEMTASK'
			, 'SQLTRACE_BUFFER_FLUSH'
			, 'WAITFOR'
			, 'LOGMGR_QUEUE'
			, 'CHECKPOINT_QUEUE'
			, 'REQUEST_FOR_DEADLOCK_SEARCH'
			, 'XE_TIMER_EVENT'
			, 'BROKER_TO_FLUSH'
			, 'BROKER_TASK_STOP'
			, 'CLR_MANUAL_EVENT'
			, 'CLR_AUTO_EVENT'
			, 'DISPATCHER_QUEUE_SEMAPHORE'
			, 'FT_IFTS_SCHEDULER_IDLE_WAIT'
			, 'XE_DISPATCHER_WAIT'
			, 'XE_DISPATCHER_JOIN'
			)

			SELECT @TableHTML =  @TableHTML +
				'<tr>
					<td width = "20%" height = "30">' +
					
						'Performance Betriebssystem' +
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
					
						'Warnung' +
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
					
						'-'  +
						
					'</td>' +
					'<th width = "10%" height = "30">' +
					
					'</th>' +
					'<td width = "50%" height = "30">' +
						
						FORMATMESSAGE(@sCPUPressure, CAST(@CPUPressure AS VARCHAR(20))) +
						'Wait Type: ' + WaitType + '<br>' +
						'Potenzielle Ursache' + (
							SELECT 
								CASE WaitType 
									WHEN 'SQLTRACE_INCREMENTAL_FLUSH_SLEEP' THEN ': Ausführung des Profiler auf dem Produktionssystem muss vermieden werden. Stattdessen einen Skript-Trace oder erweiterte Ereignisse verwenden.' 
									ELSE ' ist nicht bekannt und muss analysiert werden.'
								END
							FROM #CausesOfWaits
							) +

					'</td>' +
				'</tr>'
				FROM #CausesOfWaits
		END;

	/*
		| 11.1 Detecting SQL Server Deadlocks
	*/
	IF EXISTS (
		SELECT 1 FROM USAGE.dbo.TempDeadlocks 
		WHERE [EventTime] >= @FromDate AND [EventTime] <= @ToDate
		)
		BEGIN
		SET @Flag = 1
		INSERT INTO #GetTrafficLight ([ID], [Flag])
		VALUES (108, @Flag);

			SELECT @TableHTML =  @TableHTML +

				'<tr>
					<td width = "20%" height = "30">' +
					
						'Deadlock Monitor' +
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
					
						'Warnung' +
						
					'</td>
					<td style = "text-align: center" width = "10%" height = "30">' +
					
						'-'  +
						
					'</td>' +
					'<th width = "10%" height = "30">' +
					
					'</th>' +
					'<td width = "50%" height = "30">' +

						'Das folgende Skript wurde am ' + FORMAT([EventTime], 'D', 'de-de') + ' um ' + CONVERT(VARCHAR(8), [EventTime], 108) + ' ausgeführt:<br>-------------------------------------------------------------------------------------------------<br>' +	(
																
							CAST(DeadlockGraph AS NVARCHAR(MAX))

							) +

					'</td>
				</tr>'
			FROM USAGE.dbo.TempDeadlocks
			WHERE [EventTime] >= @FromDate AND [EventTime] <= @ToDate
			ORDER BY [EventTime] DESC
		END;

	--------------------------------------------------------------------------------
	--| HTML No Error - Footer
	--------------------------------------------------------------------------------

	IF @Flag <> 0 GOTO GetAllErrors ELSE

	DECLARE @GetInstances TABLE	(
		  VALUE NVARCHAR(100)
		, InstanceNames NVARCHAR(100)
		, DATA NVARCHAR(100)
		)

	INSERT INTO @GetInstances
	EXECUTE xp_regread
		  @rootkey = 'HKEY_LOCAL_MACHINE'
		, @key = 'SOFTWARE\Microsoft\Microsoft SQL Server'
		, @value_name = 'InstalledInstances'

	DROP TABLE IF EXISTS #MasterFiles;
	CREATE TABLE #MasterFiles (database_id INT, file_id INT, type_desc NVARCHAR(50), name NVARCHAR(255), physical_name NVARCHAR(255), size BIGINT);
	IF ((SERVERPROPERTY('Edition')) = 'SQL Azure' 
			AND (OBJECT_ID('sys.master_files') IS NULL))
		SET @StringToExecute = 'INSERT INTO #MasterFiles (database_id, file_id, type_desc, name, physical_name, size) SELECT DB_ID(), file_id, type_desc, name, physical_name, size FROM sys.database_files;';
	ELSE
		SET @StringToExecute = 'INSERT INTO #MasterFiles (database_id, file_id, type_desc, name, physical_name, size) SELECT database_id, file_id, type_desc, name, physical_name, size FROM sys.master_files;';
		EXEC(@StringToExecute);

	SET @TableHTML = @HTMLStyle +
	'
	<main>
	<table class = "technZustandTitle" height = "50" cellSpacing = "0" cellPadding = "0" width = "100%" border = "0">
		<tr>
			<td>

				Technischer Zustand ' + CONVERT(VARCHAR(100), @SERVERNAME) +
				CASE WHEN @BetaVersion = 1 THEN @sBetaVersion ELSE '' END +

			'</td>

			<td align = "right" width = "50%" bgcolor = "#FFFFFF" height = "50" style = "padding: 5px 5px 5px 5px;">

				<a href = "" title = ""><img src = "cid:intellinova_logo5.png" width = "50" height = "50"></a>

			</td>
		</tr>
	</table>' +

	'<table class = "technZustandColNames" height = "50" cellSpacing = "0" cellPadding = "0" width = "100%" border = "1">
		<tr>
			<td width = "20%" height = "50">
				Name
			</td>
			<td width = "80%" height = "50">
				Details
			</td>
		</tr>
	</table>' +

	'<table class = "technZustandContent" height = "50" cellSpacing = "0" cellPadding = "0" width = "100%" border = "1">
		<tr>
			<td width = "20%" height = "30">

				-

			<td width = "80%" height = "30">' +

				'Es wurden keine technischen Probleme festgestellt' +

			'</td>
		</tr>'

	IF ((CAST(SERVERPROPERTY('ProductUpdateLevel') AS NVARCHAR(100)) <> (SELECT [Service Pack] FROM #Versions)))
		BEGIN
			SELECT @TableHTML =  @TableHTML +

			'<tr>
				<td width = "20%" height = "30">' +

					'Offen' +

				'</th>
				<td width = "80%" height = "30">' +
					CASE WHEN @@VERSION LIKE '%Microsoft SQL Server 2017%' 
						THEN 'Kumulatives Update ' + [Service Pack] + ' wurde seit ' + CAST(DATEDIFF(DAY, @CUDate, GETDATE()) AS VARCHAR(4)) + ' Tagen veröffentlicht und muss ' +
					CASE WHEN @Overdue <= @dExecutionDate 
						THEN 'dringend installiert werden'
						ELSE 'installiert werden' 
						END 
					END + 
				'</td>' +
			'</tr>'
			FROM #Versions
		END;

		SELECT @TableHTML =  @TableHTML +
		'<tr>
			<td width = "20%" height = "30">

				Performance

			<td width = "80%" height = "30">' +

				FORMATMESSAGE(@aUserConnections, @MaxUserConnections, @TimePointMaxUserConnections) +

			'</td>
		</tr>
		<tr>
			<td width = "20%" height = "30">

				Server Info

			<td width = "80%" height = "30">' +

				FORMATMESSAGE(@sNeustartBetriebsystem, @sNeustartBetriebsystemDatum, @sNeustartBetriebsystemPoint) +

			'</td>
		</tr>
		<tr>
			<td width = "20%" height = "30">

				Server Info

			<td width = "80%" height = "30">' +

				FORMATMESSAGE(@sRestartSqlServer, @sRestartSqlDate, @sRestartSqlTimePoint) +

			'</td>
		</tr>
		<tr>
			<td width = "20%" height = "30">

				Server Info

			<td width = "80%" height = "30">' +

				FORMATMESSAGE(@sInstanceCount, @ActiveClusterPartner, @InstanceCount) + (SELECT STRING_AGG(InstanceNames, ', ') FROM @GetInstances) +

			'</td>
		</tr>
		<tr>
			<td width = "20%" height = "30">

				Server Info

			<td width = "80%" height = "30">' +

				(
					'Aktuelle Instanz ''' + ISNULL(CAST(SERVERPROPERTY('InstanceName') AS NVARCHAR(100)), '(default instance)') + '''' + ' beinhaltet ' + (SELECT CAST(COUNT(DISTINCT database_id) AS NVARCHAR(100)) + N' Datenbanken, die Gesamtgröße: ' + CAST(CAST(SUM (CAST(size AS BIGINT)*8./1024./1024.) AS MONEY) AS VARCHAR(100)) + ' GB' AS Details FROM #MasterFiles WHERE database_id > 4)
				) +

				'<br>' +

				(
					SELECT STRING_AGG(name, ', ') FROM sys.databases WHERE name NOT IN ('master', 'msdb', 'model', 'tempdb')
				) +

			'</td>
		</tr>'

	GetAllErrors:
	--------------------------------------------------------------------------------
	--| HTML No Error - End Footer
	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--| HTML Error Footer
	--------------------------------------------------------------------------------
	SELECT @TableHTML =  @TableHTML +  '</table>' +
		'<p style = "margin-top: 0; margin-bottom: 0">&nbsp;</p>
		<p>IntelliNOVA Support</p>
		</main>'
	--------------------------------------------------------------------------------
	--| End HTML Footer
	--------------------------------------------------------------------------------
	--------------------------------------------------------------------------------
	--| End to HTML Formatting
	--------------------------------------------------------------------------------

	IF @EmailRecipients IS NOT NULL
		BEGIN
			SET @WarningSignSubject = (SELECT WarningSignSubject FROM #TrafficLight WHERE Flag IN (SELECT MAX(Flag) FROM #GetTrafficLight))
			SET @SetMailSubject = 'ELVIS-Betrieb - [' + @WarningSignSubject + '] Technischer Zustand ' + CONVERT(VARCHAR(100), @SERVERNAME)					
			IF @Debug IN (1, 2) RAISERROR('Sending an email.', 0, 1) WITH NOWAIT;
			IF @EmailProfile IS NULL
				EXEC msdb.dbo.sp_send_dbmail
					  @recipients = @EmailRecipients
					, @subject = @SetMailSubject
					, @body = @TableHTML
					, @file_attachments = @LogoPath
					, @body_format = 'HTML';
			ELSE
				EXEC msdb.dbo.sp_send_dbmail
					  @profile_name = @EmailProfile
					, @recipients = @EmailRecipients
					, @subject = @SetMailSubject
					, @body = @TableHTML
					, @file_attachments = @LogoPath
					, @body_format = 'HTML';
		END;

SET NOCOUNT OFF;
SET ARITHABORT OFF;
END
GO
