-- ========================================
-- 1. Create and Use Database
-- ========================================
CREATE DATABASE food_order;
USE food_order;

-- ========================================
-- 2. Check for NULL Values in Dataset
-- ========================================
SELECT 
    SUM(CASE WHEN Order_ID IS NULL THEN 1 ELSE 0 END) AS Null_Order_ID,
    SUM(CASE WHEN Order_Value IS NULL THEN 1 ELSE 0 END) AS Null_Order_Value,
    SUM(CASE WHEN Commission_Fee IS NULL THEN 1 ELSE 0 END) AS Null_Commission_Fee,
    SUM(CASE WHEN Delivery_Fee IS NULL THEN 1 ELSE 0 END) AS Null_Delivery_Fee,
    SUM(CASE WHEN Payment_Processing_Fee IS NULL THEN 1 ELSE 0 END) AS Null_Payment_Processing_Fee,
    SUM(CASE WHEN Order_Date_and_Time IS NULL THEN 1 ELSE 0 END) AS Null_Order_Date_and_Time,
    SUM(CASE WHEN Discounts_and_Offers IS NULL THEN 1 ELSE 0 END) AS Null_Discounts_and_Offers,
    SUM(CASE WHEN Payment_Method IS NULL THEN 1 ELSE 0 END) AS Null_Payment_Method
FROM food;

-- ========================================
-- 3. Basic Aggregations
-- ========================================

-- Total Profit by Day
SELECT 
    DAY(Order_Date_and_Time) AS Order_Day,
    SUM(Profit) AS Total_Profit
FROM food
GROUP BY DAY(Order_Date_and_Time);

-- Count of Payment Methods
SELECT 
    Payment_Method,
    COUNT(Payment_Method) AS Payment_Count
FROM food
GROUP BY Payment_Method;

-- ========================================
-- 4. Add Discount Fields
-- ========================================
ALTER TABLE food
ADD 
    Discount_Value FLOAT,
    Discount_Type VARCHAR(20),
    Discount_Amount FLOAT;

-- ========================================
-- 5. Extract Discount Value and Type
-- ========================================
UPDATE food
SET 
    Discount_Value = CASE
        WHEN [Discounts_and_Offers] LIKE '%\%%' ESCAPE '\' THEN 
            CAST(LEFT([Discounts_and_Offers], CHARINDEX('%', [Discounts_and_Offers]) - 1) AS FLOAT)
        WHEN [Discounts_and_Offers] LIKE '%off%' THEN 
            CAST(LEFT([Discounts_and_Offers], CHARINDEX(' ', [Discounts_and_Offers]) - 1) AS FLOAT)
        ELSE 0.0
    END,
    Discount_Type = CASE
        WHEN [Discounts_and_Offers] LIKE '%\%%' ESCAPE '\' THEN 'percentage'
        WHEN [Discounts_and_Offers] LIKE '%off%' THEN 'fixed'
        ELSE 'none'
    END;

-- ========================================
-- 6. Calculate Discount Amount
-- ========================================
UPDATE food
SET Discount_Amount = CASE
    WHEN Discount_Type = 'percentage' THEN ([Order_Value] * Discount_Value / 100)
    WHEN Discount_Type = 'fixed' THEN Discount_Value
    ELSE 0.0
END;

-- ========================================
-- 7. Add and Calculate Financial Metrics
-- ========================================
ALTER TABLE food
ADD 
    Total_Costs FLOAT,
    Revenue FLOAT,
    Profit FLOAT;

-- Update Total Costs
UPDATE food
SET Total_Costs = ISNULL([Delivery_Fee], 0) 
                + ISNULL([Payment_Processing_Fee], 0) 
                + ISNULL([Discount_Amount], 0);

-- Update Revenue
UPDATE food
SET Revenue = ISNULL([Commission_Fee], 0);

-- Update Profit
UPDATE food
SET Profit = ROUND(Revenue - Total_Costs, 2);

-- Check Profit Sum
SELECT SUM(Profit) AS Total_Profit FROM food;

-- ========================================
-- 8. Add and Calculate Percentage Metrics
-- ========================================
ALTER TABLE food
ADD 
    Commission_Percentage FLOAT,
    Effective_Discount_Percentage FLOAT;

UPDATE food
SET 
    Commission_Percentage = CASE 
        WHEN [Order_Value] IS NOT NULL AND [Order_Value] <> 0 THEN 
            ROUND(([Commission_Fee] * 100.0) / [Order_Value], 2)
        ELSE NULL
    END,
    Effective_Discount_Percentage = CASE 
        WHEN [Order_Value] IS NOT NULL AND [Order_Value] <> 0 THEN 
            ROUND(([Discount_Amount] * 100.0) / [Order_Value], 2)
        ELSE NULL
    END;

-- ========================================
-- 9. Analyze Profitability Based on Metrics
-- ========================================

-- Profitable Orders
SELECT 
    AVG(Commission_Percentage) AS Avg_Commission_Profitable,
    AVG(Effective_Discount_Percentage) AS Avg_Discount_Profitable
FROM food
WHERE Profit > 1;

-- Note:
-- New Average Commission Percentage: 27.75%
-- New Average Discount Percentage: 5.58%

/*
Based on this analysis, a strategy that aims for a commission rate closer to 27% 
and a discount rate around 6% could potentially improve profitability across the board.
*/

-- Unprofitable Orders
SELECT 
    AVG(Commission_Percentage) AS Avg_Commission_Unprofitable,
    AVG(Effective_Discount_Percentage) AS Avg_Discount_Unprofitable
FROM food
WHERE Profit < 0;

-- Note:
-- New Average Commission Percentage: 10.51%
-- New Average Discount Percentage: 10.04%

-- ========================================
-- 10. Create Simulation Table with Strategy
-- ========================================
CREATE TABLE food_orders_simulation (
    OrderID INT PRIMARY KEY,
    OrderValue FLOAT,
    Simulated_Commission_Fee FLOAT,
    Simulated_Discount_Amount FLOAT,
    Simulated_Total_Costs FLOAT,
    Simulated_Profit FLOAT
);

-- Set Recommended Strategy Parameters
DECLARE @RecommendedCommissionPercentage FLOAT = 27.0;
DECLARE @RecommendedDiscountPercentage FLOAT = 6.0;

-- Insert Simulated Data
INSERT INTO food_orders_simulation (
    OrderID, 
    OrderValue, 
    Simulated_Commission_Fee, 
    Simulated_Discount_Amount, 
    Simulated_Total_Costs, 
    Simulated_Profit
)
SELECT 
    Order_ID,
    [Order_Value],
    [Order_Value] * (@RecommendedCommissionPercentage / 100.0),
    [Order_Value] * (@RecommendedDiscountPercentage / 100.0),
    ISNULL([Delivery_Fee], 0) 
    + ISNULL([Payment_Processing_Fee], 0) 
    + ([Order_Value] * (@RecommendedDiscountPercentage / 100.0)),
    ([Order_Value] * (@RecommendedCommissionPercentage / 100.0)) 
    - (ISNULL([Delivery_Fee], 0) 
    + ISNULL([Payment_Processing_Fee], 0) 
    + ([Order_Value] * (@RecommendedDiscountPercentage / 100.0)))
FROM food;

-- View Simulated Table
SELECT * FROM food_orders_simulation;

-- ========================================
-- 11. Compare Actual vs Simulated Results
-- ========================================
SELECT 
    f.Order_ID,
    f.[Order_Value] AS Actual_Order_Value,
    f.[Commission_Fee] AS Actual_Commission_Fee,
    s.Simulated_Commission_Fee,
    f.[Discount_Amount] AS Actual_Discount_Amount,
    s.Simulated_Discount_Amount,
    f.Total_Costs AS Total_Cost,
    s.Simulated_Total_Costs,
    f.Profit AS Actual_Profit,
    s.Simulated_Profit
FROM food f
JOIN food_orders_simulation s
    ON f.Order_ID = s.OrderID;
