SELECT 
    YEAR(dt) AS year,
    COUNT(*) AS row_count
FROM 
    KDFW
GROUP BY 
    YEAR(dt)
ORDER BY 
    year;
