/*
	Created by AMER\SVG_PGZM1s217$ using dbatools Export-DbaScript for objects on P054WFCMXSQLP02.AMER.EPIQCORP.COM at 01/01/2024 21:46:19
	See https://dbatools.io/Export-DbaScript for more information
*/
IF NOT EXISTS (SELECT * FROM sys.schemas WHERE name = N'ccqaq')
EXEC sys.sp_executesql N'CREATE SCHEMA [ccqaq]'

GO

/*
	Created by AMER\SVG_PGZM1s217$ using dbatools Export-DbaScript for objects on P054WFCMXSQLP02.AMER.EPIQCORP.COM at 01/01/2024 21:46:35
	See https://dbatools.io/Export-DbaScript for more information
*/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[ccqaq].[PhoneContactQueue]') AND type in (N'U'))
BEGIN
CREATE TABLE [ccqaq].[PhoneContactQueue](
	[PhoneContactQueueId] [int] IDENTITY(1,1) NOT NULL,
	[PhoneLogId] [int] NOT NULL,
	[TrackingNumber] [int] NULL,
	[ContactAttempt1ResultTypeId] [int] NULL,
	[ContactAttempt2ResultTypeId] [int] NULL,
	[ContactAttempt3ResultTypeId] [int] NULL,
	[ValidatedCallType] [varchar](100) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[IsUrgent] [bit] NOT NULL,
	[DateMarkedUrgent] [datetime] NULL,
	[IsCoachingNeeded] [bit] NOT NULL,
	[IsComplaintRelated] [bit] NULL,
	[QaReviewerNotes] [varchar](2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[QaManagerNotes] [varchar](2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[IsComplete] [bit] NOT NULL,
	[IsQaReviewed] [bit] NOT NULL,
	[QaReviewedBy] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[QaReviewedDate] [datetime2](0) NULL,
	[IsManagerReviewed] [bit] NOT NULL,
	[ManagerReviewedBy] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ManagerReviewedDate] [datetime2](0) NULL,
	[IsManagerApproved] [bit] NOT NULL,
	[ManagerNotes] [varchar](2000) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ApprovedBy] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[ApprovedDate] [datetime2](0) NULL,
	[UpdatedDate] [datetime2](0) NOT NULL,
	[UpdatedBy] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NOT NULL,
	[LockedDate] [datetime2](0) NULL,
	[LockedBy] [varchar](255) COLLATE SQL_Latin1_General_CP1_CI_AS NULL,
	[LockExpirationTime] [datetime2](0) NULL,
	[InsertedDate] [datetime2](0) NOT NULL,
	[IsSetForDelete] [bit] NULL,
 CONSTRAINT [PK_PhoneContactQueue] PRIMARY KEY CLUSTERED 
(
	[PhoneContactQueueId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
END
GO

IF NOT EXISTS (SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID(N'[ccqaq].[PhoneContactQueue]') AND name = N'IX_PhoneContactQueue_PhoneLogId')
CREATE NONCLUSTERED INDEX [IX_PhoneContactQueue_PhoneLogId] ON [ccqaq].[PhoneContactQueue]
(
	[PhoneLogId] ASC
)
INCLUDE([IsQaReviewed]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[ccqaq].[DF__PhoneCont__IsUrg__4D4A6ED8]') AND type = 'D')
BEGIN
ALTER TABLE [ccqaq].[PhoneContactQueue] ADD  DEFAULT ((0)) FOR [IsUrgent]
END

GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[ccqaq].[DF__PhoneCont__IsCoa__4E3E9311]') AND type = 'D')
BEGIN
ALTER TABLE [ccqaq].[PhoneContactQueue] ADD  DEFAULT ((0)) FOR [IsCoachingNeeded]
END

GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[ccqaq].[DF__PhoneCont__IsCom__4F32B74A]') AND type = 'D')
BEGIN
ALTER TABLE [ccqaq].[PhoneContactQueue] ADD  DEFAULT ((0)) FOR [IsComplete]
END

GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[ccqaq].[DF__PhoneCont__IsQaR__5026DB83]') AND type = 'D')
BEGIN
ALTER TABLE [ccqaq].[PhoneContactQueue] ADD  DEFAULT ((0)) FOR [IsQaReviewed]
END

GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[ccqaq].[DF__PhoneCont__IsMan__511AFFBC]') AND type = 'D')
BEGIN
ALTER TABLE [ccqaq].[PhoneContactQueue] ADD  DEFAULT ((0)) FOR [IsManagerReviewed]
END

GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[ccqaq].[DF__PhoneCont__IsMan__520F23F5]') AND type = 'D')
BEGIN
ALTER TABLE [ccqaq].[PhoneContactQueue] ADD  DEFAULT ((0)) FOR [IsManagerApproved]
END

GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[ccqaq].[DF__PhoneCont__Updat__5303482E]') AND type = 'D')
BEGIN
ALTER TABLE [ccqaq].[PhoneContactQueue] ADD  DEFAULT (getdate()) FOR [UpdatedDate]
END

GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[ccqaq].[DF__PhoneCont__Inser__53F76C67]') AND type = 'D')
BEGIN
ALTER TABLE [ccqaq].[PhoneContactQueue] ADD  DEFAULT (getdate()) FOR [InsertedDate]
END

GO

IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[ccqaq].[DF__PhoneCont__IsSet__54EB90A0]') AND type = 'D')
BEGIN
ALTER TABLE [ccqaq].[PhoneContactQueue] ADD  DEFAULT ((0)) FOR [IsSetForDelete]
END

GO

