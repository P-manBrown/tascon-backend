class Contact < ApplicationRecord
  belongs_to :user
  belongs_to :contact_user, class_name: "User"

  validates :contact_user_id, uniqueness: { scope: :user_id }
  validates :display_name, length: { maximum: 255 }
  validates :display_name, exclusion: [nil], if: :display_name_changed?
  validates :note, length: { maximum: 1000 }
  validates :note, exclusion: [nil], if: :note_changed?
  validate :not_self_contact, on: :create
  validate :contact_user_must_be_public, on: :create

  def not_self_contact
    return unless user_id == contact_user_id

    errors.add(:contact_user, "に自分自身は指定できません。")
  end

  def contact_user_must_be_public
    return unless contact_user&.is_private?

    errors.add(:contact_user, "のプライベートモードが有効なため登録できません。")
  end
end
