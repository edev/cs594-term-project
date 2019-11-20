require_relative 'core'

require_relative 'messages'
require 'socket'

CLI_PROMPT_TEXT = ""

module Chat
    ##
    # Provides all the necessary facilities for host an IRC chat client per the project RFC.
    #
    # A client quickstart is available via the #start method using default options. However, it's also possible
    # to fully customize the launch sequence and the various components by either inheriting from this class
    # or by simply calling the public methods in this class in a different manner. To create a custom launch sequence,
    # use the #start method's source as a starting point.
    class Client
        def initialize(host, port)
            @host = host
            @port = port
        end

        ##
        # Creates a connection to the server.
        def connect
            @socket = TCPSocket.new(@host, @port)

            # Modify socket's singleton class to include the Chat::Sendable module.
            class << @socket
                include Chat::Sendable
                include Chat::Receivable
            end

            # Ask the user for a username ("displayName")
            STDOUT.print "Enter your display name (no spaces): "
            display_name = STDIN.gets
            if display_name.nil?
                exit(1)
            end

            # Clean display_name and ensure that it has no spaces.
            display_name.chomp!
            unless display_name =~ /^\S+$/
                puts "Invalid display name."
                exit(1)
            end

            @socket.send Greeting.build(VERSION, display_name)

            # Await the response.
            loop do
                begin
                    response = @socket.receive
                rescue Exception => e
                    STDERR.puts "Error: #{e.message}"
                    exit(1)
                end

                case response
                when :EOF
                    STDERR.puts "Connection lost."
                    exit(1)
                when :SKIP
                    # Malformed packet. Ignore it and keep listening.
                    next
                when AcceptGreeting
                    STDOUT.puts "Connected to server."
                    break
                when DeclineGreeting
                    STDERR.puts "Server rejected connection. Reason: #{response[:reason]}"
                    exit(1)
                else
                    STDOUT.puts "Received unrecognized message. Ignoring."
                end
            end
        end

        ##
        # Listens to the socket and processes input.
        def listen
            loop do
                begin
                    message = @socket.receive
                rescue Exception => e
                    # If the socket was closed, possiby by another thread, then there's no real error, but we do have to quit.
                    unless @socket.closed?
                        # Otherwise, print the cause of the exception.
                        STDERR.puts "Error: #{e.message}"
                    end
                    return false
                end

                case message
                when :EOF
                    return false
                when :SKIP
                    next
                when RoomList
                    puts "Rooms:"
                    message[:rooms].each { |r| puts "\t#{r}" }
                when RoomMemberList
                    if message[:room] == ""
                        puts "Members of default room:"
                    else
                        puts "Members of #{message[:room]}:"
                    end
                    message[:members].each { |m| puts "\t#{m}" }
                else
                    STDOUT.puts "[Debug] unrecognized message received:"
                    p message
                end
            end
        end

        ##
        # Listens for input on stdin and processes it.
        def prompt
            print CLI_PROMPT_TEXT
            while input = STDIN.gets
                input.strip!
                case input
                when ""
                    # The user entered an empty line.
                    next
                when /^\/quit$/i
                    break
                when /^\/exit$/i
                    break
                when JoinRoom.client_command
                    match = JoinRoom.client_command.match input
                    @socket.send JoinRoom.build(match[:room_name])
                when RequestRoomList.client_command
                    @socket.send RequestRoomList.build
                when LeaveRoom.client_command
                    match = LeaveRoom.client_command.match input
                    @socket.send LeaveRoom.build(match[:room_name])
                when RequestRoomMemberList.client_command
                    match = RequestRoomMemberList.client_command.match input
                    @socket.send RequestRoomMemberList.build(match[:room_name])
                when %r{^/} # Any unrecognized slash command.
                    STDERR.puts "Unrecognized command."
                else # Just normal text. Say it.
                    # TODO say.
                    @socket.send({ message: input })
                end
                print CLI_PROMPT_TEXT
            end
            # TODO Disconnect.
            @socket.close
            exit(0)
        end

        def start
            connect

            @prompt_thread = Thread.new { prompt }
            listen
        end
    end
end
