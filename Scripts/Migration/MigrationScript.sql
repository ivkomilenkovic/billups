USE billups
GO


/*
-- Check and debug
SELECT COUNT(*) FROM dbo.StageGeoData
SELECT distinct Id FROM dbo.StageGeoData
SELECT * FROM dbo.StageGeoData
SELECT * FROM dbo.Brand
SELECT * FROM dbo.Category
SELECT * FROM dbo.SubCategory
SELECT * FROM dbo.City
SELECT * FROM dbo.Region
SELECT * FROM dbo.Country
SELECT * FROM dbo.Location
SELECT * FROM dbo.GeometryType
SELECT * FROM dbo.Poi
*/

/*
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- Staging table to import data from flat file
IF OBJECT_ID(N'dbo.StageGeoData', N'U') IS NOT NULL   
    DROP TABLE dbo.StageGeoData;  
CREATE TABLE dbo.StageGeoData (
	id NVARCHAR(64),
	parent_id NVARCHAR(64),
	brand NVARCHAR(1000),
	brand_id NVARCHAR(64),
	top_category NVARCHAR(1000),
	sub_category NVARCHAR(1000),
	category_tags NVARCHAR(1000),
	postal_code INTEGER,
	location_name NVARCHAR(1000),
	latitude DECIMAL(21,15),
	longitude DECIMAL(21,15),
	country_code NVARCHAR(5),
	city NVARCHAR(200),
	region NVARCHAR(5),
	operation_hours NVARCHAR(1000),
	geometry_type NVARCHAR(64),
	polygon_wkt NVARCHAR(MAX),
	CompletedData BIT NOT NULL DEFAULT 0
)
*/

IF OBJECT_ID(N'dbo.Brand', N'U') IS NOT NULL   
    DROP TABLE dbo.Brand;  
CREATE TABLE dbo.Brand (
	Id INTEGER NOT NULL IDENTITY(1,1) PRIMARY KEY,
	Brand	VARCHAR(1000), 
	ExternalBrandId NVARCHAR(64)
)

IF OBJECT_ID(N'dbo.Category', N'U') IS NOT NULL   
    DROP TABLE dbo.Category;  
CREATE TABLE dbo.Category (
	Id INTEGER NOT NULL IDENTITY(1,1) PRIMARY KEY,
	TopCategory NVARCHAR(1000)
)

IF OBJECT_ID(N'dbo.SubCategory', N'U') IS NOT NULL   
    DROP TABLE dbo.SubCategory;  
CREATE TABLE dbo.SubCategory (
	Id INTEGER NOT NULL IDENTITY(1,1) PRIMARY KEY,
	SubCategory NVARCHAR(1000),
	CategoryId INT FOREIGN KEY REFERENCES dbo.Category(Id)
)

-- dbo.City, dbo.Region and dbo.Country could be normalized on different way (e.g.dbo.City to contain FK to dbo.Region) but I decided to do it on this way because of some potentional border cases
IF OBJECT_ID(N'dbo.City', N'U') IS NOT NULL   
    DROP TABLE dbo.City;  
CREATE TABLE dbo.City (
	Id INTEGER NOT NULL IDENTITY(1,1) PRIMARY KEY,
	City VARCHAR(1000),
)

IF OBJECT_ID(N'dbo.PostalCode', N'U') IS NOT NULL   
    DROP TABLE dbo.PostalCode;  
CREATE TABLE dbo.PostalCode (
	Id INTEGER NOT NULL IDENTITY(1,1) PRIMARY KEY,
	CityId INTEGER FOREIGN KEY REFERENCES dbo.City(Id),
	PostalCode INTEGER
)

IF OBJECT_ID(N'dbo.Region', N'U') IS NOT NULL   
    DROP TABLE dbo.Region;  
CREATE TABLE dbo.Region (
	Id INTEGER NOT NULL IDENTITY(1,1) PRIMARY KEY,
	Region	VARCHAR(200)
)

IF OBJECT_ID(N'dbo.Country', N'U') IS NOT NULL   
    DROP TABLE dbo.Country;  
CREATE TABLE dbo.Country (
	Id INTEGER NOT NULL IDENTITY(1,1) PRIMARY KEY,
	CountryCode	VARCHAR(5)
)

IF OBJECT_ID(N'dbo.LocationName', N'U') IS NOT NULL   
    DROP TABLE dbo.LocationName;  
CREATE TABLE dbo.LocationName (
	Id INTEGER NOT NULL IDENTITY(1,1) PRIMARY KEY,
	LocationName NVARCHAR(1000),
)

IF OBJECT_ID(N'dbo.Location', N'U') IS NOT NULL   
    DROP TABLE dbo.Location;  
CREATE TABLE dbo.Location (
	Id INTEGER NOT NULL IDENTITY(1,1) PRIMARY KEY,
	LocationNameId INTEGER FOREIGN KEY REFERENCES dbo.LocationName(Id),
	Latitude DECIMAL(21,15),
	Longitude DECIMAL(21,15),
	PolygonWkt NVARCHAR(MAX),
	OperationHours NVARCHAR(1000)
)

IF OBJECT_ID(N'dbo.GeometryType', N'U') IS NOT NULL   
    DROP TABLE dbo.GeometryType;  
CREATE TABLE dbo.GeometryType (
	Id INTEGER NOT NULL IDENTITY(1,1) PRIMARY KEY,
	GeometryType VARCHAR(1000)
)

IF OBJECT_ID(N'dbo.Poi', N'U') IS NOT NULL   
    DROP TABLE dbo.Poi;  
CREATE TABLE dbo.Poi(
	Id INTEGER NOT NULL IDENTITY(1,1) PRIMARY KEY,
	ExternalId NVARCHAR(64),
	ParentId NVARCHAR(64),
	BrandId INTEGER,
	CategoryId INTEGER,
	SubCategoryId INTEGER,
	CountryId INTEGER FOREIGN KEY REFERENCES dbo.Country(Id),
	RegionId INTEGER FOREIGN KEY REFERENCES dbo.Region(Id),
	CityId INTEGER FOREIGN KEY REFERENCES dbo.City(Id),
	PostalCodeId INTEGER FOREIGN KEY REFERENCES dbo.PostalCode(Id),
	LocationNameId INTEGER FOREIGN KEY REFERENCES dbo.LocationName(Id),
	LocationId INTEGER FOREIGN KEY REFERENCES dbo.Location(Id),
	GeometryTypeId INTEGER FOREIGN KEY REFERENCES dbo.GeometryType(Id)
)

-- Set CompletedData = 1 for all records which are correct-all data which should be returned in result set are not missing
-- This could be useful logging and for later configuration (e.g. to exclude dirty data (CompletedData = 0) from result set)
-- Check: SELECT * FROM dbo.StageGeoData WHERE CompletedData = 0
--		  SELECT * FROM dbo.dbo.LogType
UPDATE sgd
SET CompletedData = 1
FROM dbo.StageGeoData sgd
WHERE country_code IS NOT NULL
	AND region IS NOT NULL
	AND city IS NOT NULL
	AND latitude IS NOT NULL
	AND longitude IS NOT NULL
	AND top_category IS NOT NULL
	AND location_name IS NOT NULL
	AND postal_code IS NOT NULL

IF EXISTS(SELECT TOP 1 1 FROM dbo.StageGeoData WHERE CompletedData = 0)
BEGIN
	INSERT INTO dbo.LogEvent
	SELECT 2, 'Some of result set parameters are missing', Id, GETDATE()
	FROM dbo.StageGeoData
	WHERE CompletedData = 0
END

-- Some validations (e.g. if brand id is missing for brand, postal code is missing for City,...)
IF EXISTS(SELECT TOP 1 1 FROM dbo.StageGeoData WHERE brand IS NOT NULL AND brand_id IS NULL)
BEGIN
	INSERT INTO dbo.LogEvent
	SELECT 2, 'Brand ID is missing for Brand: ' + brand, Id, GETDATE()
	FROM dbo.StageGeoData
	WHERE brand IS NOT NULL AND brand_id IS NULL
END

IF EXISTS(SELECT TOP 1 1 FROM dbo.StageGeoData WHERE city IS NOT NULL AND postal_code IS NULL)
BEGIN
	INSERT INTO dbo.LogEvent
	SELECT 2, 'Postal Code is missing for City: ' + city, Id, GETDATE()
	FROM dbo.StageGeoData
	WHERE city IS NOT NULL AND postal_code IS NULL
END

UPDATE sgd
SET id = LTRIM(RTRIM(Id)),
	parent_id = LTRIM(RTRIM(parent_id)),
	brand = LTRIM(RTRIM(brand)),
	brand_id = LTRIM(RTRIM(brand_id)),
	top_category = LTRIM(RTRIM(top_category)),
	sub_category = LTRIM(RTRIM(sub_category)),
	category_tags = LTRIM(RTRIM(category_tags)),
	postal_code = LTRIM(RTRIM(postal_code)),
	location_name = LTRIM(RTRIM(location_name)),
	latitude = LTRIM(RTRIM(latitude)),
	longitude = LTRIM(RTRIM(longitude)),
	country_code = LTRIM(RTRIM(country_code)),
	city = LTRIM(RTRIM(city)),
	region = LTRIM(RTRIM(region)),
	operation_hours = LTRIM(RTRIM(operation_hours)),
	geometry_type = LTRIM(RTRIM(geometry_type)),
	polygon_wkt = LTRIM(RTRIM(polygon_wkt))
FROM dbo.StageGeoData sgd

IF EXISTS(SELECT TOP 1 1 FROM dbo.StageGeoData WHERE parent_id IS NULL)
BEGIN
	UPDATE sgd
	SET parent_id = ISNULL(parent_id, '')
	FROM dbo.StageGeoData sgd
END

IF EXISTS(SELECT TOP 1 1 FROM dbo.StageGeoData WHERE brand IS NULL)
BEGIN
	UPDATE sgd
	SET brand = ISNULL(brand, '')
	FROM dbo.StageGeoData sgd
END

IF EXISTS(SELECT TOP 1 1 FROM dbo.StageGeoData WHERE brand_id IS NULL)
BEGIN
	UPDATE sgd
	SET brand_id = ISNULL(brand_id, '')
	FROM dbo.StageGeoData sgd
END

IF EXISTS(SELECT TOP 1 1 FROM dbo.StageGeoData WHERE top_category IS NULL)
BEGIN
	UPDATE sgd
	SET top_category = ISNULL(top_category, '')
	FROM dbo.StageGeoData sgd
END

IF EXISTS(SELECT TOP 1 1 FROM dbo.StageGeoData WHERE sub_category IS NULL)
BEGIN
	UPDATE sgd
	SET sub_category = ISNULL(sub_category, '')
	FROM dbo.StageGeoData sgd
END

IF EXISTS(SELECT TOP 1 1 FROM dbo.StageGeoData WHERE category_tags IS NULL)
BEGIN
	UPDATE sgd
	SET category_tags = ISNULL(category_tags, '')
	FROM dbo.StageGeoData sgd
END

IF EXISTS(SELECT TOP 1 1 FROM dbo.StageGeoData WHERE postal_code IS NULL)
BEGIN
	UPDATE sgd
	SET postal_code = ISNULL(postal_code, '')
	FROM dbo.StageGeoData sgd
END

IF EXISTS(SELECT TOP 1 1 FROM dbo.StageGeoData WHERE location_name IS NULL)
BEGIN
	UPDATE sgd
	SET location_name = ISNULL(location_name, '')
	FROM dbo.StageGeoData sgd
END

IF EXISTS(SELECT TOP 1 1 FROM dbo.StageGeoData WHERE latitude IS NULL)
BEGIN
	UPDATE sgd
	SET latitude = ISNULL(latitude, '')
	FROM dbo.StageGeoData sgd
END

IF EXISTS(SELECT TOP 1 1 FROM dbo.StageGeoData WHERE longitude IS NULL)
BEGIN
	UPDATE sgd
	SET longitude = ISNULL(longitude, '')
	FROM dbo.StageGeoData sgd
END

IF EXISTS(SELECT TOP 1 1 FROM dbo.StageGeoData WHERE country_code IS NULL)
BEGIN
	UPDATE sgd
	SET country_code = ISNULL(country_code, '')
	FROM dbo.StageGeoData sgd
END

IF EXISTS(SELECT TOP 1 1 FROM dbo.StageGeoData WHERE city IS NULL)
BEGIN
	UPDATE sgd
	SET city = ISNULL(city, '')
	FROM dbo.StageGeoData sgd
END

IF EXISTS(SELECT TOP 1 1 FROM dbo.StageGeoData WHERE region IS NULL)
BEGIN
	UPDATE sgd
	SET region = ISNULL(region, '')
	FROM dbo.StageGeoData sgd
END

IF EXISTS(SELECT TOP 1 1 FROM dbo.StageGeoData WHERE operation_hours IS NULL)
BEGIN
	UPDATE sgd
	SET operation_hours = ISNULL(operation_hours, '')
	FROM dbo.StageGeoData sgd
END

IF EXISTS(SELECT TOP 1 1 FROM dbo.StageGeoData WHERE geometry_type IS NULL)
BEGIN
	UPDATE sgd
	SET geometry_type = ISNULL(geometry_type, '')
	FROM dbo.StageGeoData sgd
END

IF EXISTS(SELECT TOP 1 1 FROM dbo.StageGeoData WHERE polygon_wkt IS NULL)
BEGIN
	UPDATE sgd
	SET polygon_wkt = ISNULL(polygon_wkt, '')
	FROM dbo.StageGeoData sgd
END

INSERT INTO dbo.Brand
SELECT DISTINCT brand, brand_id
FROM dbo.StageGeoData
WHERE brand <> '';

INSERT INTO dbo.Category
SELECT DISTINCT top_category
FROM dbo.StageGeoData
WHERE top_category <> '';

INSERT INTO dbo.SubCategory(SubCategory, CategoryId)
SELECT DISTINCT sub_category, ca.Id
FROM dbo.StageGeoData sgd
	JOIN dbo.Category ca ON sgd.top_category = ca.TopCategory 
WHERE sgd.sub_category <> ''

INSERT INTO dbo.City
SELECT DISTINCT city
FROM dbo.StageGeoData;

INSERT INTO dbo.PostalCode
SELECT DISTINCT c.Id, sgd.postal_code
FROM dbo.StageGeoData sgd
	JOIN dbo.City c ON sgd.city = c.City;

INSERT INTO dbo.Region
SELECT DISTINCT region
FROM dbo.StageGeoData;

INSERT INTO dbo.Country
SELECT DISTINCT country_code
FROM dbo.StageGeoData;

INSERT INTO dbo.LocationName
SELECT DISTINCT location_name
FROM dbo.StageGeoData 

INSERT INTO dbo.Location
SELECT DISTINCT ln.Id, sgd.latitude, sgd.longitude, sgd.polygon_wkt, sgd.operation_hours
FROM dbo.StageGeoData sgd
	JOIN LocationName ln ON sgd.location_name = ln.LocationName

ALTER TABLE dbo.Location
ADD LocationPoint GEOGRAPHY

UPDATE dbo.Location
SET LocationPoint = GEOGRAPHY::Point(Latitude, Longitude, 4326)

INSERT INTO dbo.GeometryType
SELECT DISTINCT geometry_type
FROM dbo.StageGeoData;


INSERT INTO dbo.Poi
SELECT  sgd.Id AS ExternalId, 
	ISNULL(sgd.parent_id, '') AS ParentId,
	ISNULL(br.Id, 0) AS BrandId,
	ISNULL(ca.Id, 0) AS CategoryId ,
	ISNULL(sc.Id, 0) AS SubCategoryId,
	ISNULL(co.Id, 0) AS CountryId,
	ISNULL(re.Id, 0) AS RegionId ,
	ISNULL(ci.Id, 0) AS CityId,
	ISNULL(pc.Id, 0) AS PostalCodeId,
	ISNULL(ln.Id, 0) AS LocationNameId,
	ISNULL(lo.Id, 0) AS LocationId, 
	ISNULL(ge.Id, 0) AS GeometryTypeId
FROM dbo.StageGeoData sgd
	LEFT JOIN dbo.Brand br ON sgd.brand_id = br.ExternalBrandId
	LEFT JOIN dbo.Category ca ON sgd.top_category = ca.TopCategory 
	LEFT JOIN dbo.SubCategory sc ON sgd.sub_category = sc.SubCategory AND sc.CategoryId = ca.Id
	LEFT JOIN dbo.Country co ON sgd.country_code = co.CountryCode
	LEFT JOIN dbo.Region re ON sgd.region = re.Region
	LEFT JOIN dbo.City ci ON sgd.city = ci.City
	LEFT JOIN dbo.PostalCode pc ON sgd.postal_code = pc.PostalCode
	LEFT JOIN dbo.LocationName ln ON sgd.location_name = ln.LocationName
	LEFT JOIN dbo.Location lo ON sgd.latitude = lo.Latitude AND sgd.longitude = lo.Longitude AND lo.LocationNameId = ln.Id
	LEFT JOIN dbo.GeometryType ge ON sgd.geometry_type = ge.GeometryType

