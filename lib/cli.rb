module CommandLine
    ##
    # Either returns the integer port, which will be in-bounds, or exits the application.
    def self.parse_port(str)
        # Since Integer() will read leading 0s as an octal number, let's strip them for user-friendliness.
        # We'll do some other basic string clean-up for the same reason, too.
        str = str.strip.sub(/^0+/, '')

        port = Integer(str)
        if port < 1 || port > 65535
            STDERR.puts "Port must be between 1 and 65535."
            exit(1)
        end
        port
    rescue ArgumentError => e
        STDERR.puts "Port must be an integer."
        exit(1)
    end
end

