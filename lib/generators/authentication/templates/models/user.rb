class User < ApplicationRecord
  MIN_PASSWORD = 4

  has_secure_password validations: false

  generates_token_for :email_verification, expires_in: 2.days do
    email
  end
  generates_token_for :password_reset, expires_in: 20.minutes

  has_many :sessions, dependent: :destroy

  # Twitter2 does not provide email, so we allow blank
  validate :email_or_name_present

  with_options if: ->(u) { u.email.present? } do
    validates :email, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  end

  with_options if: ->(u) { u.name.present? } do
    validates :name, presence: true, length: { minimum: 4 }
  end
  validates :password, allow_nil: true, length: { minimum: MIN_PASSWORD }, if: :password_required?
  validates :password, confirmation: true, if: :password_required?

  normalizes :email, with: -> { _1.strip.downcase }

  before_validation if: :email_changed?, on: :update do
    self.verified = false
  end

  after_update if: :password_digest_previously_changed? do
    sessions.where.not(id: Current.session).delete_all
  end

  # OAuth methods
  def self.from_omniauth(auth)
    find_or_create_by(provider: auth.provider, uid: auth.uid) do |user|
      name = auth.info.name
      if name.blank?
        name = auth.info.email.split('@').first
      end
      user.name = name
      user.email = auth.info.email
      user.provider = auth.provider
      user.uid = auth.uid
      user.verified = true
    end
  end

  def oauth_user?
    provider.present? && uid.present?
  end

  private

  def email_or_name_present
    if email.blank? && name.blank?
      errors.add(:base, "Either email or name must be provided")
    end
  end

  def password_required?
    return false if oauth_user?
    password_digest.blank? || password.present?
  end

end
