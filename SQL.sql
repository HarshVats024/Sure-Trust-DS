LOAD DATA INFILE "C:\Users\ayush\Documents\Major project\Capstone project 2\crop yield data sheet.csv"
INTO TABLE crop_yield_data_sheet
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS;



-- 1. Write a query to get average yield per crop type. 
-- Command:-
SELECT Crop_Type, AVG(Yield) AS avg_yield
FROM crop_yield_data_sheet
GROUP BY Crop_Type;

-- 2. Find farmers with yield > 90th percentile across all years
-- Command :-
WITH sorted AS (
    SELECT Yield
    FROM crop_yield_data_sheet
    ORDER BY Yield
),
p90_value AS (
    SELECT Yield AS p90
    FROM sorted
    LIMIT 1 OFFSET (
        SELECT CAST(0.9 * COUNT(*) AS INT)
        FROM sorted
    )
)
SELECT *
FROM crop_yield_data_sheet
WHERE Yield > (SELECT p90 FROM p90_value);

-- 3. Group data by region and season to find average rainfall.  
-- Command:-
SELECT Region, Season, AVG(Annual_Rainfall) AS avg_rainfall
FROM crop_yield_data_sheet
GROUP BY Region, Season;

-- 4. Join with a soil fertility table to enrich soil type info.  
-- Command:- 
SELECT c.*,s.Fertility_Level,s.Description
FROM crop_yield_data_sheet c
LEFT JOIN soil_fertility s
     ON c.Soil_Type = s.Soil_Type;
-- 5. Create a view for top-performing crops by yield and fertilizer efficiency. 
-- Command:-
CREATE VIEW top_crop_performance AS
SELECT 
    Crop_Type,
    AVG(Yield) AS avg_yield,
    AVG(Yield / NULLIF(Fertilizer_Used,0)) AS fertilizer_efficiency
FROM crop_yield_data_sheet
GROUP BY Crop_Type
ORDER BY avg_yield DESC, fertilizer_efficiency DESC;

-- 6. Use CASE to classify rainfall levels (Low, Medium, High).  
-- Command:-
SELECT *,
    CASE 
        WHEN Rainfall < 300 THEN 'Low'
        WHEN Rainfall BETWEEN 300 AND 700 THEN 'Medium'
        ELSE 'High'
    END AS Rainfall_Level
FROM crop_yield_data_sheet;

-- 7. Extract year-over-year yield growth for wheat. 
-- Command:-
WITH w AS (
    SELECT 
        Year,
        AVG(Yield) AS avg_yield
    FROM crop_yield_data_sheet
    WHERE Crop_Type = 'Wheat'
    GROUP BY Year
)
SELECT 
    Year,
    avg_yield,
    LAG(avg_yield) OVER (ORDER BY Year) AS prev_year_yield,
    ROUND(
        (avg_yield - LAG(avg_yield) OVER (ORDER BY Year)) 
        / NULLIF(LAG(avg_yield) OVER (ORDER BY Year), 0) * 100, 2
    ) AS yoy_growth_percent
FROM w;

-- 8. Find regions with declining yield despite increased fertilizer.  
-- Command:-
WITH region_stats AS (
    SELECT 
        Region,
        Year,
        AVG(Yield) AS avg_yield,
        AVG(Fertilizer_Used) AS avg_fertilizer
    FROM crop_yield_data_sheet
    GROUP BY Region, Year
),
comp AS (
    SELECT 
        Region,
        Year,
        avg_yield,
        avg_fertilizer,
        LAG(avg_yield) OVER (PARTITION BY Region ORDER BY Year) AS prev_yield,
        LAG(avg_fertilizer) OVER (PARTITION BY Region ORDER BY Year) AS prev_fertilizer
    FROM region_stats
)
SELECT 
    Region, Year, avg_yield, avg_fertilizer
FROM comp
WHERE avg_yield < prev_yield       -- yield declining
  AND avg_fertilizer > prev_fertilizer;   -- fertilizer increasing


-- 9. Rank crops by pesticide efficiency (yield per kg pesticide).  
-- Command:-
SELECT
    Crop_Type,
    AVG(Yield / NULLIF(Pesticide_Used,0)) AS pesticide_efficiency,
    RANK() OVER (ORDER BY 
        AVG(Yield / NULLIF(Pesticide_Used,0)) DESC
    ) AS efficiency_rank
FROM crop_yield_data_sheet
GROUP BY Crop_Type;

-- 10. Create a stored procedure to return yield summary for any crop and year. 
-- Command:-
DELIMITER //

CREATE PROCEDURE GetYieldSummary(IN crop_name VARCHAR(50), IN yr INT)
BEGIN
    SELECT *
    FROM crop_yield_data
    WHERE Crop_Type = crop_name
      AND Year = yr;
END //

DELIMITER ;

