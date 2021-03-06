class RegisterUserEmailForm
  include ActiveModel::Model
  include FormEmailValidator

  attr_reader :request_id

  def self.model_name
    ActiveModel::Name.new(self, nil, 'User')
  end

  delegate :email, to: :user

  def user
    @user ||= User.new
  end

  def resend
    'true'
  end

  def submit(params)
    user.email = params[:email]
    request_id = params[:request_id]

    if valid_form?
      process_successful_submission(request_id)
    else
      @success = process_errors(request_id)
    end

    FormResponse.new(success: success, errors: errors.messages, extra: extra_analytics_attributes)
  end

  private

  attr_writer :email
  attr_reader :success

  def valid_form?
    valid? && !email_taken?
  end

  def process_successful_submission(request_id)
    @success = true
    user.save!
    user.send_custom_confirmation_instructions(request_id)
  end

  def extra_analytics_attributes
    {
      email_already_exists: email_taken?,
      user_id: existing_user.uuid,
    }
  end

  def process_errors(request_id)
    # To prevent discovery of existing emails, we check to see if the email is
    # already taken and if so, we act as if the user registration was successful.
    if email_taken? && user_unconfirmed?
      existing_user.send_custom_confirmation_instructions(request_id)
      true
    elsif email_taken?
      UserMailer.signup_with_your_email(email).deliver_later
      true
    else
      false
    end
  end

  def user_unconfirmed?
    !existing_user.confirmed?
  end

  def existing_user
    @_user ||= User.find_with_email(email) || AnonymousUser.new
  end
end
