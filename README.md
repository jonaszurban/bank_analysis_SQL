# bank_analysis_SQL
The goal of the project is to analyze data from some Czech bank (the data has been anonymised). I analyzed data such as the sum of loans in a period, the number of loans by gender or the number of loans by region.

The data comes from the "financial" database, which can be downloaded here: https://relational.fit.cvut.cz/dataset/Financial.

Database contains 8 tables: card, disp, trans, order, loan, account, client, district. 

The card table contains information about customer's credit card, the disp table contains information which customer can use the card, the loan table contains information about customer's loans. In the table district there are information about places where bank's customers are from. The client table is all about general data of customer such as gender or birthdate. The central table is account which contains information about customer's account. There are also two additional tables - trans and order, but these two tables are not used in this project.

The repository also includes a simple diagram of the base on which the project is made. File with schema of database is called 'financial_schema.jpg'.
