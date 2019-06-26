/*8 - Views */

USE AdventureWorksLT2012
GO

/*1. The folowing will create a VIEW that retreives the name and address for all customers.
We use 2 joins to get the requirred infor from Customer, CustomerAddress and Address tables.*/
CREATE VIEW CustomerAddress AS
SELECT FirstName+' '+LastName AS Name, A.AddressLine1, A.AddressLine2, A.City, a.CountryRegion, a.StateProvince, a.PostalCode 
FROM SalesLT.Customer c
JOIN SalesLT.CustomerAddress ca ON c.CustomerID = ca.CustomerID
JOIN SalesLT.Address a ON ca.AddressID = a.AddressID
GO

/*2. We canfurther tweek the above VIEW and create a view for customers from a specific country.
Below I have created a view for customers from the US*/
CREATE VIEW CustomerUSA AS
SELECT FirstName+' '+LastName AS Name, A.AddressLine1, A.AddressLine2, A.City, a.StateProvince, a.PostalCode 
FROM SalesLT.Customer c
JOIN SalesLT.CustomerAddress ca ON c.CustomerID = ca.CustomerID
JOIN SalesLT.Address a ON ca.AddressID = a.AddressID
WHERE a.CountryRegion = 'United States'
GO

/*3. Another way to get a specific country would be to reuse the first view with a WHERE clause on CountryRegion.
This would provide the same result with a much simpler SELECT - one of the benefits of views*/
CREATE VIEW CustomersCanada AS
SELECT * FROM CustomerAddress 
WHERE CountryRegion = 'Canada'
GO



USE AdventureWorks2016
GO

/*4. The next VIEW gets the data from an aggregat select done on inventory table and joins it with  product table.
To get the reorder buffer we substrackt the total in inventory from the safetysotck level.*/
CREATE VIEW ReorderBuffer AS
SELECT p.productId, p.Name, i.stock-p.SafetyStockLevel AS ReorderBuffer 
FROM Production.Product p
JOIN (SELECT productID, sum(Quantity) AS Stock 
		FROM Production.ProductInventory
		GROUP BY ProductID) i 
 ON p.ProductID=i.ProductID
 GO

/*5. The below will generate a VIEW of prodcucts that are in special offer and are discount is different then 0. */
CREATE VIEW SpecialOffer AS
SELECT P.Name AS Product, so.Description, so.DiscountPct, so.MinQty, so.MaxQty
FROM Production.Product p 
Left Outer JOIN Sales.SpecialOfferProduct sp ON sp.ProductID = p.ProductID
JOIN Sales.SpecialOffer so ON so.SpecialOfferID = sp.SpecialOfferID
WHERE so.DiscountPct <> 0.00
GO

/*6. Next we have a view that is using a subquery. In the subquery we get average sales by entityID.
As we join with person table we get the name associated with the entityID.
With the next 2 joins retreive the name of the territory for the specific person. */
CREATE VIEW AverageSalesTeritory AS
SELECT p.FirstName, p.LastName, st.Name AS Territory, av.AverageSales 
FROM Person.Person p
JOIN (
	SELECT S.BusinessEntityID, AVG(S.SalesQuota) AS AverageSales FROM Sales.SalesPersonQuotaHistory S
	GROUP BY S.BusinessEntityID) 
	AS av ON av.BusinessEntityID = P.BusinessEntityID
JOIN Sales.SalesPerson sp ON sp.BusinessEntityID = av.BusinessEntityID
JOIN Sales.SalesTerritory st ON st.TerritoryID = sp.TerritoryID
GO

/*7. The below VIEW will display the product name and using 2 subqueries joined by the product ID we can 
retreive the MIN and  MAX production cost*/
CREATE VIEW MinMaxProductionCost AS
SELECT p.ProductID, p.Name,p.ListPrice,mi.Minimum,ma.Maximum 
FROM Production.Product P
JOIN (SELECT ProductID, MIN(StandardCost) AS Minimum 
		FROM Production.ProductCostHistory 
		GROUP BY ProductID) mi 
ON p.ProductID = mi.ProductID
JOIN (SELECT ProductID, MAX(StandardCost) AS Maximum 
		FROM Production.ProductCostHistory 
		GROUP BY ProductID) ma
ON p.ProductID = ma.ProductID
GO

/*8. We can reuse the above VIEW and calculate the minimum and maximum margin on product. I have joined the
above view with two selects that retreive the min and max list price cost. 
Originaly the above view did not included the ProductID however if we include it the VIEW becomes mutch
more versatile, and can be reused in other SELECTS/VIEWS easyer*/
CREATE VIEW PriceMarginHistory AS
SELECT p.ProductID, p.Name, mi.Minimum-p.Minimum AS MinimumMargin, ma.Maximum-p.Maximum AS MaximumMargin
FROM MinMaxProductionCost p 
JOIN (SELECT ProductID, MIN(ListPrice) AS Minimum 
		FROM Production.ProductListPriceHistory 
		GROUP BY ProductID) mi 
ON p.ProductID = mi.ProductID
JOIN (SELECT ProductID, MAX(ListPrice) AS Maximum 
		FROM Production.ProductListPriceHistory 
		GROUP BY ProductID) ma
ON p.ProductID = ma.ProductID
GO


/*12- Stored Procedures*/

/*1. This is a stored procedre to get employees with more then 30 sick days.
First we USE the cadvetureworks2016 db. Then the if statment verifies the existance of sproc hrInfo and delete it
in case it exists. next we create the sproc with a straight forward select and join on employee and person tables, */
USE AdventureWorks2016
GO
IF OBJECT_ID('hrInfo') IS NOT NULL
	DROP PROC copyTable;
GO

CREATE PROC hrInfo AS 	
	SELECT p.FirstName, p.MiddleName, p.LastName, JobTitle, VacationHours, SickLeaveHours	
	FROM HumanResources.Employee e
	JOIN Person.Person p ON p.BusinessEntityID = e.BusinessEntityID
	WHERE e.SickLeaveHours >30;

/*2. The following proc is retreiving data from production sequence and replaces product Id and location ID with their names.*/
IF OBJECT_ID('prodSequence') IS NOT NULL
	DROP PROC prodSequence;
GO
CREATE PROC prodSequence AS
	SELECT p.name AS ProductName, l.Name AS ProductLocation, wr.OperationSequence, wr.ScheduledEndDate, WR.ScheduledStartDate 
	FROM Production.WorkOrderRouting wr
	JOIN Production.Product p ON p.ProductID = wr.ProductID
	JOIN Production.Location l ON l.LocationID = wr. LocationID

/*3. This procedure will reuse a view created earlier. We join with product and vendor table to get the name of product and vendor 
instead of IDs, and set a condition to retreive the products that have a negative reorder buffer. We can see the vendors that 
we can buy the products from aswell standard price and average lead time.*/
IF OBJECT_ID('reorder') IS NOT NULL
	DROP PROC reorder
GO
CREATE PROC reorder AS
 SELECT p.Name, v1.Name, v.MinOrderQty, v.MaxOrderQty, v.AverageLeadTime, v.StandardPrice FROM Purchasing.ProductVendor v
  JOIN Production.Product p ON p.ProductID = v. ProductID
  JOIN Purchasing.Vendor v1 ON v.BusinessEntityID = v1.BusinessEntityID 
  JOIN ReorderBuffer r ON v.ProductID = r.productId
  WHERE R.ReorderBuffer < 0;

  /*4. The folowing sproc will get us all the stores from Europe. We use 4 joins to get the full address and set the condition
  on countryRegionCode */
IF OBJECT_ID('europeStore') IS NOT NULL
	DROP PROC europeStore
GO
CREATE PROC europeStore AS
  SELECT s.Name, ad.AddressLine1, ad.AddressLine2, ad.City, s1.Name AS State, st.Name AS Country FROM sales.Store s
  JOIN Person.BusinessEntityAddress a ON a.BusinessEntityID = s.BusinessEntityID
  JOIN Person.Address ad ON ad.AddressID = a.AddressID
  JOIN Person.StateProvince s1 ON s1.StateProvinceID= ad.StateProvinceID
  JOIN sales.SalesTerritory st ON st.TerritoryID = s1.TerritoryID
  WHERE st.CountryRegionCode IN ('FR','DE','GB')

/*5. Next stored procedure creats a copy of a table*/

USE RedBullF1
GO
IF OBJECT_ID('addressCopy') IS NOT NULL
	DROP PROC addressCopy
GO
	
CREATE PROC addressCopy AS
	IF OBJECT_ID('RedBullF1.dbo.PersonCopy') IS NOT NULL
		DROP TABLE RedBullF1.dbo.PersonCopy
	SELECT * 
	INTO RedBullF1.dbo.PersonCopy
	FROM RedBullF1.dbo.Person;

/*6. Using the above created table we will insert a row using stored procedure*/

IF OBJECT_ID('insertPerson') IS NOT NULL
	DROP PROC insertPerson
GO

CREATE PROC insertPerson 
	@PersonID smallint = NULL,
	@FirstName varchar(15) = NULL,
	@LastName varchar(15) = NULL,
	@Dob date = NULL,
	@PhoneNumber varchar(20) = NULL

AS
INSERT INTO dbo.PersonCopy
VALUES(@PersonID,@FirstName,@LastName,@Dob,@PhoneNumber)


EXEC insertPerson
	@PersonID = 7,
	@FirstName = 'Dave',
	@LastName = 'Goodman',
	@Dob = '09.15.1993',
	@PhoneNumber = '0053966374623';



  /*7. We can evolve the above procedure to include validation for PersonID and DOB. First the procedure checks if there
  is a PersonID inserted from the EXEC, if not the procedure will find the highest ID and increments it for the new row.
  If there is an ID coming from the EXEC it is checked if it was allready used (as this is the PK) if yes we generate
  an error. Second validation is done on DOB with a DATEDIFF on days, as we need person to be older then 18 at the time
  of hiring. 
  When executing the procedure we have the option to insert the PersonId or leav it NULL and let the procedure generate it.
  We use a TRY when runing the script and a CATCH to retreive the errors and display it to the user.*/
  IF OBJECT_ID('insertPerson') IS NOT NULL
	DROP PROC insertPerson
GO

CREATE PROC insertPerson 
	@PersonID smallint = NULL,
	@FirstName varchar(15) = NULL,
	@LastName varchar(15) = NULL,
	@Dob date = NULL,
	@PhoneNumber varchar(20) = NULL
AS
IF @PersonID IS NULL 
	SET @PersonID = (SELECT MAX(PersonID) FROM RedBullF1.dbo.PersonCopy)+1;
ELSE
	IF @PersonID IN (SELECT PersonID FROM RedBullF1.dbo.PersonCopy)
	THROW 50001, 'personID is allready in use!',1;
IF DATEDIFF(DAY,@Dob,GETDATE())<6574
	THROW 50001, 'employee must be older then 18!',1;
INSERT INTO dbo.PersonCopy
VALUES(@PersonID,@FirstName,@LastName,@Dob,@PhoneNumber);


BEGIN TRY	
	EXEC insertPerson
		@PersonID = NULL,
		@FirstName = 'Dave',
		@LastName = 'Goodman',
		@Dob = '09.15.2001',
		@PhoneNumber = '0053966374623';
END TRY
BEGIN CATCH
	PRINT 'Error, information was not inserted.'
	PRINT 'Correct the following: ' + CONVERT(varchar, ERROR_MESSAGE());
END CATCH

/*8. We can modify our procedure returning european stores to take in a parameter a country code and use this to generate out result.
The procedure validates if the country code from the argument exists in our DB.
Then we can call the procedure in a TRY CATCH and display an error message in case we have an incorrect/none existemt ID.*/
USE AdventureWorks2016
GO

IF OBJECT_ID('euStoreIn') IS NOT NULL
	DROP PROC euStoreIn
GO

CREATE PROC euStoreIn 
	@StoreCountry nvarchar(20) 
AS
	IF @StoreCountry NOT IN (SELECT CountryRegionCode FROM sales.SalesTerritory)
		THROW 50001, 'CountryID does not exist in DB',1;
	 SELECT s.Name, ad.AddressLine1, ad.AddressLine2, ad.City, s1.Name AS State, @StoreCountry AS Country FROM sales.Store s
	JOIN Person.BusinessEntityAddress a ON a.BusinessEntityID = s.BusinessEntityID
	JOIN Person.Address ad ON ad.AddressID = a.AddressID
	JOIN Person.StateProvince s1 ON s1.StateProvinceID= ad.StateProvinceID
	JOIN sales.SalesTerritory st ON st.TerritoryID = s1.TerritoryID
	WHERE st.CountryRegionCode LIKE @StoreCountry

BEGIN TRY 
	EXEC euStoreIn 'DE'; 
END TRY
BEGIN CATCH
	PRINT 'Error, informaiton not inserted.' + CONVERT(varchar, ERROR_MESSAGE());	
END CATCH

/*9.a. The next procedure will use RETURN. We input the first an last name, and the procedure will return the salary.
To retreive the salary I have used a  join on businessentityID between PayHistory and Person tables with a condition 
to match the first and last name.  Since there are employees with multiple entries a subselect is used to get the 
most recent salary with MAX DATE. 
We use validation on name and return error if name is not matched. First we try to match the last name and if we find it we
try to match the first name coresponding to that last name. In case all match up and person is employee(condition set in first if)
we look up and return the salary and */
IF OBJECT_ID('salaryEmp') IS NOT NULL
	DROP PROC salaryEmp
GO

CREATE PROC salaryEmp
	@FirstName nvarchar(50),
	@LastName nvarchar(50)
AS
	IF(@LastName NOT IN (SELECT LastName FROM Person.Person WHERE PersonType = 'EM' )) 
	THROW 50001, ' Name does not match any records',1;
	ELSE
	IF(@FirstName NOT IN (SELECT FirstName FROM Person.Person WHERE LastName = @LastName))
	THROW 50001, ' Name does not match any records',1;
	RETURN(SELECT e.Rate FROM HumanResources.EmployeePayHistory e
	JOIN Person.Person p ON p.BusinessEntityID = e.BusinessEntityID
	WHERE e.ModifiedDate = (SELECT MAX(ModifiedDate) FROM HumanResources.EmployeePayHistory)
	AND p.FirstName = @FirstName AND p.LastName = @LastName);

BEGIN TRY 
	DECLARE @sa money;
	EXEC @sa= salaryEmp Terri, Duffy;	
	PRINT  'salary:'+CONVERT(varchar(6),@sa);
END TRY
BEGIN CATCH
	PRINT CONVERT(varchar(50), ERROR_MESSAGE());
END CATCH

/* 9.b. The when using return in the above procedure the decimal is getting truncated. With OUTPUT PARAMETERS 
as below we get a correct result.*/

IF OBJECT_ID('salaryEmp') IS NOT NULL
	DROP PROC salaryEmp
GO

CREATE PROC salaryEmp	
	@sal money OUTPUT,
	@FirstName nvarchar(50),
	@LastName nvarchar(50)
AS
	IF(@LastName NOT IN (SELECT LastName FROM Person.Person WHERE PersonType = 'EM' )) 
	THROW 50001, ' Name does not match any records',1;
	ELSE
	IF(@FirstName NOT IN (SELECT FirstName FROM Person.Person WHERE LastName = @LastName))
	THROW 50001, ' Name does not match any records',1;
	SELECT @sal=e.Rate FROM HumanResources.EmployeePayHistory e
	JOIN Person.Person p ON p.BusinessEntityID = e.BusinessEntityID
	WHERE e.ModifiedDate = (SELECT MAX(ModifiedDate) FROM HumanResources.EmployeePayHistory)
	AND p.FirstName = @FirstName AND p.LastName = @LastName;

BEGIN TRY 
	DECLARE @sa money;
	EXEC salaryEmp @sa OUTPUT, Terri, Duffy;	
	PRINT  'salary:'+CONVERT(varchar(6),@sa);
END TRY
BEGIN CATCH
	PRINT CONVERT(varchar(50), ERROR_MESSAGE());
END CATCH


/*10. Return the items of a sales order by orederID. 
First we declare an int parameter. We validate the input parameter by checking if we have the orderID in our table.
If not we generate error message. If the ID is valid we select the name, order quantity and line total by joining 
salesOrderDetails with product table. Finaly we need to find the requested order using th WHERE clause and the input parameter.
On executing the procedure we use try and catch to pick up any invalid salesOrderID.   */
IF OBJECT_ID('orderDetail') IS NOT NULL
	DROP PROC orderDetail
GO

CREATE PROC orderDetail
	@salesOrderID int
AS
	IF(@salesOrderID NOT IN (SELECT SalesOrderID FROM Sales.SalesOrderDetail))
	THROW 50001, 'OrderID is not valid',1;
	SELECT p.Name, s.OrderQty, s.LineTotal FROM Sales.SalesOrderDetail s
	JOIN Production.Product p ON p.ProductID = s.ProductID
	WHERE s.SalesOrderID = @salesOrderID;
GO

BEGIN TRY
	EXEC orderDetail 43659;
END TRY
BEGIN CATCH
	PRINT CONVERT(varchar(50), ERROR_MESSAGE());
END CATCH


 /*11. Total sales between 2 dates. The below procedeure has one output parameter and 2 input parameters that are optional.
 In case there is no input for dates, we will assign the first date for begingin and todays date to enddate.
 In case there is only one date parameter given, this will be considered begingin date and end date will default to today.
 The select then returns the sum of sales between the given dates and returns this to outparameter.
 When executing the procedure we declare first the output parameter and the result will be return in this parameter.
 Print will display this to the user.*/
 IF OBJECT_ID('totalSalesByDate') IS NOT NULL
	DROP PROC totalSalesByDate
GO

CREATE PROC totalSalesByDate
	@total money OUTPUT,
	@beginDate datetime = NULL,
	@endDate datetime = NULL
AS
	IF @beginDate IS NULL
	SELECT @beginDate=MIN(OrderDate) FROM Sales.SalesOrderHeader;
	IF @endDate IS NULL
	SELECT @endDate = GETDATE(); 
	SELECT @total=SUM(TotalDue) FROM SALES.SalesOrderHeader 
	WHERE OrderDate >= @beginDate AND OrderDate <=@endDate;
GO

DECLARE @total money;
EXEC totalSalesByDate @total OUTPUT, '05.31.2011','05.31.2011';
PRINT 'Total:' + CONVERT(VARCHAR(20), @total);

 /*12. For the next procedure I have furthere developed the previous sproc. In order to get sales details based on territory
 I have added another parameter - territory optional. If territory is omited, we will generate results per all territorys.
 In case we have entered a territory, we then validate if it is existing in our DB. If yes we run the select and retreive 
 the sum total of sales between dates and matching territory. Else we generate an  error. 
 When calling the procedure I have passed the parameters by name instead of just position, this case we can omit the dates.
 If we would like to call the procedure by only the position of parameters, and omit one of the dates will give error as it will
 try to convert the territory to a date.  */
   IF OBJECT_ID('totalSalesByTerritory') IS NOT NULL
	DROP PROC totalSalesByTerritory
GO

CREATE PROC totalSalesByTerritory
	@total money OUTPUT,	
	@beginDate datetime = NULL,
	@endDate datetime = NULL,
	@territory nvarchar(50) = NULL
AS
	IF @beginDate IS NULL
	SELECT @beginDate=MIN(OrderDate) FROM Sales.SalesOrderHeader;
	IF @endDate IS NULL
	SELECT @endDate = GETDATE(); 
	IF(@territory IS NULL)
		SELECT @total=SUM(TotalDue) FROM SALES.SalesOrderHeader 
		WHERE OrderDate >= @beginDate AND OrderDate <=@endDate;
	ELSE
	IF(@territory NOT IN (SELECT Name FROM Sales.SalesTerritory))
		THROW 50001, 'Territory is not valid',1;
	ELSE
		SELECT @total=SUM(s.TotalDue) FROM SALES.SalesOrderHeader s
		JOIN Sales.SalesTerritory t ON s.TerritoryID = t.TerritoryID
		WHERE s.OrderDate >= @beginDate AND s.OrderDate <=@endDate AND t.Name = @territory;
GO

BEGIN TRY
	DECLARE @total money;
	EXEC totalSalesByTerritory @total OUTPUT,
		@beginDate ='05.31.2011',
		@endDate = '05.31.2011',
		@territory = 'Central';
	PRINT 'Total:' + CONVERT(VARCHAR(20), @total);
END TRY
BEGIN CATCH
	PRINT CONVERT(varchar(50), ERROR_MESSAGE());
END CATCH