class TaskGroupShare < ApplicationRecord
  belongs_to :task_group
  belongs_to :user

  scope :without_blocked_owners, lambda { |user|
    joins(:task_group).where.not(task_groups: { user_id: user.blocked_users })
  }

  validate :cannot_share_with_owner, :must_be_contact

  private
    def cannot_share_with_owner
      return unless task_group
      return unless task_group.user_id == user_id

      errors.add(:user, :cannot_share_with_owner, message: "に自分は指定できません。")
    end

    def must_be_contact
      return unless task_group && user

      return if task_group.user.contact?(user)

      errors.add(:user, :must_be_contact, message: "には登録しているユーザーを指定してください。")
    end
end
