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

# Create contacts for test user with specific relationship patterns
test_user = User.find_by(email: "test@example.com")
User.where.not(id: test_user.id)
public_users = User.where(is_private: false).where.not(id: test_user.id)

# Test user -> other users (unidirectional relationship)
reverse_only_users = public_users.limit(25)
Rails.logger.debug "Creating reverse-only relationships (test_user -> others)..."
reverse_only_users.each_with_index do |contact_user, index|
  is_blocked = (index % 8).zero? # Block every 8th user
  blocked_at = is_blocked ? Faker::Time.between(from: 30.days.ago, to: Time.current) : nil

  Contact.create!(
    user_id: test_user.id,
    contact_user_id: contact_user.id,
    display_name: "#{contact_user.name} (reverse only)",
    note: "Unidirectional relationship test (test -> other) - #{Faker::Lorem.sentence}",
    blocked_at: blocked_at
  )
rescue ActiveRecord::RecordInvalid => e
  Rails.logger.debug { "Reverse-only contact creation failed: #{e.message}" }
  next
end

# Unidirectional relationship (other users -> test user)
Rails.logger.debug "Creating unidirectional relationships (others -> test_user)..."
unidirectional_users = public_users.offset(35).limit(8)
unidirectional_users.each_with_index do |user, index|
  is_blocked = (index % 7).zero? # Block every 7th user
  blocked_at = is_blocked ? Faker::Time.between(from: 7.days.ago, to: Time.current) : nil

  Contact.create!(
    user_id: user.id,
    contact_user_id: test_user.id,
    display_name: "Test user registered by #{user.name}",
    note: "Unidirectional relationship test (other -> test) - #{Faker::Lorem.sentence}",
    blocked_at: blocked_at
  )
rescue ActiveRecord::RecordInvalid => e
  Rails.logger.debug { "Unidirectional contact creation failed: #{e.message}" }
  next
end

# Mutual relationship (test user <-> other users)
Rails.logger.debug "Creating mutual relationships (test_user <-> others)..."
mutual_users = public_users.offset(25).limit(10)
mutual_users.each_with_index do |user, index|
  is_blocked_forward = (index % 8).zero? # Block every 8th user
  blocked_at_forward = is_blocked_forward ? Faker::Time.between(from: 10.days.ago, to: Time.current) : nil

  Contact.create!(
    user_id: test_user.id,
    contact_user_id: user.id,
    display_name: "#{user.name} (mutual)",
    note: "Mutual relationship (test -> other) - #{Faker::Lorem.sentence}",
    blocked_at: blocked_at_forward
  )

  # Other users -> test user (create reverse direction)
  is_blocked_reverse = (index % 6).zero? # Block every 6th user
  blocked_at_reverse = is_blocked_reverse ? Faker::Time.between(from: 5.days.ago, to: Time.current) : nil

  Contact.create!(
    user_id: user.id,
    contact_user_id: test_user.id,
    display_name: "Test user registered by #{user.name} (mutual)",
    note: "Mutual relationship (other -> test) - #{Faker::Lorem.sentence}",
    blocked_at: blocked_at_reverse
  )
rescue ActiveRecord::RecordInvalid => e
  Rails.logger.debug { "Mutual contact creation failed: #{e.message}" }
  next
end

Rails.logger.debug "\n=== Relationship pattern creation completed ==="
Rails.logger.debug { "- Reverse only (test_user -> others): #{reverse_only_users.count} users" }
Rails.logger.debug { "- Unidirectional (others -> test_user): #{unidirectional_users.count} users" }
Rails.logger.debug { "- Mutual (test_user <-> others): #{mutual_users.count} users" }
Rails.logger.debug do
  "- No relationship: #{100 - reverse_only_users.count - unidirectional_users.count - mutual_users.count} users"
end

Rails.logger.debug "\n=== Test data preparation for suggestions feature completed ==="
Rails.logger.debug do
  "Number of users that should appear in suggestions: #{unidirectional_users.count} (unidirectional relationships)"
end
