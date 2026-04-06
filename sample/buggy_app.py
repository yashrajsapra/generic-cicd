"""
Sample app for testing the CI/CD code review pipeline.
Contains deliberate issues for the automated reviewer to catch.
"""
import sqlite3
import os


# ISSUE 1: Hardcoded credentials
DB_PASSWORD = "supersecret123"
API_KEY = "sk-prod-abc123xyz789hardcoded"


def get_user(username):
    """Fetch a user from the database."""
    # ISSUE 2: SQL injection — string concatenation instead of parameterised query
    conn = sqlite3.connect("users.db")
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE username = '" + username + "'")
    return cursor.fetchone()
    # ISSUE 3: conn never closed — resource leak


def calculate_discount(price, discount_pct):
    """Return the discounted price."""
    # ISSUE 4: Logic error — returns the discount amount, not the discounted price
    return price * (discount_pct / 100)


def load_config(path):
    """Load config file contents."""
    # ISSUE 5: No FileNotFoundError handling
    with open(path) as f:
        return f.read()


def divide(a, b):
    """Divide a by b."""
    # ISSUE 6: No zero-division guard
    return a / b


def process_items(items):
    """Remove negative items from list."""
    # ISSUE 7: Mutating list while iterating — skips elements
    for item in items:
        if item < 0:
            items.remove(item)
    return items


if __name__ == "__main__":
    print(f"DB password: {DB_PASSWORD}")
    print(f"Discount on $100 at 20%: {calculate_discount(100, 20)}")  # prints 20.0, not 80.0
    print(f"10 / 0 = {divide(10, 0)}")  # crashes
