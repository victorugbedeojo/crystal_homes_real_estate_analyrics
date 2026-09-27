-- ============================================================
-- CRYSTAL HOMES AND REAL ESTATE MANAGEMENT
-- Full SQL script: table creation + all analytical views
-- Database: crystal_homes
-- Pipeline: Google Sheets (raw data) -> MySQL -> Power BI
-- ============================================================

-- ============================================================
-- 1. DATABASE + TABLE SETUP
-- ============================================================

CREATE DATABASE IF NOT EXISTS crystal_homes;
USE crystal_homes;

CREATE TABLE properties (
    property_id VARCHAR(10) PRIMARY KEY,
    city VARCHAR(50),
    area VARCHAR(50),
    property_type VARCHAR(50),
    bedrooms INT,
    size_sqm INT,
    listing_price INT,
    listing_type VARCHAR(20),   -- Sale / Rent
    status VARCHAR(20),         -- Available / Sold / Rented
    date_listed DATE
);

CREATE TABLE agents (
    agent_id VARCHAR(10) PRIMARY KEY,
    name VARCHAR(50),
    phone VARCHAR(15),
    branch VARCHAR(50),
    hire_date DATE
);

CREATE TABLE clients (
    client_id VARCHAR(10) PRIMARY KEY,
    name VARCHAR(50),
    phone VARCHAR(15),
    client_type VARCHAR(20),    -- Buyer / Tenant
    city VARCHAR(50)
);

CREATE TABLE sales (
    sale_id VARCHAR(10) PRIMARY KEY,
    property_id VARCHAR(10),
    agent_id VARCHAR(10),
    client_id VARCHAR(10),
    sale_price INT,
    sale_date DATE,
    FOREIGN KEY (property_id) REFERENCES properties(property_id),
    FOREIGN KEY (agent_id) REFERENCES agents(agent_id),
    FOREIGN KEY (client_id) REFERENCES clients(client_id)
);

CREATE TABLE leases (
    lease_id VARCHAR(10) PRIMARY KEY,
    property_id VARCHAR(10),
    agent_id VARCHAR(10),
    client_id VARCHAR(10),
    monthly_rent INT,
    lease_start DATE,
    lease_end DATE,
    status VARCHAR(20),         -- Active / Ended
    FOREIGN KEY (property_id) REFERENCES properties(property_id),
    FOREIGN KEY (agent_id) REFERENCES agents(agent_id),
    FOREIGN KEY (client_id) REFERENCES clients(client_id)
);

-- Data imported via Table Data Import Wizard, in this order:
-- properties -> agents -> clients -> sales -> leases


-- ============================================================
-- 2. SALES ANALYTICS (Q1 - Q6)
-- ============================================================

-- Q1: Revenue by city and area
CREATE VIEW vw_q1_revenue_by_city_area AS
SELECT
    p.city,
    p.area,
    SUM(s.sale_price) AS total_revenue
FROM sales s
JOIN properties p ON s.property_id = p.property_id
GROUP BY p.city, p.area
ORDER BY total_revenue DESC;

-- Q2: Revenue by property type
CREATE VIEW vw_q2_revenue_by_property_type AS
SELECT
    p.property_type,
    SUM(s.sale_price) AS total_revenue
FROM sales s
JOIN properties p ON s.property_id = p.property_id
GROUP BY p.property_type
ORDER BY total_revenue DESC;

-- Q3: Average sale price by area (which areas command a premium)
CREATE VIEW vw_q3_avg_sale_price AS
SELECT
    p.area,
    AVG(s.sale_price) AS avg_sale_price
FROM sales s
JOIN properties p ON s.property_id = p.property_id
GROUP BY p.area
ORDER BY avg_sale_price DESC;

-- Q4: Sale price vs listing price (discount / markup)
CREATE VIEW vw_q4_price_comparison AS
SELECT
    p.property_id,
    p.listing_price,
    s.sale_price,
    (s.sale_price - p.listing_price) AS price_diff
FROM sales s
JOIN properties p ON s.property_id = p.property_id;

-- Q5: Monthly sales trend
CREATE VIEW vw_q5_monthly_sales_trend AS
SELECT
    DATE_FORMAT(sale_date, '%Y-%m') AS sale_month,
    COUNT(sale_id) AS num_sales,
    SUM(sale_price) AS monthly_revenue
FROM sales
GROUP BY sale_month
ORDER BY sale_month;

-- Q6: Agent sales performance (most sales closed + highest revenue)
CREATE VIEW vw_q6_agent_sales_performance AS
SELECT
    a.agent_id,
    a.name AS agent_name,
    a.branch,
    COUNT(s.sale_id) AS num_sales,
    SUM(s.sale_price) AS total_revenue
FROM sales s
JOIN agents a ON s.agent_id = a.agent_id
GROUP BY a.agent_id, a.name, a.branch
ORDER BY total_revenue DESC;


-- ============================================================
-- 3. RENTAL ANALYTICS (Q7 - Q12)
-- ============================================================

-- Q7: Total active monthly rent income
CREATE VIEW vw_q7_active_rent_income AS
SELECT
    SUM(monthly_rent) AS total_monthly_rent
FROM leases
WHERE status = 'Active';

-- Q8: Active vs ended lease breakdown
CREATE VIEW vw_q8_lease_status_breakdown AS
SELECT
    status,
    COUNT(lease_id) AS num_leases
FROM leases
GROUP BY status;

-- Q9: Leases expiring soon (within next 90 days)
CREATE VIEW vw_q9_leases_expiring_soon AS
SELECT
    lease_id,
    property_id,
    lease_end,
    DATEDIFF(lease_end, CURDATE()) AS days_until_expiry
FROM leases
WHERE status = 'Active'
  AND DATEDIFF(lease_end, CURDATE()) BETWEEN 0 AND 90;

-- Q10: Average rent by property type AND area combined (detailed view)
CREATE VIEW vw_q10_avg_rent_by_type_area AS
SELECT
    p.property_type,
    p.area,
    AVG(l.monthly_rent) AS avg_rent_by_property
FROM leases l
JOIN properties p ON l.property_id = p.property_id
GROUP BY p.property_type, p.area
ORDER BY avg_rent_by_property DESC;

-- Q10a: Average rent by property type only
CREATE VIEW vw_q10a_avg_rent_by_type AS
SELECT
    p.property_type,
    AVG(l.monthly_rent) AS avg_rent_by_type
FROM leases l
JOIN properties p ON l.property_id = p.property_id
GROUP BY p.property_type
ORDER BY avg_rent_by_type DESC;

-- Q10b: Average rent by area only
CREATE VIEW vw_q10b_avg_rent_by_area AS
SELECT
    p.area,
    AVG(l.monthly_rent) AS avg_rent_by_area
FROM leases l
JOIN properties p ON l.property_id = p.property_id
GROUP BY p.area
ORDER BY avg_rent_by_area DESC;

-- Q11: Which agent manages the most active leases
CREATE VIEW vw_q11_agent_active_leases AS
SELECT
    a.agent_id,
    a.name,
    a.phone,
    COUNT(l.agent_id) AS agent_active_leases
FROM agents a
JOIN leases l ON a.agent_id = l.agent_id
WHERE l.status = 'Active'
GROUP BY a.agent_id, a.name, a.phone
ORDER BY agent_active_leases DESC;

-- Q12: Average lease duration (months), and whether it varies by area
CREATE VIEW vw_q12_avg_lease_duration AS
SELECT
    p.area,
    AVG(TIMESTAMPDIFF(MONTH, l.lease_start, l.lease_end)) AS avg_duration_months
FROM leases l
JOIN properties p ON l.property_id = p.property_id
GROUP BY p.area
ORDER BY avg_duration_months DESC;


-- ============================================================
-- 4. PROPERTY PORTFOLIO ANALYTICS (Q13 - Q17)
-- ============================================================

-- Q13: New listings growth month over month
CREATE VIEW vw_q13_monthly_listings_trend AS
SELECT
    DATE_FORMAT(date_listed, '%Y-%m') AS listing_month,
    COUNT(property_id) AS num_new_listings
FROM properties
GROUP BY listing_month
ORDER BY listing_month;

-- Q14: Property status breakdown (Available / Sold / Rented)
CREATE VIEW vw_q14_property_status_breakdown AS
SELECT
    status,
    COUNT(property_id) AS num_properties
FROM properties
GROUP BY status;

-- Q15: Sale vs rent listing split by city
CREATE VIEW vw_q15_listing_type_by_city AS
SELECT
    city,
    listing_type,
    COUNT(property_id) AS num_listings
FROM properties
GROUP BY city, listing_type
ORDER BY city, listing_type;

-- Q16: Area with highest concentration of listings
CREATE VIEW vw_q16_listings_by_area AS
SELECT
    area,
    COUNT(property_id) AS num_listings
FROM properties
GROUP BY area
ORDER BY num_listings DESC;

-- Q17: Average property size by property type
CREATE VIEW vw_q17_avg_size_by_type AS
SELECT
    property_type,
    AVG(size_sqm) AS avg_size_sqm
FROM properties
GROUP BY property_type
ORDER BY avg_size_sqm DESC;


-- ============================================================
-- 5. AGENT & BRANCH PERFORMANCE (Q18 - Q19)
-- ============================================================

-- Q18: Agent combined revenue (sales revenue + active rent managed)
CREATE VIEW vw_q18_agent_combined_performance AS
SELECT
    a.agent_id,
    a.name AS agent_name,
    a.branch,
    COALESCE(s.total_sales_revenue, 0) AS total_sales_revenue,
    COALESCE(l.total_rent_managed, 0) AS total_rent_managed,
    COALESCE(s.total_sales_revenue, 0) + COALESCE(l.total_rent_managed, 0) AS combined_revenue
FROM agents a
LEFT JOIN (
    SELECT agent_id, SUM(sale_price) AS total_sales_revenue
    FROM sales
    GROUP BY agent_id
) s ON a.agent_id = s.agent_id
LEFT JOIN (
    SELECT agent_id, SUM(monthly_rent) AS total_rent_managed
    FROM leases
    WHERE status = 'Active'
    GROUP BY agent_id
) l ON a.agent_id = l.agent_id
ORDER BY combined_revenue DESC;

-- Q19: Branch performance (sales revenue by agent's home branch)
-- NOTE: revenue here is attributed to the agent's branch, not the
-- property's city. A sale on a property in one city can be closed
-- by an agent based in another branch (see Ibadan vs Lagos finding
-- in the project write-up).
CREATE VIEW vw_q19_branch_performance AS
SELECT
    a.branch,
    COUNT(DISTINCT s.sale_id) AS num_sales,
    COALESCE(SUM(s.sale_price), 0) AS total_sales_revenue
FROM agents a
LEFT JOIN sales s ON a.agent_id = s.agent_id
GROUP BY a.branch
ORDER BY total_sales_revenue DESC;


-- ============================================================
-- 6. CLIENT ANALYTICS (Q20)
-- ============================================================

-- Q20: Client split - buyer/tenant by city (view, feeds dashboard chart)
CREATE VIEW vw_q20_client_split AS
SELECT
    client_type,
    city,
    COUNT(client_id) AS num_clients
FROM clients
GROUP BY client_type, city
ORDER BY client_type, city;


-- ============================================================
-- END OF SCRIPT
-- 21 views total (Q1-Q19, with Q10 split into overall + type-only +
-- area-only) plus Q20 as its own view for dashboard use.
-- ============================================================
