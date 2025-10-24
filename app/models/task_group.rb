class TaskGroup < ApplicationRecord
  belongs_to :user
  has_many :tasks, dependent: :destroy

  validates :name, presence: true, length: { maximum: 255 }
  validates :icon, presence: true, length: { maximum: 255 }
  validates :note, length: { maximum: 1000 }
end
