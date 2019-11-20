require_relative 'core'
require_relative 'messages'
require 'socket'

CLI_PROMPT_TEXT = "server> "

module Chat
    class ConnectedClient
        attr_accessor :socket, :thread, :display_name

        def receive
            @socket.receive
        end

        def send(*args)
            @socket.send(*args)
        end
    end

    ##
    # Provides all the necessary facilities for host an IRC chat server per the project RFC.
    #
    # A server quickstart is available via the #start method using default options. However, it's also possible
    # to fully customize the launch sequence and the various components by either inheriting from this class
    # or by simply calling the public methods in this class in a different manner. To create a custom launch sequence,
    # use the #start method's source as a starting point.
    class Server
        ##
        # port - the port the server should listen on.
        def initialize(port)
            @port = port
            @tcpServer = TCPServer.new @port

            # The fields in this block are all synchronized by the lock below.
            @client_info_lock = Mutex.new
            @clients = {}         # Keys are display names, values are ConnectedClient objects.
            @rooms = {}           # Keys are room names, values are lists of users (ConnectedClient) in each room.
        end

        private def create_or_join_room(room_name, client)
            @client_info_lock.synchronize do
                if @rooms.has_key? room_name
                    @rooms[room_name] << client unless @rooms[room_name].include? client
                else
                    @rooms[room_name] = [client]
                end
            end
        end

        private def each_socket(&block)
            if !block_given?
                raise ArgumentError.new "Expected a block, but none was provided."
            end

            # TODO synchronize and, within that, loop over all clients, invoking block.
            raise Exception.new "Not yet implemented."
        end

        ##
        # Removes client from the named room. If client was the member of the room, deletes the room.
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

        private def register_name(name, client)
            @client_info_lock.synchronize do
                if @clients.has_key? name
                    return false
                end
                @clients[name] = client
                return true
            end
        end

        ##
        # Looks up the members of the named room and returns a reply for the requesting client.
        private def room_members(name)
            if name.nil?
                # TODO send an Error message.
                STDERR.puts "Room name cannot be nil."
            end
            if name == ""
                # Send client list.
                members = @client_info_lock.synchronize { @clients.keys.dup }
                RoomMemberList.build name, members
            elsif @rooms.has_key? name
                # Send client list for named room.
                members = @client_info_lock.synchronize { @rooms[name].map &:display_name }
                RoomMemberList.build name, members
            else
                # TODO Send Error message.
                STDERR.puts "Room #{name} does not exist."
            end
        end

        def accept
            @tcpServer.accept
        end

        def clean_up(client)
            @client_info_lock.synchronize do
                # Remove the client from all rooms. If any rooms are empty as a result, remove them.
                @rooms.each do |room_name, member_list|
                    member_list.delete(client)
                    if member_list.length == 0
                        @rooms.delete room_name
                    end
                end
            end
        end

        ##
        # Initializes an incoming client connection and handles the greeting sequence.
        #
        # client - a ConnectedClient.
        def greet(client)
            # Retrieve the current thread to use the thread-local data store for client-specific state.
            thread = Thread.current

            # Modify socket's singleton class to include the Sendable and Receivable modules.
            class << client.socket
                include Sendable
                include Receivable
            end

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

                    if !(/^\S+$/ === message[:displayName])
                        # Fatal: invalid displayName.
                        client.send DeclineGreeting.build("Invalid display name. Spaces are not allowed.")
                        return false
                    end

                    if register_name(message[:displayName], client) == false
                        # Fatal: username already taken.
                        client.send DeclineGreeting.build("Display name is already in use. Please choose a different name.")
                        return false
                    end

                    # This is the first greeting, and everything checks out.
                    client.send AcceptGreeting.build
                    thread[:greeting_done] = true
                    client.display_name = message[:displayName]
                    return true
                end
            end
        end

        ##
        # Listens to input on a socket and responds.
        #
        # client - a ConnectedClient.
        def listen(client)
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
                when JoinRoom
                    # TODO Check whether the room name is valid (no spaces). Otherwise, send error response.
                    create_or_join_room message[:name], client
                when RequestRoomList
                    client.send RoomList.build(@rooms.keys)
                when LeaveRoom
                    leave_room message[:name], client
                    # TODO Check for error returns and pass them as Error messages once Error messages are implemented.
                when RequestRoomMemberList
                    client.send room_members message[:name]
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
                when /^quit$/i
                    break
                when /^exit$/i
                    break
                else
                    STDERR.puts "Unrecognized command."
                end
                print CLI_PROMPT_TEXT
            end
            exit(0)
        end

        ##
        # Starts the server using default options and behavior.
        def start
            STDOUT.puts "Starting server on port #{@port}."
            # First, start a prompt thread.
            @prompt_thread = Thread.new { prompt }

            # Then, start accepting clients for eternity.
            loop do
                # Accept a new connection (blocking).
                socket = accept

                # Store the client socket before invoking a new thread to listen. This avoids a race condition
                # between the two threads by ensuring that client is added to the socket list by the time
                # the thread is spawned. After we have a thread object, we'll store that, too.
                client = ConnectedClient.new
                client.socket = socket
                thread = Thread.new do 
                    if greet(client)
                        listen(client)
                        clean_up(client)
                    end
                end
                @client_info_lock.synchronize do
                    client.thread = thread
                end
            end
        end
    end
end
