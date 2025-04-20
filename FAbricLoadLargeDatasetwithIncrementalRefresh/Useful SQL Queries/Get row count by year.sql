SELECT 
    YEAR(dt) AS year,
    COUNT(*) AS row_count
FROM 
    <Your table name>
GROUP BY 
    YEAR(<Your Date Time column>)
ORDER BY 
    year;
