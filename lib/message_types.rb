require_relative 'matchers'

module Matchers
    Greeting = hash(type: "greeting",
                    version: /(:?[0-9]\.)*[0-9]/,
                    displayName: string)

    # TODO Write matchers for all message types.
end

# Sample matchers. Use a case statement to match message types.
puts Matchers::Greeting === { type: "greeting", version: "1.2.3.4", displayName: "Mr. Wonka" }

puts ["abc", Matchers::string] === ["abc", "def"]

