require_relative 'core'
require_relative 'messages'
require 'socket'

CLI_PROMPT_TEXT = "server> "

module Chat
    ##
    # Provides all the necessary facilities for hosting an IRC chat server per the project RFC.
    #
    # A server quickstart is available via the start method using default options. However, it's also possible
    # to fully customize the launch sequence and the various components by either inheriting from this class
    # or by simply calling the public methods in this class in a different manner. To create a custom launch sequence,
    # use the start method's source as a starting point.
    class Server
        ##
        # Encapsulates client-specific information that the server needs to store and provides convenience methods
        # to send and receive data (also accessible via Client#socket#send and #Client#socket#receive).
        class Client
            attr_accessor :socket, :thread, :display_name

            def initialize(socket)
                @socket = socket

                # Modify socket's singleton class to include the Sendable and Receivable modules.
                class << @socket
                    include Sendable
                    include Receivable
                end
            end

            def receive
                @socket.receive
            end

            def send(*args)
                @socket.send(*args)
            end
        end

        ##
        # port - the port the server should listen on.
        def initialize(port)
            @port = port
            @tcpServer = TCPServer.new @port

            # The fields in this block are all synchronized by the lock below.
            @client_info_lock = Mutex.new
            @clients = {}         # Keys are display names, values are Client objects.
            @rooms = {}           # Keys are room names, values are lists of users (Client) in each room.
        end

        ##
        # Creates or adds the given client to the given room.
        #
        # If name is valid, returns true.
        #
        # If name is invalid (e.g. contains spaces or is blank), returns (false, reason) where
        # reason is a text explanation suitable to send to the client, e.g. in an Error message.
        private def create_or_join_room(name, client)
            if name.nil?
                return false, "Room name cannot be nil."
            elsif name.strip == ""
                return false, "Room name cannot be blank."
            elsif /\s/ =~ name
                return false, "Room name cannot contain whitespace."
            end

            @client_info_lock.synchronize do
                if @rooms.has_key? name
                    if @rooms[name].include? client
                        return false, "You are already in #{name}."
                    else
                      @rooms[name] << client
                    end
                else
                    @rooms[name] = [client]
                end
            end
            true
        end

        ##
        # Removes client from the named room. If client was the last member of the room, deletes the room.
        #
        # If the room was found and the client was in the room, returns true.
        #
        # If the room was not found or the client was not in the room, returns (false, reason) where
        # reason is a text explanation suitable to send to the client, e.g. in an Error message.
        private def leave_room(name, client)
            @client_info_lock.synchronize do
                unless @rooms.has_key?(name)
                    return false, "Room #{name} does not exist."
                end

                unless @rooms[name].include?(client)
                    return false, "You are not in room #{name}."
                end

                @rooms[name].delete client

                if @rooms[name].length == 0
                    @rooms.delete name
                end
            end
            true
        end

        ##
        # Attempts to register a new name on behalf of a client by making a new name => client mapping in @clients.
        #
        # Returns true if the mapping was successful or (false, reason) if the mapping could not be made, where
        # reason is a text explanation suitable to send to the client, e.g. in an Error message.
        private def register_name(name, client)
            if name.nil?
                return false, "Name cannot be nil."
            elsif name.strip == ""
                return false, "Name cannot be blank."
            elsif /\s/ =~ name
                return false, "Name cannot contain whitespace."
            end

            @client_info_lock.synchronize do
                if @clients.has_key? name
                    return false, "That name is already taken."
                end
                @clients[name] = client
                return true
            end
        end

        ##
        # Looks up the members of the named room and returns a reply for the requesting client.
        private def room_members(name)
            if name.nil?
                Error.build "Room name cannot be nil."
            elsif name == ""
                # Send client list.
                members = @client_info_lock.synchronize { @clients.keys.dup }
                RoomMemberList.build name, members
            elsif @rooms.has_key? name
                # Send client list for named room.
                members = @client_info_lock.synchronize { @rooms[name].map &:display_name }
                RoomMemberList.build name, members
            else
                Error.build "Room #{name} does not exist."
            end
        end

        ##
        # Causes a speaker to speak a message to a room. Assuming the speaker has a message and is actually
        # a member of the room (which may be the default room), all other members of the room will receive
        # Said messages. In case of any error, the speaker will receive an Error message.
        #
        # Due to the complex, multicast nature of this speaking to a room, this method sends data itself.
        private def speak(room, message, speaker)
            @client_info_lock.synchronize do
                if message.nil?
                    speaker.send Error.build("Message cannot be nil.")
                    return
                end

                if room == ""
                    # Default room. No further checks needed; anyone can speak.
                    @clients.each_value do |client|
                        if client == speaker
                            next
                        end
                        client.send Said.build(room, message, speaker.display_name)
                    end
                else
                    # Named room. Ensure that it exists.
                    unless @rooms.has_key? room
                        speaker.send Error.build("Room #{room} does not exist.")
                        return
                    end

                    # Ensure that the speaker is i nthe room.
                    unless @rooms[room].include? speaker
                      speaker.send Error.build("You are not a member of #{room}.")
                        return
                    end

                    # Everything checks out. Speak to the room.
                    @rooms[room].each do |client|
                        if client == speaker
                            next
                        end
                        client.send Said.build(room, message, speaker.display_name)
                    end
                end
            end
        end

        ##
        # Attempts to look up the intended recipient of a whisper and route the message.
        #
        # Returns (outbound_client, message), where outbound_client is the Client object
        # to which the message should be delivered. The message may be a Whispered
        # message for the intended recipient or an Error message to be returned to the
        # sender.
        #
        # to: the display_name of the intended recipient.
        # from: the Client object of the sender.
        # message: the message to be whispered.
        def whisper(to, from, message)
            @client_info_lock.synchronize do
                if @clients.has_key? to
                    # Success!
                    return @clients[to], Whispered.build(to, from.display_name, message)
                else
                    # No such client. Return an error message.
                    return from, Error.build("Could not find a client named #{to}.")
                end
            end
        end

        def accept
            @tcpServer.accept
        end

        def clean_up(client)
            @client_info_lock.synchronize do
                # Notify everyone that the user has disconnected.
                @clients.each_value do |c|
                    if c == client
                        next
                    end
                    c.send Notice.build("#{client.display_name} has disconnected.")
                end

                # Remove the client from all rooms. If any rooms are empty as a result, remove them.
                @rooms.each do |room_name, member_list|
                    member_list.delete(client)
                    if member_list.length == 0
                        @rooms.delete room_name
                    end
                end

                # Remove the client from @clients, which also frees up the client's display_name.
                @clients.delete client.display_name
            end
        end

        ##
        # Initializes an incoming client connection and handles the greeting sequence.
        #
        # client - a Client object.
        def greet(client)
            loop do
                begin
                    message = client.receive
                rescue Exception => e
                    STDERR.puts "Error: #{e.message}"
                    return false
                end

                case message
                when :EOF
                    return false
                when :SKIP
                    next
                when Greeting
                    if message[:version] != VERSION
                        # Fatal: version mismatch.
                        client.send DeclineGreeting.build("Incompatible version. Server is running #{VERSION}.")
                        return false
                    end

                    unless /^\S+$/ =~ message[:displayName]
                        # Fatal: invalid displayName.
                        client.send DeclineGreeting.build("Invalid display name. Spaces are not allowed.")
                        return false
                    end

                    registered, reason = register_name(message[:displayName], client)
                    if registered == false
                        client.send DeclineGreeting.build(reason)
                        return false
                    end

                    # Everything checks out. Set client.display_name and announce their arrival to others.
                    @client_info_lock.synchronize do
                        client.display_name = message[:displayName]
                        @clients.each_value do |c|
                            if c == client
                                next
                            end
                            c.send Notice.build("#{client.display_name} has connected.")
                        end
                    end
                    client.send AcceptGreeting.build
                    return true
                end
            end
        end

        def help
            <<~END

            Supported commands:
                /quit or /exit - disconnect from the server and quit the program.
                /? or /help - print this list of commands.

            END
        end

        ##
        # Listens to input on a socket and responds.
        #
        # client - a Client.
        def listen(client)
            loop do
                begin
                    message = client.receive
                rescue Exception => e
                    STDERR.puts "Error: #{e.message}"
                    return
                end

                case message
                when :EOF
                    return
                when :SKIP
                    next
                when JoinRoom
                    created, reason = create_or_join_room message[:name], client
                    if created
                        client.send Success.build("Joined #{message[:name]}.")
                    else
                        client.send Error.build(reason)
                    end
                when RequestRoomList
                    room_list = @client_info_lock.synchronize { @rooms.keys.dup }
                    client.send RoomList.build(room_list)
                when LeaveRoom
                    left, reason = leave_room message[:name], client
                    if left
                        client.send Success.build("Left #{message[:name]}.")
                    else
                        client.send Error.build(reason)
                    end
                when RequestRoomMemberList
                    client.send room_members(message[:name])
                when Say
                    speak(message[:room], message[:message], client)
                    room = message[:room]
                when Disconnect
                    return
                when Whisper
                    recipient, message = whisper(message[:to], client, message[:message])
                    recipient.socket.send message
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
                when /^\/quit$/i
                    break
                when /^\/exit$/i
                    break
                when /^\/\?$/
                    STDOUT.puts help
                when /^\/help$/i
                    STDOUT.puts help
                else
                    STDERR.puts "Unrecognized command."
                end
                print CLI_PROMPT_TEXT
            end

            @client_info_lock.synchronize do
                @clients.each_value do |client|
                    client.send Disconnect.build
                end
            end

            exit(0)
        end

        ##
        # Starts the server using default options and behavior.
        def start
            STDOUT.puts "Starting server on port #{@port}."
            STDOUT.puts help

            # First, start a prompt thread.
            @prompt_thread = Thread.new { prompt }

            # Then, start accepting clients for eternity.
            loop do
                # Accept a new connection (blocking).
                socket = accept

                # Store the client socket before invoking a new thread to listen. This avoids a race condition
                # between the two threads by ensuring that client is added to the socket list by the time
                # the thread is spawned. After we have a thread object, we'll store that, too.
                client = Client.new(socket)
                thread = Thread.new do 
                    if greet(client)
                        listen(client)
                        clean_up(client)
                    end
                end
                @client_info_lock.synchronize { client.thread = thread }
            end
        end
    end
end
