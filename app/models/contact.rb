class Contact < ApplicationRecord
  belongs_to :user
  belongs_to :contact_user, class_name: "User"

  validates :contact_user_id, uniqueness: { scope: :user_id }
  validates :display_name, length: { maximum: 255 }
  validates :note, length: { maximum: 1000 }
  validate :not_self_contact, on: :create

  scope :blocked, -> { where.not(blocked_at: nil) }

  def not_self_contact
    return unless user_id == contact_user_id

    errors.add(:contact_user, "に自分自身は指定できません。")
  end
end
