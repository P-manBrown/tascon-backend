class TaskGroup < ApplicationRecord
  belongs_to :user
  has_many :tasks, dependent: :destroy
  has_many :task_group_shares, dependent: :destroy
  has_many :shared_users, through: :task_group_shares, source: :user

  validates :name, presence: true, length: { maximum: 255 }
  validates :icon, presence: true, length: { maximum: 255 }
  validates :note, length: { maximum: 1000 }
end
