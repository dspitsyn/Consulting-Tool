/*
	| If I need to subtract the length of the search string, and then subtract the number of positions in that the first search hit was.
	| After all, there are still leading and trailing spaces on each line.
	| If you want to get rid of those, you can either adjust your LEN functions, or you can call TRIM, LTRIM/RTRIM on the final result

*/
SELECT *,
       SUBSTRING(
                 m.text, /*First argument*/
                 CHARINDEX(':', m.text) + LEN(':'), /*Second argument*/
                 CHARINDEX(':', m.text, CHARINDEX(':', m.text) + LEN(':'))
                 - LEN(':') - CHARINDEX(':', m.text) /*Third argument*/
                 ) AS parsed_string
FROM sys.messages AS m
WHERE m.language_id = 1031
AND   m.text LIKE N'%:%:%';
