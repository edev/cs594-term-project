##
# This file defines one class for each message type in the RFC. Each class provides the following class methods:
#
# build: returns a Hash object containing a message of the given type. (Arguments are not checked for validity.)
# case comparison operator (===): allows the class to be used in case statements to check message types.
#
# The classes are defined in the same order as in the RFC.

require_relative 'matchers'

module Chat
    class Greeting
        @@matcher = Matchers::hash(
            type: "greeting",
            version: /^(:?[0-9]+\.)*[0-9]+$/,
            displayName: String   # Left vague so application can send helpful error responses.
        )

        def self.build(version, display_name)
            {
                type: "greeting",
                version: version,
                displayName: display_name
            }
        end

        def self.===(other)
            @@matcher === other
        end
    end

    class AcceptGreeting
        @@matcher = Matchers::hash(
            type: "greetingResponse",
            response: "accept"
        )

        def self.build
            {
                type: "greetingResponse",
                response: "accept"
            }
        end

        def self.===(other)
            @@matcher === other
        end
    end

    class DeclineGreeting
        @@matcher = Matchers::hash(
            type: "greetingResponse",
            response: "decline",
            reason: String
        )

        def self.build(reason)
            {
                type: "greetingResponse",
                response: "decline",
                reason: reason
            }
        end

        def self.===(other)
            @@matcher === other
        end
    end

    class JoinRoom
        @@matcher = Matchers::hash(
            type: "joinRoom",
            name: String
        )

        def self.build(name)
            {
                type: "joinRoom",
                name: name
            }
        end

        def self.===(other)
            @@matcher === other
        end

        ##
        # /join <room_name>
        def self.client_command
            %r{^/join\s+(?<room_name>\S+)$}
        end
    end

    class RequestRoomList
        @@matcher = Matchers::hash(
            type: "requestRoomList"
        )

        def self.build
            {
                type: "requestRoomList"
            }
        end

        def self.===(other)
            @@matcher === other
        end

        ##
        # /rooms
        def self.client_command
            %r{/rooms}
        end
    end

    class RoomList
        @@matcher = Matchers::hash(
            type: "roomList",
            rooms: Array
        )

        def self.build(room_array)
            {
                type: "roomList",
                rooms: room_array
            }
        end

        def self.===(other)
            @@matcher === other
        end
    end

    class LeaveRoom
        @@matcher = Matchers::hash(
            type: "leaveRoom",
            name: String
        )

        def self.build(name)
            {
                type: "leaveRoom",
                name: name
            }
        end

        def self.===(other)
            @@matcher === other
        end

        ##
        # /leave <room_name>
        def self.client_command
            %r{^/leave\s+(?<room_name>\S+)$}
        end
    end

    class RequestRoomMemberList
        @@matcher = Matchers::hash(
            type: "requestRoomMemberList",
            name: String
        )

        def self.build(name="")
            if name.nil?
                # In case we get a nil name, we'll substitute "" to be nice to the caller and comply with the protocol.
                name = ""
            end

            {
                type: "requestRoomMemberList",
                name: name
            }
        end

        def self.===(other)
            @@matcher === other
        end

        ##
        # Two valid signatures:
        # /members
        # /members <room_name>
        def self.client_command
            %r{^/members(?:\s+(?<room_name>\S+))?$}
        end
    end

    class RoomMemberList
        @@matcher = Matchers::hash(
          "type": "roomMemberList",
          "room": String,
          "members": Array
        )

        def self.build(room, members)
            {
                "type": "roomMemberList",
                "room": room,
                "members": members
            }
        end

        def self.===(other)
            @@matcher === other
        end
    end
end
