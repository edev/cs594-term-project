require_relative 'core'

require_relative 'messages'
require 'openssl'
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
            @socket = OpenSSL::SSL::SSLSocket.new(TCPSocket.new(@host, @port), OpenSSL::SSL::SSLContext.new)
            @socket.sync_close = true

            begin
                @socket.connect
            rescue Exception => e
                STDOUT.puts "Error: #{e}"
                exit(1)
            end

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
                    STDOUT.puts "Connected to server!"
                    STDOUT.puts help
                    break
                when DeclineGreeting
                    STDERR.puts "Server rejected connection. Reason: #{response[:reason]}"
                    exit(1)
                else
                    STDOUT.puts "Received unrecognized message. Ignoring."
                end
            end
        end

        def help
            <<~END

            Supported commands:
                <message> - send a message to the default room.
                /join <room_name> - join a room.
                /rooms - list all rooms.
                /leave <room_name> - leave a room.
                /members - list members of the default room / connected clients.
                /members <room_name> - list members of a specific room.
                /say <room_name> <message> - speak to a (non-default) room.
                /w <display_name> <message> - whisper to a single client by name.
                /quit or /exit - disconnect from the server and quit the program.
                /? or /help - print this list of commands.

            END
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
                    return
                end

                case message
                when :EOF
                    return
                when :SKIP
                    next
                when RoomList
                    STDOUT.puts "Rooms:"
                    message[:rooms].each { |r| STDOUT.puts "\t#{r}" }
                when RoomMemberList
                    if message[:room] == ""
                        STDOUT.puts "Members of default room:"
                    else
                        STDOUT.puts "Members of #{message[:room]}:"
                    end
                    message[:members].each { |m| STDOUT.puts "\t#{m}" }
                when Said
                    if message[:room] == ""
                        STDOUT.puts "#{message[:sender]}: #{message[:message]}"
                    else
                        STDOUT.puts "[#{message[:room]}] #{message[:sender]}: #{message[:message]}"
                    end
                when Disconnect
                    STDOUT.puts "The server ended the connection."
                    return
                when Success
                    STDOUT.puts message[:message]
                when Notice
                    STDOUT.puts message[:message]
                when Error
                    STDERR.puts message[:message]
                when Whispered
                    STDOUT.puts "(Whisper from #{message[:from]}): #{message[:message]}"
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
                input.chomp!
                case input
                when /^\s*$/
                    # The user entered an empty line.
                    next
                when /^\/quit$/i
                    break
                when /^\/exit$/i
                    break
                when /^\/\?$/
                    STDOUT.puts help
                when /^\/help$/i
                    STDOUT.puts help
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
                when Say.client_command
                    match = Say.client_command.match input
                    @socket.send Say.build(match[:room_name], match[:message])
                when Whisper.client_command
                    match = Whisper.client_command.match input
                    @socket.send Whisper.build(match[:display_name], match[:message])
                when %r{^/} # Any unrecognized slash command.
                    STDERR.puts "Unrecognized command."
                else # Just normal text. Say it to the default room.
                    @socket.send Say.build(room="", message=input)
                end
                print CLI_PROMPT_TEXT
            end
            @socket.send Disconnect.build
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
