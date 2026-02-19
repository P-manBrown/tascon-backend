class Task < ApplicationRecord
  belongs_to :task_group

  enum :status, { not_started: 0, in_progress: 1, completed: 2 }, prefix: true, default: :not_started, validate: true

  validates :name, presence: true, length: { maximum: 255 }
  validates :note, length: { maximum: 1000 }
  validates :time_spent, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_nil: true
  validates :estimated_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_nil: true
  validates :ends_at, comparison: { greater_than: :starts_at }, allow_nil: true, if: :starts_at?

  scope :actionable, lambda {
    today_start = Time.zone.now.beginning_of_day
    today_end = Time.zone.now.end_of_day

    today = where(starts_at: ..today_end, ends_at: today_start..)
    overdue_incomplete = where(ends_at: ...today_start).where.not(status: :completed)

    today.or(overdue_incomplete)
  }

  scope :with_dates_set, -> { where.not(starts_at: nil).where.not(ends_at: nil) }

  scope :in_date_range, lambda { |start_date, end_date|
    start_datetime = start_date.beginning_of_day
    end_datetime = end_date.end_of_day

    starts_in_range = where(starts_at: start_datetime..end_datetime)
    ends_in_range = where(ends_at: start_datetime..end_datetime)
    spans_range = where(starts_at: ..start_datetime).where(ends_at: end_datetime..)

    starts_in_range.or(ends_in_range).or(spans_range)
  }

  scope :ordered_by_ends_at, -> { order(arel_table[:ends_at].asc.nulls_last) }
end
