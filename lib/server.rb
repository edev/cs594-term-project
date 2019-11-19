require_relative 'core'
require 'socket'

CLI_PROMPT_TEXT = "server> "

module Chat
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
            @client_sockets = []
            @client_threads = []
            @clients_lock = Mutex.new
        end

        ##
        # Adds a socket and/or a thread to the client list in a thread-safe way.
        #
        # Either socket or client can safely be nil. There is no pairing between the two; this method can safely
        # add sockets, threads, or both to their respective lists.
        private def add_client(socket=nil, thread=nil)
            @clients_lock.synchronize do
                @client_sockets << socket unless socket.nil?
                @client_threads << thread unless thread.nil?
            end
        end

        private def each_socket(&block)
            if !block_given?
                raise ArgumentError.new "Expected a block, but none was provided."
            end

            # TODO synchronize and, within that, loop over all clients, invoking block.
            raise Exception.new "Not yet implemented."
        end

        private def each_thread(&block)
            if !block_given?
                raise ArgumentError.new "Expected a block, but none was provided."
            end

            @clients_lock.synchronize do
                @client_threads.each do |t|
                    yield i
                end
            end
        end

        def accept
            @tcpServer.accept
        end

        ##
        # Listens to input for a TCPSocket and responds.
        #
        # client - a TCPSocket object representing a newly connected client.
        def listen(client)
            # Modify socket's singleton class to include the Sendable and Receivable modules.
            class << client
                include Sendable
                include Receivable
            end
            loop do
                message = client.receive
                case message
                when :EOF
                    break
                when :SKIP
                    next
                when Hash
                    # TODO Process message
                    # temporary, proof-of-concept:
                    p message
                    client.send message
                else
                    STDERR.puts "Receivable#receive returned a non-Hash value:"
                    STDERR.puts message.inspect
                    STDERR.puts "Skipping."
                    next
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
                client = accept

                # Store the client socket before invoking a new thread to listen. This avoids a race condition
                # between the two threads by ensuring that client is added to the socket list by the time
                # the thread is spawned. After we have a thread object, we'll store that, too.
                add_client(socket: client)
                thread = Thread.new { listen(client) }
                add_client(thread: client)
            end
        end
    end
end
