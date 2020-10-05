USE [USAGE]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MemoryPressure](
	[ID] [int] NULL,
	[Counter Name] [nvarchar](128) NULL,
	[Value] [numeric](20, 2) NULL
) ON [PRIMARY]
GO
CREATE TABLE [dbo].[MemoryAllocation](
	[PhysicalMemoryUsedBySQL] [bigint] NULL,
	[PhysicalMemoryLow] [bit] NULL,
	[VirtualMemoryLow] [bit] NULL,
	[EventTime] [datetime] NULL
) ON [PRIMARY]
GO
CREATE TABLE [dbo].[LogArchive](
	[LogArchiveID] [int] IDENTITY(1,1) NOT NULL,
	[LogDate] [datetime] NULL,
	[ProcessInfo] [varchar](50) NULL,
	[Text] [varchar](max) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
CREATE TABLE [dbo].[ErrorArchiveCurrent](
	[ErrorID] [int] IDENTITY(1,1) NOT NULL,
	[ErrorDate] [datetime] NULL,
	[ProcessInfo] [varchar](50) NULL,
	[Text] [varchar](max) NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
CREATE TABLE [dbo].[CPUUtilization](
	[SQLCPUUtilization] [tinyint] NULL,
	[SystemIdleProcess] [tinyint] NULL,
	[OtherProcessCPUUtilization] [tinyint] NULL,
	[EventTime] [datetime] NULL
) ON [PRIMARY]
GO


