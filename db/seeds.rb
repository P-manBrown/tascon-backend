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
  confirmed_at: Time.current
)
# Create 100 users.
100.times do
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

# Delete all contacts.
Contact.destroy_all
# Create contacts for test user.
test_user = User.find_by(email: "test@example.com")
other_users = User.where.not(id: test_user.id)
other_users.each do |contact_user|
  Contact.create!(
    user_id: test_user.id,
    contact_user_id: contact_user.id,
    display_name: Faker::Name.name,
    note: Faker::Lorem.paragraph(sentence_count: 3)
  )
rescue ActiveRecord::RecordInvalid
  next
end
