Cccms::Application.config.middleware.use ExceptionNotification::Rack,
  :email => {
    :email_prefix => "[CCCMS] ",
    :sender_address => %("CCCMS Error" <error@www.ccc.de>),
    :exception_recipients => %w(erdgeist@ccc.de)
  }
