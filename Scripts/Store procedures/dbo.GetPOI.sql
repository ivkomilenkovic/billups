USE billups
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:				Ivan Milenkovic
-- Create Date:			03.09.2024.
-- Module:				POI
-- Description:			Returns the customer's company name.
-- Input parameter(s):	@inCriteria NVARCHAR(MAX) - one or more that one criteria for getting POI
-- Example:				
						/*
						DECLARE @inCriteria NVARCHAR(MAX) = '{"Region" : "NY", "POICategory" : "Grocery Stores"}'
						EXEC dbo.GetPOI @inCriteria
						*/
-- =============================================
CREATE OR ALTER PROCEDURE dbo.GetPOI 
(
    @inCriteria NVARCHAR(MAX)
)
AS
BEGIN
    
	SET NOCOUNT ON

	-- for debug purpose
	-- DECLARE @inCriteria NVARCHAR(MAX) = '{"Region" : "NY", "POICategory" : "Grocery Stores"}'

	DECLARE @Area VARCHAR(50)
	DECLARE @AreaLat DECIMAL(21,15)
	DECLARE @AreaLong DECIMAL(21,15)
	DECLARE @DummyLat DECIMAL(21,15)
	DECLARE @DummyLong DECIMAL(21,15)
	DECLARE @DummyLocation GEOGRAPHY
	DECLARE @DummyPoint VARCHAR(60)
    DECLARE @Distance FLOAT 
	DECLARE @FirstSpace INT
	DECLARE @SecondSpace INT
	DECLARE @CountryCode NVARCHAR(5)
	DECLARE @City NVARCHAR(200)
	DECLARE @Region NVARCHAR(5)
	DECLARE @Radius FLOAT
	DECLARE @Category NVARCHAR(1000)
	DECLARE @WktPolygon NVARCHAR(MAX)
	DECLARE @LocationName NVARCHAR(1000)
	
	-- Temp table to collect inputs from input parameter
	IF OBJECT_ID('tempdb..#InputCriteria') IS NOT NULL 
		DROP TABLE #InputCriteria
	CREATE TABLE #InputCriteria(
		Country			NVARCHAR(5),
		Region			NVARCHAR(5),
		City			NVARCHAR(200),
		LocationRadius	FLOAT,
		Area			VARCHAR(50),
		AreaLat			DECIMAL(21,15),
		AreaLong		DECIMAL(21,15),
		WktPolygon		NVARCHAR(MAX),
		POICategory		NVARCHAR(1000),
		POIName			NVARCHAR(1000)
	)

	-- Result temp table
	IF OBJECT_ID('tempdb..#Result') IS NOT NULL 
		DROP TABLE #Result
	CREATE TABLE #Result(
		Id				NVARCHAR(64),
		ParentId		NVARCHAR(64),
		CountryCode		NVARCHAR(5),
		City			NVARCHAR(200),
		Region			NVARCHAR(5),
		Latitude		DECIMAL(21,15),
		Longitude		DECIMAL(21,15),
		Category		NVARCHAR(1000),
		SubCategory		NVARCHAR(1000),
		WktPolygon		NVARCHAR(MAX),
		LocationName	NVARCHAR(1000),
		PostalCode		INTEGER,
		OperationHours	NVARCHAR(1000)
	)
	 
	-- Values from input parameter
	SELECT @CountryCode = value FROM OPENJSON(@inCriteria) WHERE [key] = 'Country'
	SELECT @City = value FROM OPENJSON(@inCriteria) WHERE [key] = 'City'
	SELECT @Region = value FROM OPENJSON(@inCriteria) WHERE [key] = 'Region'
	
	SELECT @Category = value FROM OPENJSON(@inCriteria) WHERE [key] = 'POICategory'
	SELECT @WktPolygon = value FROM OPENJSON(@inCriteria) WHERE [key] = 'WktPolygon'
	SELECT @LocationName = value FROM OPENJSON(@inCriteria) WHERE [key] = 'POIName'

	-- if Area (Latitude&Longitude) is passed as input (e.g. 33.503393430000074 -112.14356011499996), then extract Latitude and Longitutde from input
	SELECT @Area = value FROM OPENJSON(@inCriteria) WHERE [key] = 'Area'
	IF ISNULL(@Area, '') <> ''
	BEGIN
		-- Find the position of the first space
		SET @FirstSpace = CHARINDEX(' ', @Area);
		-- Find the position of the second space
		SET @SecondSpace = CHARINDEX(' ', @Area, @FirstSpace + 1);
		-- Find the 1st and the 2nd value from passed Area parameter
		SELECT @AreaLat = SUBSTRING(@Area,1,(CHARINDEX(' ',@Area + ' ')-1))
		SELECT @AreaLong =  SUBSTRING(
                @Area,
                @FirstSpace + 1,
                CASE 
                    WHEN @SecondSpace = 0 THEN LEN(@Area) - @FirstSpace
                    ELSE @SecondSpace - @FirstSpace - 1
                END
            )
	END
	SELECT @Radius = value FROM OPENJSON(@inCriteria) WHERE [key] = 'LocationRadius'

	-- If input is Exact location it has to  contain Latitude and Longitude
	IF(
		(ISNULL(@AreaLat, 0) <> 0 AND ISNULL(@AreaLong, 0) = 0)
		OR
		(ISNULL(@AreaLat, 0) = 0 AND ISNULL(@AreaLong, 0) <> 0)
	)
	BEGIN 
		RAISERROR ('Exact location has to contain Latitude and Longitude', 16, 1 );
	END

	-- If input is Exact location with given radius it should be completed
	IF(
		((ISNULL(@AreaLat, 0) <> 0 AND ISNULL(@AreaLong, 0) <> 0) AND ISNULL(@Radius, 0) = 0)
		OR
		((ISNULL(@AreaLat, 0) = 0 AND ISNULL(@AreaLong, 0) = 0) AND ISNULL(@Radius, 0) <> 0)
	)
	BEGIN 
		RAISERROR ('Please complet Exact location with given radius', 16, 1 );
	END
	
	INSERT INTO #InputCriteria(Country, Region, City, LocationRadius, Area, AreaLat, AreaLong, POICategory, POIName)
	SELECT Country, Region, City, LocationRadius, Area, @AreaLat AS AreaLat, @AreaLong AS AreaLong, POICategory, POIName
	FROM OPENJSON(@inCriteria)
	WITH (
			Country			NVARCHAR(5),
			Region			NVARCHAR(5),
			City			NVARCHAR(200),
			LocationRadius	INT,
			Area			VARCHAR(50),
			AreaLat			DECIMAL(21,15),
			AreaLong		DECIMAL(21,15),
			POICategory		NVARCHAR(1000),
			POIName			NVARCHAR(1000),
			WktPolygon		NVARCHAR(MAX)
	)

	-- If no search criteria is supplied, return all POIs within 200 meters of the current location-dummy location in Phoenix
	IF NOT EXISTS(SELECT TOP 1 1 FROM #InputCriteria)
	BEGIN
		SET @Distance = 200
		SET @DummyLat = 33.450225360548245
		SET @DummyLong = -111.94701703275423
		SET @DummyLocation = GEOGRAPHY::Point(@DummyLat, @DummyLong, 4326)

		INSERT INTO #Result(Id, ParentId, CountryCode, City, Region, Latitude, Longitude, Category, SubCategory, WktPolygon, LocationName, PostalCode, OperationHours)
		SELECT  po.Id, 
				po.ParentId, 
				co.CountryCode , 
				ci.City, 
				re.Region, 
				lo.Latitude, 
				lo.Longitude, 
				ca.TopCategory, 
				sc.SubCategory, 
				lo.PolygonWkt, 
				ln.LocationName, 
				pc.PostalCode, 
				lo.OperationHours 
		FROM dbo.Poi po
			JOIN dbo.Country co ON po.CountryId = co.Id
			JOIN dbo.City ci ON po.CityId = ci.Id
			JOIN dbo.Region re ON po.RegionId = re.Id
			LEFT JOIN dbo.PostalCode pc ON po.PostalCodeId = pc.Id
			LEFT JOIN dbo.LocationName ln ON po.LocationNameId = ln.Id
			JOIN dbo.Location lo ON po.LocationId = lo.Id
			LEFT JOIN dbo.Category ca ON po.CategoryId = ca.Id
			LEFT JOIN dbo.SubCategory sc ON po.SubCategoryId = sc.Id
		WHERE lo.LocationPoint.STDistance(@DummyLocation) <= @Distance
	END
	ELSE
	BEGIN

		-- if location is sent as an input the other parameters are not considering given that the exact location is the most accurate parameter to determinate object
		IF(ISNULL(@Area, '') <> '')
		BEGIN
			INSERT INTO #Result(Id, ParentId, CountryCode, City, Region, Latitude, Longitude, Category, SubCategory, WktPolygon, LocationName, PostalCode, OperationHours)
			SELECT  po.Id, 
					po.ParentId, 
					co.CountryCode , 
					ci.City, 
					re.Region, 
					lo.Latitude, 
					lo.Longitude, 
					ca.TopCategory, 
					sc.SubCategory, 
					lo.PolygonWkt, 
					ln.LocationName, 
					pc.PostalCode, 
					lo.OperationHours 
			FROM dbo.Poi po
				JOIN dbo.Country co ON po.CountryId = co.Id
				JOIN dbo.City ci ON po.CityId = ci.Id
				JOIN dbo.Region re ON po.RegionId = re.Id
				LEFT JOIN dbo.PostalCode pc ON po.PostalCodeId = pc.Id
				LEFT JOIN dbo.LocationName ln ON po.LocationNameId = ln.Id
				JOIN dbo.Location lo ON po.LocationId = lo.Id
				LEFT JOIN dbo.Category ca ON po.CategoryId = ca.Id
				LEFT JOIN dbo.SubCategory sc ON po.SubCategoryId = sc.Id
			WHERE lo.Latitude = @AreaLat AND lo.Longitude = @AreaLong
		END
		ELSE
			-- if WKT polugon is sent as an input we will pass all locations which are in a proper area
			IF(ISNULL(@WktPolygon, '') <> '')
			BEGIN
				INSERT INTO #Result(Id, ParentId, CountryCode, City, Region, Latitude, Longitude, Category, SubCategory, WktPolygon, LocationName, PostalCode, OperationHours)
				SELECT  po.Id, 
						po.ParentId, 
						co.CountryCode , 
						ci.City, 
						re.Region, 
						lo.Latitude, 
						lo.Longitude, 
						ca.TopCategory, 
						sc.SubCategory, 
						lo.PolygonWkt, 
						ln.LocationName, 
						pc.PostalCode, 
						lo.OperationHours 
				FROM dbo.Poi po
					JOIN dbo.Country co ON po.CountryId = co.Id
					JOIN dbo.City ci ON po.CityId = ci.Id
					JOIN dbo.Region re ON po.RegionId = re.Id
					LEFT JOIN dbo.PostalCode pc ON po.PostalCodeId = pc.Id
					LEFT JOIN dbo.LocationName ln ON po.LocationNameId = ln.Id
					JOIN dbo.Location lo ON po.LocationId = lo.Id
					LEFT JOIN dbo.Category ca ON po.CategoryId = ca.Id
					LEFT JOIN dbo.SubCategory sc ON po.SubCategoryId = sc.Id
				WHERE GEOGRAPHY::STGeomFromText(lo.PolygonWkt, 4326).STContains(lo.LocationPoint) = 1
			END
			ELSE
				INSERT INTO #Result(Id, ParentId, CountryCode, City, Region, Latitude, Longitude, Category, SubCategory, WktPolygon, LocationName, PostalCode, OperationHours)
				SELECT  po.Id, 
						po.ParentId, 
						co.CountryCode , 
						ci.City, 
						re.Region, 
						lo.Latitude, 
						lo.Longitude, 
						ca.TopCategory, 
						sc.SubCategory, 
						lo.PolygonWkt, 
						ln.LocationName, 
						pc.PostalCode, 
						lo.OperationHours 
				FROM dbo.Poi po
					JOIN dbo.Country co ON po.CountryId = co.Id
					JOIN dbo.City ci ON po.CityId = ci.Id
					JOIN dbo.Region re ON po.RegionId = re.Id
					LEFT JOIN dbo.PostalCode pc ON po.PostalCodeId = pc.Id
					LEFT JOIN dbo.LocationName ln ON po.LocationNameId = ln.Id
					JOIN dbo.Location lo ON po.LocationId = lo.Id
					LEFT JOIN dbo.Category ca ON po.CategoryId = ca.Id
					LEFT JOIN dbo.SubCategory sc ON po.SubCategoryId = sc.Id
				WHERE (co.CountryCode = @CountryCode OR @CountryCode IS NULL)
					AND (re.Region = @Region OR @Region IS NULL)
					AND (ci.City = @City OR @City IS NULL)
					AND (ca.TopCategory = @Category OR @Category IS NULL)
					AND (ln.LocationName = @LocationName OR @LocationName IS NULL)
		---- OPTION(RECOMPILE) because of dynamic parameters in input
		OPTION(RECOMPILE) 
	END

	-- Query to return results as GeoJSON
	SELECT
		'{
			"type": "FeatureCollection",
			"features": [' +
			STUFF((
				SELECT
					', {
						"type": "Feature",
						"geometry": {
							"type": "Point",
							"coordinates": [' + 
							CAST(Longitude AS NVARCHAR(50)) + ', ' + 
							CAST(Latitude AS NVARCHAR(50)) + ']
						},
						"properties": {
							"id": "' + Id  + '",
							"ParentId": "' + ParentId + '",
							"CountryCode": "' + CountryCode  + '",
							"City": "' + City  + '",
							"Region": "' + Region  + '",
							"TopCategory": "' + Category  + '",
							"SubCategory": "' + SubCategory + '",
							"PolygonWkt": "' + WktPolygon  + '",
							"LocationName": "' + LocationName  + '",
							"PostalCode": "' + CAST(PostalCode AS VARCHAR(10)) + '",
							"OperationHours": "' + OperationHours  + '"
						}
					}'
				FROM #Result
				FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)'), 1, 2, ''
			) + 
		']
		}' AS GeoJSON
	

END
GO

