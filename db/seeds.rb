# Clear existing data
puts "Clearing existing data..."
User.destroy_all
Book.destroy_all
BookRequest.destroy_all

# Create sample users
puts "Creating sample users..."

users = [
  {
    email_address: 'john.doe@example.com',
    password: 'password123',
    first_name: 'John',
    last_name: 'Doe',
    zip_code: '10001',
    phone: '5550101000',
    verified: true
  },
  {
    email_address: 'jane.smith@example.com',
    password: 'password123',
    first_name: 'Jane',
    last_name: 'Smith',
    zip_code: '10002',
    phone: '5550102000',
    verified: true
  },
  {
    email_address: 'mike.johnson@example.com',
    password: 'password123',
    first_name: 'Mike',
    last_name: 'Johnson',
    zip_code: '10003',
    phone: '5550103000',
    verified: false
  },
  {
    email_address: 'sarah.wilson@example.com',
    password: 'password123',
    first_name: 'Sarah',
    last_name: 'Wilson',
    zip_code: '10001',
    phone: '5550104000',
    verified: true
  }
]

created_users = users.map do |user_data|
  User.create!(user_data)
end

puts "Created #{created_users.length} users"

# Create sample books
puts "Creating sample books..."

books_data = [
  {
    title: 'The Great Gatsby',
    author: 'F. Scott Fitzgerald',
    condition: 'excellent',
    summary: 'A classic American novel about the Jazz Age and the American Dream. This copy is in excellent condition with minimal wear.',
    isbn: '9780743273565',
    genre: 'Fiction',
    published_year: 1925,
    user: created_users[0]
  },
  {
    title: 'To Kill a Mockingbird',
    author: 'Harper Lee',
    condition: 'good',
    summary: 'A powerful story about racial injustice in the American South. This copy shows some signs of use but is still in good reading condition.',
    isbn: '9780446310789',
    genre: 'Fiction',
    published_year: 1960,
    user: created_users[1]
  },
  {
    title: '1984',
    author: 'George Orwell',
    condition: 'fair',
    summary: 'A dystopian novel about totalitarianism and surveillance. This copy has some highlighting and notes but is still readable.',
    isbn: '9780451524935',
    genre: 'Fiction',
    published_year: 1949,
    user: created_users[2]
  },
  {
    title: 'The Hobbit',
    author: 'J.R.R. Tolkien',
    condition: 'excellent',
    summary: 'A fantasy novel about Bilbo Baggins and his journey with thirteen dwarves. This copy is in excellent condition.',
    isbn: '9780547928241',
    genre: 'Fantasy',
    published_year: 1937,
    user: created_users[3]
  },
  {
    title: 'Pride and Prejudice',
    author: 'Jane Austen',
    condition: 'good',
    summary: 'A classic romance novel about Elizabeth Bennet and Mr. Darcy. This copy is in good condition with minor wear.',
    isbn: '9780141439518',
    genre: 'Romance',
    published_year: 1813,
    user: created_users[0]
  },
  {
    title: 'The Catcher in the Rye',
    author: 'J.D. Salinger',
    condition: 'fair',
    summary: 'A coming-of-age novel about Holden Caulfield. This copy has some wear but is still in readable condition.',
    isbn: '9780316769488',
    genre: 'Fiction',
    published_year: 1951,
    user: created_users[1]
  },
  {
    title: 'The Alchemist',
    author: 'Paulo Coelho',
    condition: 'excellent',
    summary: 'A novel about following your dreams and listening to your heart. This copy is in excellent condition.',
    isbn: '9780062315007',
    genre: 'Fiction',
    published_year: 1988,
    user: created_users[2]
  },
  {
    title: 'The Little Prince',
    author: 'Antoine de Saint-Exupéry',
    condition: 'good',
    summary: 'A poetic tale about a young prince who visits various planets. This copy is in good condition.',
    isbn: '9780156013987',
    genre: 'Fiction',
    published_year: 1943,
    user: created_users[3]
  }
]

created_books = books_data.map do |book_data|
  Book.create!(book_data)
end

puts "Created #{created_books.length} books"

# Create some sample book requests
puts "Creating sample book requests..."

requests_data = [
  {
    requester: created_users[1],
    book: created_books[0], # Jane requests The Great Gatsby from John
    message: 'I would love to read this classic! I can pick it up this weekend if that works for you.',
    status: BookRequest::PENDING_STATUS
  },
  {
    requester: created_users[2],
    book: created_books[1], # Mike requests To Kill a Mockingbird from Jane
    message: 'This is one of my favorite books and I would love to have a copy. I can meet you anywhere convenient.',
    status: BookRequest::ACCEPTED_STATUS
  },
  {
    requester: created_users[0],
    book: created_books[3], # John requests The Hobbit from Sarah
    message: 'I\'ve been wanting to read this for a while. Would love to add it to my collection!',
    status: BookRequest::PENDING_STATUS
  }
]

created_requests = requests_data.map do |request_data|
  BookRequest.create!(request_data)
end

puts "Created #{created_requests.length} book requests"

puts "Seed data created successfully!"
puts "You can now log in with any of these accounts:"
users.each do |user_data|
  puts "- #{user_data[:email_address]} (password: password123)"
end
