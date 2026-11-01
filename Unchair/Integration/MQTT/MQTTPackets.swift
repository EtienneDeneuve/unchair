import Foundation

/// Minimal MQTT 3.1.1 packet builders (CONNECT / PUBLISH / PINGREQ / DISCONNECT).
enum MQTTPackets {
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
        packet.append(contentsOf: remainingLength(body.count))
        packet.append(body)
        return packet
    }

    private static func remainingLength(_ length: Int) -> [UInt8] {
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
}
