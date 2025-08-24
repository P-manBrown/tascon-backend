class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable, :confirmable,
         :omniauthable
  include UserOverride

  include Rails.application.routes.url_helpers

  # ":redirect_url" is used to set the redirect URL when updating the email.
  attr_accessor :redirect_url

  has_one_attached :avatar

  has_many :contacts, dependent: :destroy
  has_many :contact_users, through: :contacts

  has_many :reverse_contacts, class_name: "Contact",
                              foreign_key: "contact_user_id", dependent: :destroy, inverse_of: :contact_user
  has_many :reverse_contact_users, through: :reverse_contacts, source: :user

  validates :name, presence: true, length: { maximum: 255 }
  validates :email, uniqueness: { case_sensitive: false }, length: { maximum: 100 }
  validates :avatar, content_type: { in: %w[image/jpeg image/png] }, size: { less_than_or_equal_to: 2.megabytes },
                     processable_file: true, mime_type_and_extension_consistency: true
  validates :bio, length: { maximum: 250 }

  def avatar=(value)
    if value.respond_to?(:original_filename) && value.original_filename
      extension = File.extname(value.original_filename)
      value.original_filename = "#{SecureRandom.alphanumeric(10)}#{extension}"
    end

    super
  end

  def avatar_url
    return nil unless avatar.attached?

    variant = avatar.variant(resize_to_fill: [256, 256], saver: { strip: true })

    rails_representation_url(variant.processed, host: ENV.fetch("WEB_HOST"), port: ENV.fetch("WEB_PORT"))
  end

  def suggestion_users
    reverse_contact_users.includes(:avatar_attachment)
                         .where(contacts: { blocked_at: nil })
                         .where.not(id: contacts.select(:contact_user_id))
  end

  def suggestion_user_ids
    suggestion_users.pluck(:id)
  end
end
