#!/usr/bin/env python3
"""
PostgreSQL Insert/Update Example with Kerberos
Demonstrates data manipulation using Kerberos authentication
"""

import psycopg2
import sys
from datetime import datetime

def perform_operations():
    """Perform various database operations"""
    try:
        # Connect
        conn = psycopg2.connect(
            host="postgres.example.com",
            port=5432,
            database="testdb",
            user="dbuser",
            gssencmode="prefer"
        )
        
        print("✓ Connected to PostgreSQL")
        print()
        
        cursor = conn.cursor()
        
        # Insert a new employee
        print("=== Inserting New Employee ===")
        cursor.execute("""
            INSERT INTO demo.employees (name, email, department)
            VALUES (%s, %s, %s)
            RETURNING id, name;
        """, ("Frank Miller", "frank@example.com", "Engineering"))
        
        new_id, new_name = cursor.fetchone()
        print(f"  ✓ Inserted: {new_name} (ID: {new_id})")
        conn.commit()
        
        print()
        
        # Update employee
        print("=== Updating Employee ===")
        cursor.execute("""
            UPDATE demo.employees
            SET department = %s
            WHERE name = %s
            RETURNING id, name, department;
        """, ("Sales", "Frank Miller"))
        
        emp_id, emp_name, emp_dept = cursor.fetchone()
        print(f"  ✓ Updated: {emp_name} -> Department: {emp_dept}")
        conn.commit()
        
        print()
        
        # Insert a new project
        print("=== Inserting New Project ===")
        cursor.execute("""
            INSERT INTO demo.projects (name, description, start_date, status)
            VALUES (%s, %s, %s, %s)
            RETURNING id, name, status;
        """, ("Cloud Migration", "Move infrastructure to cloud", "2026-04-01", "planning"))
        
        proj_id, proj_name, proj_status = cursor.fetchone()
        print(f"  ✓ Inserted: {proj_name} (Status: {proj_status})")
        conn.commit()
        
        print()
        
        # Show all employees
        print("=== All Employees ===")
        cursor.execute("SELECT id, name, department FROM demo.employees ORDER BY id;")
        for row in cursor.fetchall():
            print(f"  {row[0]:2d}. {row[1]:20s} - {row[2]}")
        
        print()
        
        # Transaction example
        print("=== Transaction Example ===")
        try:
            cursor.execute("""
                INSERT INTO demo.departments (name, location, budget)
                VALUES (%s, %s, %s);
            """, ("Research", "Building D", 400000.00))
            
            cursor.execute("""
                UPDATE demo.employees
                SET department = %s
                WHERE name = %s;
            """, ("Research", "Alice Johnson"))
            
            conn.commit()
            print("  ✓ Transaction committed successfully")
        except Exception as e:
            conn.rollback()
            print(f"  ✗ Transaction rolled back: {e}")
        
        print()
        
        # Clean up
        cursor.close()
        conn.close()
        
        print("✓ All operations completed successfully")
        return True
        
    except psycopg2.Error as e:
        print(f"✗ Database error: {e}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"✗ Error: {e}", file=sys.stderr)
        return False

def main():
    print("=" * 60)
    print("PostgreSQL Data Operations with Kerberos")
    print("=" * 60)
    print()
    
    success = perform_operations()
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
