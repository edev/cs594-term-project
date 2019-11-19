#!/usr/bin/env ruby

require_relative 'lib/cli'
require_relative 'lib/server'

# Check command-line arguments. Either print a helpful error message or connect to the server.
begin
    case ARGV.length
    when 0
        Chat::Server.new(DEFAULT_PORT).start
    when 1
        port = CommandLine.parse_port(ARGV[0])
        Chat::Server.new(port).start
    else
        print "Too many arguments. Expected arguments: none (to use default port) or port."
        exit(1)
    end
rescue Exception => e
    # Who knows what happened? Maybe the user passed a port that wasn't a port. Exit gracefully.
    STDERR.puts e.message
    exit(1)
end
