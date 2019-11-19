require 'set'

##
# This module defines a class Matcher that provides a structure to check objects against general expectations,
# plus a variety of methods that return matchers for various, common purposes.
#
# Matchers for float, integer, string, and array simply verify the type of the object.
#
# The hash matcher verifies an Hash object's keys and values. (The latter can be literals or any matchers.)
#
# Literals, specific arrays (including ones with matchers), and anything that responds to == and ===
# in the desired manner can be directly specified, e.g. ["abc", Matchers::string] will match ["abc", "def"].
module Matchers
    ##
    # Defines the structure of a matcher that can examine an object and decide whether it amtches a given spec.
    class Matcher
        def initialize()
            # A list of blocks that must all return true in order for an object to match.
            @matchers = []
        end
        
        ##
        # Adds a block to the list of expectations. The block must take a single argument, the object to examine.
        def expect(&block)
            @matchers << block
        end

        ##
        # Case equality for matchers: checks whether the object matches the matcher's expectations.
        def ===(other)
            @matchers.each do |m|
                if m.call(other) == false
                    return false
                end
            end

            # All matchers returned true, so they passed!
            return true
        end

        alias == ===
    end

    ##
    # Expects a Hash object with exactly the keys provided and exactly the specified values for said keys.
    #
    # exact - if true, no other keys may be present in the hash.
    def self.hash(exact=true, **elems)
        m = Matcher.new

        # First, a basic type check.
        m.expect { |other| Hash === other }

        if exact
            # Make sure the set of keys is exactly the expected set.
            m.expect { |other| Set.new(elems.keys) == Set.new(other.keys) }
        end

        # Verify that every key matches the expectation.
        elems.each do |key, matcher|
            m.expect { |other| matcher === other[key] }
        end
        
        m
    end

    [
        Float,
        Integer,
        String,
        Array
    ].each do |cls|
        method = cls.name.downcase.to_sym
        self.class.define_method(method) do
            m = Matcher.new
            m.expect { |other| cls === other }
            m
        end
    end
end

