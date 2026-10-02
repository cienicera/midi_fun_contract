// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title MidiFun
 * @notice Contract for processing and validating MIDI data on-chain.
 */
contract MidiFun {
    using Strings for uint256;

    /**
     * @notice Converts a MIDI file's ByteArray into a JSON string representation.
     * @param midiData The raw MIDI ByteArray to convert.
     * @return jsonOutput The JSON-formatted ByteArray representing the MIDI data.
     *
     * JSON Structure:
     * {
     *   "midi": {
     *     "format": "<uint16>",       // MIDI format type (0, 1, or 2)
     *     "numTracks": "<uint16>",    // Number of tracks in the MIDI file
     *     "deltaTimeDivision": "<uint16>", // Time division (ticks per beat or frames per second)
     *     "tracks": [
     *       {
     *         "events": [
     *           {
     *             "deltaTime": "<uint32>",  // Time elapsed since previous event
     *             "channel": "<uint8>",     // MIDI channel (0-15) or sysex/status
     *             "type": "<string>",       // Event type: noteOn, noteOff, controlChange, programChange, pitchBend, metaEvent, sysex, etc.
     *             "data": "<bytes>"         // Hex-encoded raw event data (excluding delta-time and status byte)
     *           }
     *         ]
     *       }
     *     ]
     *   }
     * }
     */
    function output_json_midi_object(bytes memory midiData) external pure returns (bytes memory jsonOutput) {
        if (midiData.length < 20) {
            return abi.encodePacked(
                '{"error":"MIDI data too short. Expected at least 20 bytes for MThd header."}'
            );
        }

        // Parse MThd header
        // Bytes 0-3: "MThd"
        // Bytes 4-7: Header size (should be 6)
        // Bytes 8-9: Format
        // Bytes 10-11: Number of tracks
        // Bytes 12-13: Time division

        string memory format = Strings.toString(uint16(be16toUint(midiData, 8)));
        string memory numTracksStr = Strings.toString(uint16(be16toUint(midiData, 10)));
        uint16 timeDivision = uint16(be16toUint(midiData, 12));
        string memory deltaTimeDivision = Strings.toString(timeDivision);

        uint16 numTracksUint = uint16(be16toUint(midiData, 10));

        // Build JSON header
        bytes memory result = abi.encodePacked(
            '{"midi":{"format":', format,
            ',"numTracks":', numTracksStr,
            ',"deltaTimeDivision":', deltaTimeDivision,
            ',"tracks":['
        );

        uint256 offset = 20; // Start after MThd header

        for (uint16 i = 0; i < numTracksUint; i++) {
            if (offset + 8 > midiData.length) break;

            // Parse MTrk chunk
            // Bytes 0-3: "MTrk"
            // Bytes 4-7: Chunk size (big-endian)
            uint32 trackSize = be32toUint(midiData, offset + 4);
            offset += 8; // Skip "MTrk" + size

            if (offset + trackSize > midiData.length) break;

            uint256 trackEnd = offset + trackSize;
            result = abi.encodePacked(result, '{"events":[');

            while (offset < trackEnd) {
                uint32 deltaTime = decodeVariableLengthValue(midiData, offset);
                offset += variableLengthSize();

                if (offset >= trackEnd) break;

                uint8 firstByte = uint8(midiData[offset]);
                offset++;

                uint8 channel;
                uint8 eventType;
                uint8 dataLen;
                bytes memory eventData;

                if (firstByte & 0x80 != 0) {
                    // Status byte
                    channel = firstByte & 0x0F;
                    eventType = firstByte & 0xF0;

                    if (eventType == 0x80) dataLen = 2;       // Note Off
                    else if (eventType == 0x90) dataLen = 2;   // Note On
                    else if (eventType == 0xA0) dataLen = 2;   // Polyphonic Key Pressure
                    else if (eventType == 0xB0) dataLen = 1;   // Control Change
                    else if (eventType == 0xC0) dataLen = 1;   // Program Change
                    else if (eventType == 0xD0) dataLen = 1;   // Channel Pressure
                    else if (eventType == 0xE0) dataLen = 2;   // Pitch Bend
                    else dataLen = 0;
                } else if (firstByte == 0xFF) {
                    // Meta event
                    channel = 0;
                    eventType = 0xFF;
                    if (offset >= trackEnd) break;
                    uint8 metaType = uint8(midiData[offset]); offset++;
                    uint8 metaLen = decodeVariableLengthByte(midiData, offset);
                    offset += variableLengthSize();
                    dataLen = metaLen;
                    if (metaLen > 0 && offset + metaLen <= trackEnd) {
                        eventData = new bytes(metaLen);
                        for (uint8 k = 0; k < metaLen; k++) {
                            eventData[k] = midiData[offset + k];
                        }
                        offset += metaLen;
                    } else {
                        eventData = new bytes(0);
                    }
                    // Write the event now
                    string memory eventTypeStr = "metaEvent";
                    string memory hexData = bytesToHex(eventData);
                    result = abi.encodePacked(
                        result,
                        '{"deltaTime":', Strings.toString(deltaTime),
                        ',"channel":', Strings.toString(channel),
                        ',"type":"', eventTypeStr,
                        '","data":"0x', hexData, '"}'
                    );
                    if (offset < trackEnd) {
                        result = abi.encodePacked(result, ',');
                    }
                    continue;
                } else if (firstByte == 0xF0 || firstByte == 0xF7) {
                    // Sysex event
                    channel = 0;
                    eventType = firstByte;
                    uint8 sysexLen = decodeVariableLengthByte(midiData, offset);
                    offset += variableLengthSize();
                    dataLen = sysexLen;
                    if (sysexLen > 0 && offset + sysexLen <= trackEnd) {
                        eventData = new bytes(sysexLen);
                        for (uint8 k = 0; k < sysexLen; k++) {
                            eventData[k] = midiData[offset + k];
                        }
                        offset += sysexLen;
                    } else {
                        eventData = new bytes(0);
                    }
                    string memory eventTypeStr = (firstByte == 0xF0) ? "sysex" : "sysexFractional";
                    string memory hexData = bytesToHex(eventData);
                    result = abi.encodePacked(
                        result,
                        '{"deltaTime":', Strings.toString(deltaTime),
                        ',"channel":', Strings.toString(channel),
                        ',"type":"', eventTypeStr,
                        '","data":"0x', hexData, '"}'
                    );
                    if (offset < trackEnd) {
                        result = abi.encodePacked(result, ',');
                    }
                    continue;
                } else {
                    // Running status – skip
                    continue;
                }

                if (offset + dataLen > trackEnd) break;

                // Read event data
                eventData = new bytes(dataLen);
                for (uint8 k = 0; k < dataLen; k++) {
                    eventData[k] = midiData[offset + k];
                }
                offset += dataLen;

                // Determine event type string
                string memory eventTypeStr;
                if (eventType == 0x80) eventTypeStr = "noteOff";
                else if (eventType == 0x90) eventTypeStr = "noteOn";
                else if (eventType == 0xA0) eventTypeStr = "pressure";
                else if (eventType == 0xB0) eventTypeStr = "controlChange";
                else if (eventType == 0xC0) eventTypeStr = "programChange";
                else if (eventType == 0xD0) eventTypeStr = "channelPressure";
                else if (eventType == 0xE0) eventTypeStr = "pitchBend";
                else eventTypeStr = "unknown";

                string memory hexData = bytesToHex(eventData);

                result = abi.encodePacked(
                    result,
                    '{"deltaTime":', Strings.toString(deltaTime),
                    ',"channel":', Strings.toString(channel),
                    ',"type":"', eventTypeStr,
                    '","data":"0x', hexData, '"}'
                );

                if (offset < trackEnd) {
                    result = abi.encodePacked(result, ',');
                }
            }

            result = abi.encodePacked(result, "]}");

            if (i < numTracksUint - 1) {
                result = abi.encodePacked(result, ',');
            }

            offset = trackEnd;
        }

        result = abi.encodePacked(result, ']}');

        jsonOutput = result;
    }

    // ---------- Internal helpers ----------

    function be16toUint(bytes memory data, uint256 offset) internal pure returns (uint16) {
        require(offset + 2 <= data.length, "offset out of bounds");
        return uint16(uint8(data[offset])) << 8 | uint16(uint8(data[offset + 1]));
    }

    function be32toUint(bytes memory data, uint256 offset) internal pure returns (uint32) {
        require(offset + 4 <= data.length, "offset out of bounds");
        return uint32(uint8(data[offset])) << 24 | uint32(uint8(data[offset + 1])) << 16
            | uint32(uint8(data[offset + 2])) << 8 | uint32(uint8(data[offset + 3]));
    }

    function variableLengthSize() internal pure returns (uint8) {
        // Placeholder: actual logic computed inline via decode functions
        return 1;
    }

    function decodeVariableLengthValue(bytes memory data, uint256 offset) internal pure returns (uint32 vls_deltaTime) {
        uint32 value = 0;
        for (uint8 i = 0; i < 4; i++) {
            uint8 b = uint8(data[offset + i]);
            value = (value << 7) | (b & 0x7F);
            if ((b & 0x80) == 0) {
                vls_deltaTime = value;
                return;
            }
        }
        vls_deltaTime = value;
    }

    function decodeVariableLengthByte(bytes memory data, uint256 offset) internal pure returns (uint8 vlb_val) {
        uint8 value = 0;
        for (uint8 i = 0; i < 4; i++) {
            uint8 b = uint8(data[offset + i]);
            value = (value << 7) | (b & 0x7F);
            if ((b & 0x80) == 0) {
                vlb_val = value;
                return;
            }
        }
        vlb_val = value;
    }

    function bytesToHex(bytes memory data) internal pure returns (string memory) {
        bytes memory hexChars = "0123456789abcdef";
        bytes memory result = new bytes(data.length * 2);
        for (uint256 i = 0; i < data.length; i++) {
            uint8 byteVal = uint8(data[i]);
            result[i * 2] = hexChars[byteVal >> 4];
            result[i * 2 + 1] = hexChars[byteVal & 0x0F];
        }
        return string(result);
    }
}
