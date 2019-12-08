require 'net/smtp'

message = <<MESSAGE_END
From: Christian Neubauer <me@christianneubauer.de>
To: Christian Neubauer <me@christianneubauer.de>
Subject: SMTP e-mail test

This is a test e-mail message.
MESSAGE_END

Net::SMTP.start('smtp.1und1.de', 25, 'localhost', 'me@christianneubauer.de', '', :plain) do |smtp|
  smtp.send_message(message, 'me@christianneubauer.de', 'me@christianneubauer.de')
end