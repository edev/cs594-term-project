require 'set'

##
# This module defines a class Matcher that provides a structure to check objects against general expectations,
# plus a variety of methods that return matchers for various, common purposes.
#
# Literals can, of course, be specified directly.
#
# Any comparison that works correctly on case equality, such as checking that an object is an array or a string,
# can be specified directly and does not require a custom matcher.
#
# Any collection that specifically supports case equality, using case equality to check its elements, can be
# specified directly and does not require a custom matcher.
#
# Hashes and arrays do not have the required case equality support, so the hash and array methods provide
# correct matchers for these data types.
module Chat
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
        # Expects an array object with specified elements.
        def self.array(exact=true, *elems)
            m = Matcher.new

            # First, a basic type check.
            m.expect { |other| Array === other }

            if exact
                # Make sure the set of keys is exactly the expected set.
                m.expect { |other| elems.length == other.length }
            end

            elems.each_index do |i| 
                m.expect { |other| elems[i] === other[i] }
            end
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
    end
end
