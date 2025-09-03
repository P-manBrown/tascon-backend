class Block < ApplicationRecord
  belongs_to :blocker, class_name: "User"
  belongs_to :blocked, class_name: "User"

  validates :blocked_id, uniqueness: { scope: :blocker_id }
  validate :cannot_block_self

  private
    def cannot_block_self
      return unless blocker_id == blocked_id

      errors.add(:blocked, :cannot_block_self, message: "に自分自身は指定できません。")
    end
end
