FactoryBot.define do
  factory :user do
    name { Faker::Name.name }
    email { Faker::Internet.unique.email }
    password { Faker::Internet.password }

    trait :with_confirmed_at do
      confirmed_at { Time.current }
    end

    trait :with_unconfirmed_email do
      unconfirmed_email { Faker::Internet.unique.email }
    end
  end
end
