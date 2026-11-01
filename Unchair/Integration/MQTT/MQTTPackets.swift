import Foundation

/// Minimal MQTT 3.1.1 packet builders/parsers (CONNECT / PUBLISH / SUBSCRIBE / PING / DISCONNECT).
enum MQTTPackets {
    enum Inbound: Equatable, Sendable {
        case connack(code: UInt8)
        case publish(topic: String, payload: Data, retain: Bool)
        case suback(packetID: UInt16)
        case pingresp
        case ignored
    }

    static func connect(
        clientID: String,
        username: String?,
        password: String?,
        keepAliveSeconds: UInt16,
        willTopic: String?,
        willMessage: String?,
        willRetain: Bool
    ) -> Data {
        var payload = Data()
        payload.append(mqttString(clientID))

        var flags: UInt8 = 0x02 // clean session
        if let willTopic, let willMessage {
            payload.append(mqttString(willTopic))
            payload.append(mqttString(willMessage))
            flags |= 0x04 // will flag
            if willRetain { flags |= 0x20 }
            // will QoS 1 → bits 3-4 = 01
            flags |= 0x08
        }
        if let username {
            flags |= 0x80
            payload.append(mqttString(username))
        }
        if let password {
            flags |= 0x40
            payload.append(mqttString(password))
        }

        var variable = Data()
        variable.append(mqttString("MQTT"))
        variable.append(4) // protocol level 3.1.1
        variable.append(flags)
        variable.append(UInt8(keepAliveSeconds >> 8))
        variable.append(UInt8(keepAliveSeconds & 0xff))
        variable.append(payload)

        return wrap(type: 0x10, body: variable)
    }

    static func publish(topic: String, payload: Data, retain: Bool, qos: UInt8 = 0) -> Data {
        var body = Data()
        body.append(mqttString(topic))
        // QoS 0 — no packet id
        body.append(payload)
        var header: UInt8 = 0x30
        if retain { header |= 0x01 }
        if qos == 1 { header |= 0x02 }
        return wrap(type: header, body: body)
    }

    static func subscribe(topic: String, packetID: UInt16, qos: UInt8 = 0) -> Data {
        var body = Data()
        body.append(UInt8(packetID >> 8))
        body.append(UInt8(packetID & 0xff))
        body.append(mqttString(topic))
        body.append(qos & 0x03)
        // SUBSCRIBE requires reserved flag bits 0010
        return wrap(type: 0x82, body: body)
    }

    static func pingReq() -> Data {
        Data([0xc0, 0x00])
    }

    static func disconnect() -> Data {
        Data([0xe0, 0x00])
    }

    /// Returns CONNACK return code if buffer starts with a CONNACK; nil if incomplete.
    static func parseConnack(from buffer: Data) -> UInt8? {
        guard buffer.count >= 4 else { return nil }
        guard buffer[0] == 0x20 else { return nil }
        // remaining length 2 for CONNACK
        return buffer[3]
    }

    /// Consume one complete MQTT control packet from the front of `buffer`.
    /// Returns nil when more bytes are needed. Never traps on malformed input.
    static func consumeInboundPacket(from buffer: inout Data) -> Inbound? {
        let bytes = [UInt8](buffer)
        guard !bytes.isEmpty else { return nil }
        let header = bytes[0]
        let type = header & 0xf0
        guard let (remaining, lengthSize) = decodeRemainingLength(bytes, start: 1) else {
            return nil
        }
        let headerSize = 1 + lengthSize
        guard remaining >= 0, headerSize > 0 else { return nil }
        let total = headerSize + remaining
        guard bytes.count >= total else { return nil }

        let body = Array(bytes[headerSize..<total])
        buffer = Data(bytes[total...])

        switch type {
        case 0x20:
            guard body.count >= 2 else { return .ignored }
            return .connack(code: body[1])
        case 0x30:
            return parsePublishBody(body, retain: (header & 0x01) != 0, qos: (header >> 1) & 0x03)
        case 0x90:
            guard body.count >= 2 else { return .ignored }
            let packetID = (UInt16(body[0]) << 8) | UInt16(body[1])
            return .suback(packetID: packetID)
        case 0xd0:
            return .pingresp
        default:
            return .ignored
        }
    }

    private static func parsePublishBody(_ body: [UInt8], retain: Bool, qos: UInt8) -> Inbound {
        guard body.count >= 2 else { return .ignored }
        let topicLength = (Int(body[0]) << 8) | Int(body[1])
        guard topicLength >= 0, body.count >= 2 + topicLength else { return .ignored }
        let topicData = Array(body[2..<(2 + topicLength)])
        guard let topic = String(bytes: topicData, encoding: .utf8) else { return .ignored }
        var offset = 2 + topicLength
        if qos > 0 {
            guard body.count >= offset + 2 else { return .ignored }
            offset += 2 // packet id
        }
        let payload = Data(body[offset...])
        return .publish(topic: topic, payload: payload, retain: retain)
    }

    private static func mqttString(_ string: String) -> Data {
        let utf8 = Array(string.utf8)
        var data = Data()
        data.append(UInt8((utf8.count >> 8) & 0xff))
        data.append(UInt8(utf8.count & 0xff))
        data.append(contentsOf: utf8)
        return data
    }

    private static func wrap(type: UInt8, body: Data) -> Data {
        var packet = Data()
        packet.append(type)
        packet.append(contentsOf: encodeRemainingLength(body.count))
        packet.append(body)
        return packet
    }

    private static func encodeRemainingLength(_ length: Int) -> [UInt8] {
        var x = length
        var bytes: [UInt8] = []
        repeat {
            var encoded = UInt8(x % 128)
            x /= 128
            if x > 0 { encoded |= 0x80 }
            bytes.append(encoded)
        } while x > 0
        return bytes
    }

    private static func decodeRemainingLength(_ buffer: [UInt8], start: Int) -> (Int, Int)? {
        var multiplier = 1
        var value = 0
        var index = start
        var encodedBytes = 0
        while index < buffer.count {
            let encoded = Int(buffer[index])
            index += 1
            encodedBytes += 1
            value += (encoded & 127) * multiplier
            if encoded & 128 == 0 {
                return (value, encodedBytes)
            }
            multiplier *= 128
            if encodedBytes > 4 || multiplier > 128 * 128 * 128 {
                return nil
            }
        }
        return nil
    }
}
