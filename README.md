# SQL
Tables analisys using PostgreSQL

![](https://img.shields.io/badge/PostgreSQL-316192?style=for-the-badge&logo=postgresql&logoColor=white)
![](https://img.shields.io/badge/dbeaver-382923?style=for-the-badge&logo=dbeaver&logoColor=white)

## Description
In this project I used 4 tables to analize Facebook and Google ads campaigns. My first assignment was to use CTE to select certain fields. 
Then I truncated month from ad_date column as it supposed to be new column in the result table (and part of window function). 
I used function to decode cirillic letters to replace some utm_campaigns that were named in cirillic letters.
Next step was to calculate metrics (CTR, CPM, ROMI) using CASE method to avoid division by 0 error.
To find the same metrics, only for previous month, I used window function. And in the final select statement I had to find the difference between metrics for given and previous month.
In the process I learned how to work with strings, effectively use functions for manipulation with strings, search for matches and union(join) of table parts. Also I used methods to handle null values and window function.
