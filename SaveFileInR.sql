exec sp_execute_external_script
	@language = N'R'
	, @script = N'write.csv(InputDataSet, "C:\\temp\\test.csv", row.names = FALSE);'
	, @input_data_1 = N'SELECT ProductId, Name FROM Production.Product'
