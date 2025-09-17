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
test_user = User.create!(
  name: "テスト ユーザー",
  email: "test@example.com",
  password: "sample",
  password_confirmation: "sample",
  confirmed_at: Time.current
)

# Create 300 users.
created_users = []
300.times do |_i|
  password = Faker::Alphanumeric.alphanumeric(number: 10)

  user = User.create!(
    name: Faker::Name.name,
    email: Faker::Internet.unique.email,
    password: password,
    password_confirmation: password,
    is_private: Faker::Boolean.boolean(true_ratio: 0.2), # rubocop:disable Rails/ThreeStateBooleanColumn
    bio: Faker::Lorem.paragraph(sentence_count: 10),
    confirmed_at: Time.current
  )
  created_users << user
end

# Delete all contacts.
Contact.destroy_all

# Define user groups with clear separation to prevent data conflicts
contact_users = created_users[0, 100]        # First 100 users for contact relationships
block_users = created_users[100, 100]        # Second 100 users for block relationships
other_users = created_users[200, 100]        # Third 100 users for future features

# Filter for public users only
contact_public_users = contact_users.reject(&:is_private?)

# Create contacts for test user with specific relationship patterns using ONLY contact group users
# Test user -> other users (unidirectional relationship)
reverse_only_users = contact_public_users.take(25)
Rails.logger.debug "Creating reverse-only relationships (test_user -> others)..."
reverse_only_users.each do |contact_user|
  Contact.create!(
    user_id: test_user.id,
    contact_user_id: contact_user.id,
    display_name: "#{contact_user.name} (reverse only)",
    note: "Unidirectional relationship test (test -> other) - #{Faker::Lorem.sentence}"
  )
rescue ActiveRecord::RecordInvalid => e
  Rails.logger.debug { "Reverse-only contact creation failed: #{e.message}" }
  next
end

# Unidirectional relationship (other users -> test user)
Rails.logger.debug "Creating unidirectional relationships (others -> test_user)..."
unidirectional_users = contact_public_users.drop(25).take(25)
unidirectional_users.each do |user|
  Contact.create!(
    user_id: user.id,
    contact_user_id: test_user.id,
    display_name: "Test user registered by #{user.name}",
    note: "Unidirectional relationship test (other -> test) - #{Faker::Lorem.sentence}"
  )
rescue ActiveRecord::RecordInvalid => e
  Rails.logger.debug { "Unidirectional contact creation failed: #{e.message}" }
  next
end

# Mutual relationship (test user <-> other users)
Rails.logger.debug "Creating mutual relationships (test_user <-> others)..."
remaining_contact_users = contact_public_users.drop(50)
mutual_users = remaining_contact_users.take([remaining_contact_users.count, 25].min)
mutual_users.each do |user|
  # Test user -> other users (create forward direction)
  Contact.create!(
    user_id: test_user.id,
    contact_user_id: user.id,
    display_name: "#{user.name} (mutual)",
    note: "Mutual relationship (test -> other) - #{Faker::Lorem.sentence}"
  )

  # Other users -> test user (create reverse direction)
  Contact.create!(
    user_id: user.id,
    contact_user_id: test_user.id,
    display_name: "Test user registered by #{user.name} (mutual)",
    note: "Mutual relationship (other -> test) - #{Faker::Lorem.sentence}"
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

Rails.logger.debug do
  "
  === Generating block relationships test data ==="
end

# Delete all blocks.
Block.destroy_all

# Filter for public users in block group only
block_public_users = block_users.reject(&:is_private?)

# Test user blocks other users (one-way block: test_user -> others) using ONLY block group users
Rails.logger.debug "Creating one-way blocks (test_user blocks others)..."
blocked_by_test_users = block_public_users.take(25)
blocked_by_test_users.each do |blocked_user|
  Block.create!(
    blocker_id: test_user.id,
    blocked_id: blocked_user.id
  )
rescue ActiveRecord::RecordInvalid => e
  Rails.logger.debug { "One-way block creation failed: #{e.message}" }
  next
end

# Other users block test user (one-way block: others -> test_user)
Rails.logger.debug "Creating reverse one-way blocks (others block test_user)..."
blockers_of_test_user = block_public_users.drop(25).take(25)
blockers_of_test_user.each do |blocker_user|
  Block.create!(
    blocker_id: blocker_user.id,
    blocked_id: test_user.id
  )
rescue ActiveRecord::RecordInvalid => e
  Rails.logger.debug { "Reverse one-way block creation failed: #{e.message}" }
  next
end

# Mutual blocking (both directions)
Rails.logger.debug "Creating mutual blocks (bidirectional blocking)..."
remaining_block_users = block_public_users.drop(50)
mutual_block_users = remaining_block_users.take([remaining_block_users.count, 25].min)
mutual_block_users.each do |mutual_user|
  # Test user blocks the other user
  Block.create!(
    blocker_id: test_user.id,
    blocked_id: mutual_user.id
  )

  # The other user blocks test user back
  Block.create!(
    blocker_id: mutual_user.id,
    blocked_id: test_user.id
  )
rescue ActiveRecord::RecordInvalid => e
  Rails.logger.debug { "Mutual block creation failed: #{e.message}" }
  next
end

# No blocking relationship (reference users - these have no blocks with test_user)
Rails.logger.debug "Identifying non-blocked users (no blocking relationship)..."
other_public_users = other_users.reject(&:is_private?)
Rails.logger.debug { "Non-blocked users: #{other_public_users.count} users (these have no block relationship)" }

Rails.logger.debug do
  "
=== Block relationship pattern creation completed ==="
end
Rails.logger.debug { "- Test user blocks others: #{blocked_by_test_users.count} users" }
Rails.logger.debug { "- Others block test user: #{blockers_of_test_user.count} users" }
Rails.logger.debug { "- Mutual blocking: #{mutual_block_users.count} users" }
Rails.logger.debug { "- No blocking relationship: #{other_public_users.count} users" }

Rails.logger.debug do
  "
=== Block functionality test data generation completed ==="
end
Rails.logger.debug do
  "Total blocks created: #{Block.count} block relationships"
end
