class TaskGroupShare < ApplicationRecord
  belongs_to :task_group
  belongs_to :user

  enum :status, { shared: 0, handover_pending: 1 }, prefix: true, default: :shared, validate: true

  scope :without_blocked_owners, lambda { |user|
    joins(:task_group).where.not(task_groups: { user_id: user.blocked_users })
  }

  validates :user_id, uniqueness: { scope: :task_group_id }
  validate :cannot_share_with_owner, :must_be_contact
  validate :only_one_handover_pending_per_task_group, if: :status_handover_pending?

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

    def only_one_handover_pending_per_task_group
      return unless task_group
      return unless task_group.task_group_shares.status_handover_pending.where.not(id: id).exists?

      errors.add(:status, :handover_pending_conflict, message: "はすでに他の引き継ぎ依頼が進行中のため設定できません。")
    end
end
