# Database connection pool manager
import sqlite3
def get_connection():
    return sqlite3.connect("app.db")
