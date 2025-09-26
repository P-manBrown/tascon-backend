class TaskGroup < ApplicationRecord
  belongs_to :user

  validates :name, presence: true, length: { maximum: 255 }
  validates :icon, presence: true, length: { maximum: 255 }
  validates :note, length: { maximum: 1000 }
end
