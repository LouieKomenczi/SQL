USE AdventureWorks2016;
/*due - 16.02.2019 @10PM */


/*1 Management is looking to find the top 10 cost of products scraped  in the year 2013. 
To deliver this query I have used SELECT TOP 10 with a join between workorder and product. Grouped the select by name, and count the name, hence giving us the number of workorders affected. The total cost was delivered by the SUM function. Where clause defined the date interval, and set out the condition for ScrapReasonId to be not NULL resulting in a  scraped product. Finally we have ordered it by cost descending */


SELECT TOP 10 p2.Name
		, SUM(p2.StandardCost) AS [Total Cost]
		, COUNT(p2.Name) AS [Work Orders Affected] 
  FROM Production.WorkOrder p1
  JOIN Production.Product p2 ON p1.ProductID = p2.ProductID
  WHERE ScrapReasonID is not null AND (p1.EndDate BETWEEN '2013-01-01' AND '2014-01-01')
  GROUP BY Name
  ORDER BY [Total Cost] DESC;


/*2 For this SELECT the request is to find out all the items in stock that are below the reorder point. 
We need to access 2 tables to get all the information. The product inventory has the current stock. The product table has the name and the reorder point. The query returns the product ID, product name and the current stock. Join pulls the name based on ProductID. Stock is added up and grouped by productId. With the HAVING keyword we further constrict the query to return only the ones that the stock level is under reorder point, which is retrieved by a SELECT from product where the productID match up.*/


SELECT p1.ProductID
		, p2.Name
		,  SUM(Quantity) AS [Stock]  
FROM Production.ProductInventory p1
JOIN Production.Product p2 on p2.ProductID = p1.ProductID
GROUP BY p1.ProductID,p2.Name
HAVING SUM(Quantity)<(
			SELECT ReorderPoint 
			FROM Production.Product 
			WHERE p1.ProductID = ProductID );


/*3 Human resources are reviewing the salaries and are looking for employees who never had a raise and make less than average of employees.
I have built the query on a select that groups by bussinesEntityID the employeePayHistory and then finds the employees who appear one time only in this list. Further we constrict the query by another select that averages the employee rate in the company.2 Joins are pulling the first name, last name and the job title. The result is ordered by the salary date oldest being the first, as this would be the order to review the salary  */


SELECT p.FirstName
	, p.LastName
	, h1.JobTitle
	, h.Rate
	, CONVERT (varchar(12), h.RateChangeDate, 103) AS [Salary Set Date]
FROM HumanResources.EmployeePayHistory h
JOIN HumanResources.Employee h1 ON h1.BusinessEntityID=h.BusinessEntityID
JOIN Person.Person p ON p.BusinessEntityID=h.BusinessEntityID
	WHERE h.BusinessEntityID 
	IN( SELECT BusinessEntityID FROM HumanResources.EmployeePayHistory
		GROUP BY BusinessEntityID
		HAVING COUNT(BusinessEntityID)=1) 
	AND h.Rate < (SELECT AVG(Rate) FROM HumanResources.EmployeePayHistory)
ORDER BY RateChangeDate;


/*4 Management request a list of personnel movements between departments.
To realize this query I started out by singling out the employees who have multiple entries in the department history. This was done by GROUPING the records by BussinessEntityID and set a condition in place to show only the ones with more then 1 entry. At this point we have the BussinesEntityID for the persons who moved between departments. Then department history table was listed on the condition to have the previous results, hence all the records that contain the BussinesEntityID that moved between departments. After this I used the joins to retrieve, department name, start date and  the persons first, middle and last name. I have set a condition to insert nothing if middle name is NULL(else we have a NULL entry for name). Date was formatted to DD MMM YYYY    Finally this was ordered by Lastname and date.*/


SELECT p.FirstName+' '+ISNULL(P.MiddleName,'')+' ' + p.LastName AS [Name]
	, h1.Name AS [Departament]
	, CONVERT( varchar(12), h.StartDate, 106) AS [Start Date] 
FROM HumanResources.EmployeeDepartmentHistory h
JOIN HumanResources.Department h1 ON h.DepartmentID = h1.DepartmentID
JOIN HumanResources.Employee h2 ON h2.BusinessEntityID = h.BusinessEntityID
JOIN Person.Person p ON h.BusinessEntityID = p.BusinessEntityID	
WHERE h.BusinessEntityID IN( 
		SELECT   BusinessEntityID 
		FROM HumanResources.EmployeeDepartmentHistory  
		GROUP BY BusinessEntityID
		HAVING COUNT(BusinessEntityID) >1)
ORDER BY p.LastName, h.StartDate;


/*5 Yellow jersey competition, - to boost sales on jerseys: the sales person who sales the most jerseys in the first half year, gets the symbolic yellow jersey and an extra 15% on sales. Second place gets 10% and third 5%. Management asked for the top 3.
I begin this task using the WITH clause, and using a subquery that gathers the SalesOrdersID and the quantity on the order joined with the product table where the product name includes the key word jersey, and the date is in between 1.Jan and 30.June. Then I have selected the top 3 and displayed the SalesPersonID, number sold - by counting the number of entries ordered by SalesPersonID, and first and last name. The first join is needed to get the salesPersonID based on SalesOrderID, the second join gets us the name of the sales person based on SalesPersonID. Finally the result was ordered descending.*/


WITH jersy AS ( SELECT  s.SalesOrderID as id, s.OrderQty
				FROM [AdventureWorks2016].[Production].[Product] p
				join Sales.SalesOrderDetail s ON p.ProductID = s.ProductID  
				WHERE [Name] like '%Jersey%' and s.ModifiedDate between '2014-1-1' and '2014-6-30')
SELECT TOP 3  s.SalesPersonID, 
			COUNT(s.SalesPersonID) AS [number sold]
			, p.LastName
			, p.FirstName FROM jersy j
JOIN sales.SalesOrderHeader s ON j.id=s.SalesOrderID  
JOIN Person.Person p ON s.SalesPersonID = p.BusinessEntityID
GROUP BY SalesPersonID, p.LastName, p.FirstName
ORDER BY [number sold] DESC;

/*6 The request is to generate a list of all employees on dayshift, with name and departments. 
Since the common ground for all information is in humanResources.EmployeeDepartmentHistory, we start the select with this table. Then we join with the Shift table on shiftID so we can set the condition for day shift. Further we set a condition on endDate to be NULL so we know the employee is still hired. Next we join with person table form person.person table on businessEntityID so we can get the name of persons. Finally we retrieve the department name by joining with department table on departmentID. I have set result to be ordered by department name, then last name and first name.*/


SELECT p.FirstName
	,p.MiddleName
	, p.LastName
	, d.Name AS [Department] 
FROM HumanResources.EmployeeDepartmentHistory h
JOIN HumanResources.Shift s ON s.ShiftID=h.ShiftID
JOIN Person.Person p ON p.BusinessEntityID = h.BusinessEntityID
JOIN HumanResources.Department d ON d.DepartmentID = h.DepartmentID
WHERE s.Name = 'day' AND h.EndDate IS NULL
ORDER BY d.Name, p.LastName, p.FirstName;

/*7 Management would like to take a look at our reviews that are less than 5 in order to get to the bottom of customer dissatisfaction. 
A simple select however a potentially very important one if we have allot of online sales. We return name of the reviewer, rating, comments and email in order to reply. The join is done between production.productReview table and production.product tables on prodcuctID. Condition is set to rating below 5 The same query was done by replacing JOIN with WHERE clause.*/


SELECT p2.name
	,p1.ReviewerName
	, p1.Rating
	, p1.Comments
	, p1.EmailAddress 
FROM production.productreview p1
JOIN Production.Product p2 on p1.ProductID = p2.ProductID
WHERE p1.Rating< 5;

SELECT p2.name
	,p1.ReviewerName
	, p1.Rating
	, p1.Comments
	, p1.EmailAddress 
FROM production.productreview p1, Production.Product p2
WHERE p1.Rating< 5 and p1.ProductID = p2.ProductID;

/*8 The next select displays all the business from Germany. Again, in this query I have replaced the joint and used WHERE to achieve the same result.
We pick the information from four tables, sales.Store, person.Address, person.BusinessEntityAddress and person.StateProvince. The where clause sets out that businessEntityID has to match between store and address further addressID has to match up in businessID and address table. Then we match up the stateProvinceID as the State is kept in  a separate table, stateProvince and finally we set out the condition for coountryRegionCode to match DE for Germany */


SELECT s.Name
	, a.AddressLine1
	, a.AddressLine2
	, a.City 
FROM Sales.Store s, 
	Person.Address a, 
	Person.BusinessEntityAddress b, 
	Person.StateProvince p
WHERE s.BusinessEntityID= b.BusinessEntityID 
	AND b.AddressID = a.AddressID 
	AND	a.StateProvinceID = p.StateProvinceID 
	AND p.CountryRegionCode = 'de' ;




  /*9. SELF Join 
Purchasing requires a list of products that are supplied by more then one vendors.
We will use a self join on purchasing.productVendor to complete this query. As this is a self join we call the same table two times and name it p1 and p2.The join is done on productID and we are looking for different vendors hence the where condition is p1.businessEntityId different form p2. The table generated is further processed and we attached a name to productID and vendor ID, to make the information more accessible. */


WITH compare AS (
			SELECT  p1.ProductID
				,   p1.BusinessEntityID
				,   p1.AverageLeadTime
				,   p1.StandardPrice  
			FROM Purchasing.ProductVendor p1
			JOIN Purchasing.ProductVendor p2 ON p1.ProductID = p2.ProductID
			WHERE p1.BusinessEntityID <> p2.BusinessEntityID)
SELECT c.ProductID
	,  p.Name
	,  v.name
	,  c.AverageLeadTime
	,  c.StandardPrice 
FROM compare c
JOIN Production.Product p ON p.productID = c.productID
JOIN Purchasing.Vendor v ON v.BusinessEntityID = c.BusinessEntityID
ORDER BY ProductID


/*10. Left Join 
Management is asking for a list of sales done in 2011 December by sales agents. 

To make a full list and include the sales persons who did not had any sales in December I uses a left join. This would allow to have all the sales persons in the result. First I started out by generating a temporary view with all the sales between the 1st and 31st of Dec. This view then is used to left join with the salesPerson table. Further I have used a second join to get the first and last name of the persons and another left join to get the sales territory name. Since we have persons with undefined territory without the left join we would not get them returned in our result. */


WITH december AS (
			SELECT * 
			FROM sales.SalesOrderHeader h 
			WHERE OrderDate between '2011-12-01' and  '2011-12-31')
SELECT pe.FirstName
	,  pe.LastName
	,  t.name AS [Territory]
	,  p.SalesYTD
	,  p.CommissionPct
	,  d.SalesOrderNumber 
FROM sales.SalesPerson p
LEFT JOIN december d ON p.BusinessEntityID = d.SalesPersonID
JOIN Person.Person pe ON pe.BusinessEntityID = p.BusinessEntityID
LEFT JOIN Sales.SalesTerritory t ON t.TerritoryID = p.TerritoryID
ORDER BY SalesYTD;

/*11. Right join 
The requirement for the next query is to generate a list with the price history of the products and include the products that do not have a price history.

To realize this we will use a right join between productionCostHistory and product table. Right join will pick up all the rows from the product table and the ones that match up by productid from productionCostHistory. The rows in prodcutionCostHistory that do not have a corresponding match in product, will have NULL data in the join result. */


SELECT p.Name
	,  p.ProductNumber
	,  p.ProductID
	,  h.* 
FROM Production.ProductCostHistory h
RIGHT JOIN Production.Product p ON p.ProductID = h. ProductID
ORDER BY P.ProductID;

/*12. Full join with as second DB* 
A full join is uses when we need to retrieve information from both tables regardless if they match ON condition. A possible use case would be to compare two tables and see what rows are matching up and what rows are appearing only in one of the tables (both left or right).
In our example we compare Adventure Works Lite and full version, particularly the product table. To access table from two different DB we need to mention the DB name in front of the table name. The SELECT works retrieves product id, product name from both tables and displays it ordered by product ID of the first table.*/


SELECT p1.ProductID AS [AW2016 Product ID]
	,  p1.Name AS [AW2016 Product Name]
	,  p2.ProductID AS [AWLT Product ID]
	,  p2.Name AS [AWLT Product Name]
FROM AdventureWorks2016.Production.Product p1
FULL JOIN AdventureWorksLT2012.SalesLT.Product p2 ON p1.ProductID=p2.ProductID
ORDER BY p1.ProductID;

 /*13 Requirement for the next query is to return top 100 list with customers who reorder the same items.
In the result we display the first and last name as name, in case the person has middle name(determined by the IIF) we take the initial of the middle name using LEFT. We also display the product and how many times was ordered with COUNT function. The name is picked from the person table, this is joined with salesOrderheader and salesOrderDetail to get the product. Further we join with production.product to get the name of the product. This is grouped by lastName, firstName and productID, ordered by number of reorders descending. */


SELECT TOP 100 
		IIF(p.MiddleName IS NULL,p.FirstName+' '+ p.LastName,p.FirstName+' '+LEFT(p.MiddleName,1)+'. '+ p.LastName) AS [Name]
		, pr.Name AS [Product]
		, COUNT(pr.Name) AS [Number]
FROM Person.Person p
JOIN Sales.SalesOrderHeader h ON p.BusinessEntityID = h.CustomerID
JOIN sales.SalesOrderDetail d ON h.SalesOrderID = d.SalesOrderID
JOIN Production.Product pr ON d.ProductID = pr.ProductID
GROUP BY p.LastName, p.MiddleName, p.FirstName, pr.Name
ORDER BY [Number] DESC;

/*14 Compound join
Retrieve all sales on special offer for product 770
In order to get the requested information we need to join specialOfferProduct table with salesOrderDetails on specialOfferID and productID. We further restrict the search */


SELECT p.SpecialOfferID
	,p.ProductID
	,d.SalesOrderID
	,d.OrderQty
	,d.UnitPrice
	,d.LineTotal
	,d.ModifiedDate
FROM Sales.SpecialOfferProduct p
join sales.SalesOrderDetail d ON d.SpecialOfferID = p.SpecialOfferID AND d.ProductID = p.ProductID
WHERE p.ProductID LIKE '770'


/*15 Compound join
Next query does a comparation on payment rate in information services department for year 2009.
First, I ran a select in department to find out the departmentID for information services. This is 11. Then I joined the employeePayHistory to itself on bussinesEntittyID to be different (as we compare the employees between themselves) and the payFrecuency to be the same. Further I made sure that the bussinessEntityID would be in department 11 by using IN and constructing a select that would return the bussinessEntityID from the required department. Last option was to set the modified date to year 2009.*/


SELECT h1.BusinessEntityID
	, h1.rate
	, h2.rate
	, h2.BusinessEntityID 
FROM HumanResources.EmployeePayHistory h1
JOIN HumanResources.EmployeePayHistory h2 ON h1.BusinessEntityID <> h2.BusinessEntityID AND h1.PayFrequency = h2.PayFrequency
WHERE h1.BusinessEntityID IN (SELECT BusinessEntityID 
								FROM HumanResources.EmployeeDepartmentHistory e
								JOIN HumanResources.Department  d ON e.DepartmentID = d.DepartmentID
								WHERE d.DepartmentID = 11) 
	and h2.BusinessEntityID IN (SELECT BusinessEntityID 
								FROM HumanResources.EmployeeDepartmentHistory e
								JOIN HumanResources.Department  d ON e.DepartmentID = d.DepartmentID
								WHERE d.DepartmentID = 11) 
	and YEAR(h1.RateChangeDate ) = 2009

/*16 Compound join
Who is equal and above the Engineering Manager in the organization?
To realize this query I have joined the humanResources.Employee table to itself on job title to be different, as we do not want to return the Engineering Manager and organization level to be equal or higher. The where clause sets out the job title we are setting out to compare, in our case Engineering Manager. The result is ordered by organization level increasing and job title alphabetically. */


SELECT e1.BusinessEntityID
	, e1.OrganizationLevel
	,e1.JobTitle
	,e2.BusinessEntityID
	,e2.OrganizationLevel
	,e2.JobTitle	
FROM HumanResources.Employee e1
JOIN humanresources.Employee e2  ON e1.JobTitle <> e2.JobTitle AND e1.OrganizationLevel >= e2.OrganizationLevel
WHERE e1.JobTitle LIKE 'Engineering%'
ORDER BY e2.OrganizationLevel, e2.JobTitle

/*17 Compound join
Next request is for a List that gives us all the alternative locations for products from A shelf.

Again, I have used a self join this time on productInventory table from production. The conditions are to be in a different row and to have the same productID so we get a relevant result. Where condition sets out that we are interested in shelf A. Result is ordered by bin and shelf and bin is concatenated in out field as Reference and alternative.*/


SELECT  CONCAT(p1.Shelf ,' ' , p1.bin) AS [Reference location]
	, CONCAT(p2.Shelf,' ',P2.Bin)	AS [Alternative location]
	, p2.Quantity
	, p1.ProductID 
FROM Production.ProductInventory p1
JOIN Production.ProductInventory p2 ON p1.Shelf<>p2.Shelf AND p1.ProductID = p2.ProductID
WHERE p1.Shelf = 'A'
ORDER BY p1.bin;

/*18 Next request is to generate a list with all the shops from Canada that purchased for more than 25000.
To make this SELECT I have reused the previous select(turned the where clauses to joins), and extended it by sticking a select in front of it using the WITH key word. The SELCET in the WITH is grouping all the stores by the amount they have purchased from us. Using this list I filter out by StoreID using the logic from the previous join, all the stores that match country code CA. Further I have set the condition to purchasing total to be more than 25000 and ordered it descending. */


WITH purchase AS (
	SELECT c.StoreID
		, SUM (d.LineTotal) AS [Total purchase]  
	FROM Sales.SalesOrderDetail d
	JOIN Sales.SalesOrderHeader h ON d.SalesOrderID = h.SalesOrderID
	JOIN Sales.Customer c ON h.CustomerID = c.CustomerID
	JOIN Sales.store s ON s.BusinessEntityID = c.StoreID
	GROUP BY c.StoreID)
SELECT s.Name
	, purchase.[Total purchase]
	, a.AddressLine1, a.AddressLine2
	, a.City 
FROM purchase
JOIN Sales.Store s ON purchase.StoreID = S.BusinessEntityID
JOIN Person.BusinessEntityAddress b ON s.BusinessEntityID = b.BusinessEntityID 
JOIN Person.Address a ON b.AddressID = a.AddressID 
JOIN Person.StateProvince p ON a.StateProvinceID = p.StateProvinceID
WHERE [Total purchase] > 25000 AND p.CountryRegionCode = 'CA' 
ORDER BY [Total purchase] DESC;


/*19. The task for this query is to find out the margin of products and what product generates the most income.
In order to get the sale price of an item, I have made a select on salesOrderDetails, grouped by product and averaged the price as the items could change price or be on sale. Then I counted the number of items sold for each product. The third select averages the production cost of the items. The main select uses the above three results and pulls information from them with 2 joins, all on productID, and one join to pull the name of the product from production.product table. I have used CAST to cu down the decimals at display. On Margin per total I have rounded up the decimals and then used the CAST to bring it to 2 decimals. Result is ordered by Margin Per Total Descending. If we ordered it increasing (or we scroll down to the bottom), we could see on the top the products that generate loss, or make 0 profit. */


WITH averageSale AS (SELECT ProductID, AVG(LineTotal) AS [average sale] FROM Sales.SalesOrderDetail GROUP BY ProductID),
	howManySale AS (SELECT ProductID, SUM(OrderQty) AS [how many sold] FROM Sales.SalesOrderDetail GROUP BY ProductID),
	averageCost AS(SELECT ProductID, AVG(ActualCost) AS [average cost] FROM Production.TransactionHistory GROUP BY ProductID)
SELECT p.name AS [Product Name]
	, CAST([average Sale] AS decimal(8,2)) AS [Average Sale Price]
	, CAST(c.[average cost] AS decimal(8,2)) AS [Average Prodcution Cost]
	, CAST([average sale]-c.[average cost]AS decimal(8,2)) AS [Margin Per Item]
	, h.[how many sold] AS [Number Of Item Sold]
	, CAST(ROUND((([average sale]-c.[average cost]) * h.[how many sold]), 2) as decimal(9,2)) AS [Margin Per Total] 
FROM averageSale s
JOIN averageCost c ON s.ProductID=c.ProductID
JOIN Production.Product p ON p.ProductID=s.ProductID
JOIN howManySale h ON h.ProductID = s.ProductID
ORDER BY [Margin per Total] DESC;

/*20 Next query generates a list of employees with full address.
The list of employees are joined with person table on bussinessEntityId to retreive the name of employees, this is displayed in the name column, first and last name are concatenated with a space in between them. Address line 1 and 2 are pulled from person.Address however to get to this we have to join with bussinessEntityAddress. The next join retreives the state/province, with the stateprovinceID from address table. Further we need to join with countryRegion to retrieve the country, join is done with stateProvince table on contryRegionCode. Finally we order by City and last name.*/


 SELECT   p.FirstName + ' '+ p.LastName AS [Name]
		, a1.AddressLine1
		, a1.AddressLine2
		, a1.City
		, s.Name AS [State/Province]
		, c.Name AS [Country] 
 FROM HumanResources.Employee e
 JOIN Person.Person p ON e.BusinessEntityID = p.BusinessEntityID
 JOIN Person.BusinessEntityAddress a ON e.BusinessEntityID = a.BusinessEntityID
 JOIN Person.Address a1 ON a.AddressID = a1. AddressID
 JOIN Person.StateProvince s ON a1.StateProvinceID = s.StateProvinceID
 JOIN person.CountryRegion c ON s.CountryRegionCode = c.CountryRegionCode
 ORDER BY City, LastName;