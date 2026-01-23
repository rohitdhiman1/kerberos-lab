#!/usr/bin/env python3
"""
PostgreSQL Kerberos Authentication Example
Demonstrates connecting to PostgreSQL using Kerberos tickets
"""

import psycopg2
import sys

def connect_with_kerberos():
    """Connect to PostgreSQL using Kerberos authentication"""
    try:
        # Connection parameters
        # Note: No password needed - uses Kerberos ticket!
        conn = psycopg2.connect(
            host="postgres.example.com",
            port=5432,
            database="testdb",
            user="dbuser",
            gssencmode="prefer"  # Use GSSAPI encryption if available
        )
        
        print("✓ Successfully connected to PostgreSQL using Kerberos!")
        print()
        
        # Create cursor
        cursor = conn.cursor()
        
        # Test query - Get employees
        print("=== Employees ===")
        cursor.execute("SELECT id, name, department FROM demo.employees ORDER BY id;")
        for row in cursor.fetchall():
            print(f"  {row[0]}: {row[1]} ({row[2]})")
        
        print()
        
        # Test query - Get departments with budget
        print("=== Departments ===")
        cursor.execute("SELECT name, location, budget FROM demo.departments ORDER BY name;")
        for row in cursor.fetchall():
            print(f"  {row[0]}: {row[1]} - Budget: ${row[2]:,.2f}")
        
        print()
        
        # Test query - Active projects
        print("=== Active Projects ===")
        cursor.execute("SELECT name, status, start_date FROM demo.projects WHERE status = 'active' ORDER BY start_date;")
        for row in cursor.fetchall():
            print(f"  {row[0]}: {row[1]} (Started: {row[2]})")
        
        print()
        
        # Get connection info
        cursor.execute("SELECT current_user, current_database(), inet_server_addr(), inet_server_port();")
        user, db, host, port = cursor.fetchone()
        print(f"Connection Info:")
        print(f"  User: {user}")
        print(f"  Database: {db}")
        print(f"  Server: {host}:{port}")
        print()
        
        # Check if connection is using GSS encryption
        cursor.execute("SELECT ssl_is_used();")
        ssl_used = cursor.fetchone()[0]
        print(f"  SSL/TLS: {'Yes' if ssl_used else 'No (using GSSAPI encryption)'}")
        
        # Clean up
        cursor.close()
        conn.close()
        
        print()
        print("✓ Connection closed successfully")
        return True
        
    except psycopg2.Error as e:
        print(f"✗ Database error: {e}", file=sys.stderr)
        return False
    except Exception as e:
        print(f"✗ Error: {e}", file=sys.stderr)
        return False

def main():
    print("=" * 60)
    print("PostgreSQL Kerberos Authentication Example")
    print("=" * 60)
    print()
    
    # Check if we can connect
    success = connect_with_kerberos()
    
    sys.exit(0 if success else 1)

if __name__ == "__main__":
    main()
