#!/usr/bin/env ruby

require_relative 'lib/client'

EXPECTED_ARGS_MESSAGE = "Expected arguments: server address and (optional) port."

# Check command-line arguments. Either print a helpful error message or connect to the server.
case ARGV.length
when 0
    STDERR.puts EXPECTED_ARGS_MESSAGE
    exit(1)
when 1
    Chat::Client.new(ARGV[0], DEFAULT_PORT).start
when 2
    Chat::Client.new(ARGV[0], ARGV[1]).start
else
    print "Too many arguments. "
    STDERR.puts EXPECTED_ARGS_MESSAGE
    exit(1)
end
