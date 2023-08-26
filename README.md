
# PostgreSQL Utils

A collection of PostgreSQL utilities designed to simplify and enhance various database operations.

## Utilities Included

### CRUD Functions Generator

Automatically generates CRUD (Create, Read, Update, Delete) functions for a specified table in PostgreSQL.

#### Features:

- Generates basic CRUD functions based on table structure.
- Handles columns with default values, including auto-generated UUIDs.
- Sets `created_at` and `updated_at` timestamps automatically.
- Excludes `created_at` and `updated_at` from function parameters for internal management.

#### Usage:

1. Create your table in PostgreSQL.
2. Execute the `generate_crud_functions` script.
3. Call the function with your table's name:

```sql
SELECT generate_crud_functions('your_table_name');
```

### [Other Utilities]

(None available yet)

## Prerequisites

- PostgreSQL 9.5 or later.
- `uuid-ossp` extension for PostgreSQL (for UUID-related operations).

## Contributing

Contributions are welcome! Please fork this repository and open a pull request with your changes, or open an issue to discuss a potential change.

## License

This project is open source and available under the [MIT License](LICENSE).
