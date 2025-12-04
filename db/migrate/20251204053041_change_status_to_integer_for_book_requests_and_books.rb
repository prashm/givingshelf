class ChangeStatusToIntegerForBookRequestsAndBooks < ActiveRecord::Migration[8.0]
  def up
    # Drop default values first (they're strings and can't be cast to integer)
    change_column_default :book_requests, :status, nil
    change_column_default :books, :status, nil

    # Change book_requests status from string to integer using USING clause
    # Map: "pending" -> 0, "accepted" -> 1, "declined" -> 2, "completed" -> 4
    execute <<-SQL
      ALTER TABLE book_requests
      ALTER COLUMN status TYPE integer
      USING CASE
        WHEN status = 'pending' THEN 0
        WHEN status = 'accepted' THEN 1
        WHEN status = 'declined' THEN 2
        WHEN status = 'completed' THEN 4
        ELSE 0
      END
    SQL

    # Set default and not null constraint
    change_column_default :book_requests, :status, 0
    change_column_null :book_requests, :status, false

    # Change books status from string to integer using USING clause
    # Map: "available" -> 0, "requested" -> 1, "donated" -> 2
    execute <<-SQL
      ALTER TABLE books
      ALTER COLUMN status TYPE integer
      USING CASE
        WHEN status = 'available' THEN 0
        WHEN status = 'requested' THEN 1
        WHEN status = 'donated' THEN 2
        ELSE 0
      END
    SQL

    # Set default and not null constraint
    change_column_default :books, :status, 0
    change_column_null :books, :status, false

    # Add indexes on status columns
    add_index :book_requests, :status
    add_index :books, :status
  end

  def down
    # Remove indexes
    remove_index :book_requests, :status
    remove_index :books, :status

    # Change book_requests status from integer to string using USING clause
    execute <<-SQL
      ALTER TABLE book_requests
      ALTER COLUMN status TYPE varchar
      USING CASE
        WHEN status = 0 THEN 'pending'
        WHEN status = 1 THEN 'accepted'
        WHEN status = 2 THEN 'declined'
        WHEN status = 4 THEN 'completed'
        ELSE 'pending'
      END
    SQL

    # Set default
    change_column_default :book_requests, :status, 'pending'
    change_column_null :book_requests, :status, true

    # Change books status from integer to string using USING clause
    execute <<-SQL
      ALTER TABLE books
      ALTER COLUMN status TYPE varchar
      USING CASE
        WHEN status = 0 THEN 'available'
        WHEN status = 1 THEN 'requested'
        WHEN status = 2 THEN 'donated'
        ELSE 'available'
      END
    SQL

    # Set default
    change_column_default :books, :status, 'available'
    change_column_null :books, :status, true
  end
end
