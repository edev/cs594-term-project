require_relative 'core'

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
            end

            # TODO Send greeting and await response.
        end

        ##
        # Listens to the socket and processes input.
        def listen
            while message = @socket.gets(sep="\0")
                message.strip!
                if message.length > 0
                    # There's content to process.
                    STDOUT.puts message
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