-- Initialize test database

-- Create database
CREATE DATABASE testdb;

-- Connect to testdb
\c testdb;

-- Create schema
CREATE SCHEMA IF NOT EXISTS demo;

-- Create sample tables
CREATE TABLE demo.employees (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    department VARCHAR(50),
    hire_date DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE demo.departments (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    location VARCHAR(100),
    budget DECIMAL(12, 2)
);

CREATE TABLE demo.projects (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    start_date DATE,
    end_date DATE,
    status VARCHAR(20) DEFAULT 'active'
);

-- Insert sample data
INSERT INTO demo.departments (name, location, budget) VALUES
    ('Engineering', 'Building A', 500000.00),
    ('Marketing', 'Building B', 250000.00),
    ('Sales', 'Building C', 300000.00),
    ('HR', 'Building A', 150000.00);

INSERT INTO demo.employees (name, email, department) VALUES
    ('Alice Johnson', 'alice@example.com', 'Engineering'),
    ('Bob Smith', 'bob@example.com', 'Engineering'),
    ('Carol Williams', 'carol@example.com', 'Marketing'),
    ('David Brown', 'david@example.com', 'Sales'),
    ('Eve Davis', 'eve@example.com', 'HR');

INSERT INTO demo.projects (name, description, start_date, status) VALUES
    ('Product Launch', 'New product release', '2026-01-01', 'active'),
    ('Website Redesign', 'Corporate website update', '2026-02-01', 'active'),
    ('Security Audit', 'Annual security review', '2026-03-01', 'planning');

-- Create views
CREATE VIEW demo.employee_summary AS
SELECT 
    e.name,
    e.department,
    e.hire_date,
    d.location
FROM demo.employees e
LEFT JOIN demo.departments d ON e.department = d.name;

-- Grant permissions (will be adjusted after Kerberos user creation)
GRANT USAGE ON SCHEMA demo TO PUBLIC;
GRANT SELECT ON ALL TABLES IN SCHEMA demo TO PUBLIC;

-- Create index
CREATE INDEX idx_employees_department ON demo.employees(department);
CREATE INDEX idx_projects_status ON demo.projects(status);

-- Display summary
SELECT 'Database initialized successfully' AS status;
SELECT COUNT(*) AS employee_count FROM demo.employees;
SELECT COUNT(*) AS department_count FROM demo.departments;
SELECT COUNT(*) AS project_count FROM demo.projects;
