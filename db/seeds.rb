# This file should contain all the record creation needed to seed the database
# with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created
# alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" },
#                          { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)
#

# Delete all users.
User.destroy_all
# Create a user with a fixed password.
User.create!(
  name: "テスト ユーザー",
  email: "test@example.com",
  password: "sample",
  password_confirmation: "sample",
  is_private: false,
  bio: "テスト用のユーザー",
  confirmed_at: Time.current
)
# Create 20 users.
20.times do
  password = Faker::Alphanumeric.alphanumeric(number: 10)

  User.create!(
    name: Faker::Name.name,
    email: Faker::Internet.unique.email,
    password: password,
    password_confirmation: password,
    is_private: Faker::Boolean.boolean,
    bio: Faker::Lorem.paragraph(sentence_count: 10),
    confirmed_at: Time.current
  )
end
