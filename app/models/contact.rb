class Contact < ApplicationRecord
  belongs_to :user
  belongs_to :contact_user, class_name: "User"

  validates :contact_user_id, uniqueness: { scope: :user_id }
  validates :display_name, length: { maximum: 255 }
  validates :note, length: { maximum: 1000 }
  validate :cannot_add_self_contact, :cannot_add_blocked_user, on: :create

  private
    def cannot_add_self_contact
      return unless user_id == contact_user_id

      errors.add(:contact_user, :cannot_add_self_contact, message: "に自分自身は指定できません。")
    end

    def cannot_add_blocked_user
      return unless user.blocked_users.exists?(contact_user.id)

      errors.add(:contact_user, :cannot_add_blocked_user, message: "はブロックしているため登録できません。")
    end
end
