USE billups
GO

IF OBJECT_ID(N'dbo.LogType', N'U') IS NOT NULL   
    DROP TABLE dbo.LogType;
CREATE TABLE dbo.LogType (
	Id			INTEGER NOT NULL IDENTITY(1,1) PRIMARY KEY,
	LogType		INTEGER,
	LogTypeDesc VARCHAR(10)
)

IF OBJECT_ID(N'dbo.LogEvent', N'U') IS NOT NULL   
    DROP TABLE dbo.LogEvent;
CREATE TABLE dbo.LogEvent (
	Id				INTEGER NOT NULL IDENTITY(1,1) PRIMARY KEY,
	LogType			INTEGER FOREIGN KEY REFERENCES dbo.LogType(Id),
	LogEventDesc	VARCHAR(MAX), 
	DataId			NVARCHAR(64),
	TimeStamp		DATETIME
)

INSERT INTO dbo.LogType
VALUES (1, 'ERROR')
INSERT INTO dbo.LogType
VALUES (2, 'WARNING')
INSERT INTO dbo.LogType
VALUES (3, 'INFO')