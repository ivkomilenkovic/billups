# billups

Getting Started <br /> 
File or Folder <br />
- Config.sql	<br />
	The file contains code for creating logging tables and inserting configuration data in one of them. The same file could contain also code for creating some configuration tables what could be next phase of enhancing the project. <br />
-	MigrationScript.sql <br />
	The file contains code needed to create normalized tables and insert “clean” data in them after import data from file to database. <br />
-	dbo.GetPOI.sql <br />
Store procedure to return requested data. <br />

Set up development environment:
1.	Create new MS SQL Server database
	https://learn.microsoft.com/en-us/sql/relational-databases/databases/create-a-database?view=sql-server-ver16
2.	Execute code from Config.sql in order to create logging tables
3.	Open MigrationScript.sql and create staging table dbo.StageGeoData
4.	Import data from file to created table dbo.StageGeoData
	https://learn.microsoft.com/en-us/sql/relational-databases/import-export/import-data-from-excel-to-sql?view=sql-server-ver16
5.	Execute the rest of code in MigrationScript.sql which will create normalized tables and get data into them from staging table <br />
Note: dbo.StageGeoData is under comment block in order to enable to execute MigrationScript.sql at once after import <br />

Database backup and restore: <br />
	Please follow the instructions: https://learn.microsoft.com/en-us/sql/relational-databases/backup-restore/quickstart-backup-restore-database?view=sql-server-ver16&tabs=ssms <br />

	Database backup: https://drive.google.com/file/d/1v0ElnSPv4qK2VdoveQ_Ao2W3e-1Bmcc_/view?usp=sharing
 
