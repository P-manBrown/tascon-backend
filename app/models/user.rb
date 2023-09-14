class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable, :confirmable,
         :omniauthable
  include DeviseTokenAuth::Concerns::User

  # ":redirect_url" is used to set the redirect URL when updating the email.
  attr_accessor :redirect_url
end
