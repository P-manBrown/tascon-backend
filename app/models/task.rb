class Task < ApplicationRecord
  belongs_to :task_group

  validates :name, presence: true, length: { maximum: 255 }
  validates :note, length: { maximum: 1000 }
  validates :time_spent, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :estimated_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :ends_at, comparison: { greater_than: :starts_at }, allow_nil: true
end
