require 'json'

DEFAULT_PORT = 2019
MESSAGE_SEPARATOR = "\0"
VERSION = "0.1"

module Chat
    module Sendable
        def send(message)
            json = JSON.generate(message) + "\0"
            self.puts json
        end
    end

    module Receivable
        def receive
            message = gets(sep=MESSAGE_SEPARATOR)
            message.strip! unless message.nil?
            return(:EOF) if message.nil? || message.length == 0
            begin
                JSON.parse message, symbolize_names: true
            rescue JSON::ParserError => e
                STDERR.puts "Received a message that was not JSON. Ignored."
                :SKIP
            end
        end
    end
end
