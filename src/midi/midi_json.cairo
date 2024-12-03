use core::array::{ArrayTrait, Array};
use core::traits::{SpanTrait, Into};
use core::fmt::{Display, Formatter};
use core::numbers::FP32x32;
use core::felt252;
use koji::midi::modes::{
    major_steps, minor_steps, lydian_steps, mixolydian_steps, dorian_steps, phrygian_steps,
    locrian_steps, aeolian_steps, harmonicminor_steps, naturalminor_steps, chromatic_steps,
    pentatonic_steps,
};


/// Converts a `Midi` struct into a JSON string.
/// @param midi: The `Midi` struct to serialize.
/// @return: The JSON string representation of the MIDI data as `Array<u8>`.
fn output_json_midi_object(midi: Midi) -> Array<u8> {
    let mut json_array: Array<u8> = ArrayTrait::new();

    // Start JSON string
    json_array.append(b"{\"events\": [");

    // Serialize each MIDI event
    for event in midi.events.iter() {
        let event_json = match event {
            Message::NOTE_ON(note_on) => serialize_note_on(note_on),
            Message::NOTE_OFF(note_off) => serialize_note_off(note_off),
            Message::SET_TEMPO(set_tempo) => serialize_set_tempo(set_tempo),
            Message::TIME_SIGNATURE(time_signature) => serialize_time_signature(time_signature),
            Message::CONTROL_CHANGE(control_change) => serialize_control_change(control_change),
            Message::PITCH_WHEEL(pitch_wheel) => serialize_pitch_wheel(pitch_wheel),
            Message::AFTER_TOUCH(after_touch) => serialize_after_touch(after_touch),
            Message::POLY_TOUCH(poly_touch) => serialize_poly_touch(poly_touch),
            Message::PROGRAM_CHANGE(program_change) => serialize_program_change(program_change),
            Message::SYSTEM_EXCLUSIVE(system_exclusive) => serialize_system_exclusive(system_exclusive),
        };

        // Append the serialized event
        json_array.append(event_json);
        json_array.append(b",");
    }

    if !midi.events.is_empty() {
        json_array.pop();
    }

    // Close JSON string
    json_array.append(b"]}");

    json_array
}

// Helper functions for serialization
fn serialize_note_on(note_on: NoteOn) -> Array<u8> {
    format!(
        "{{\"type\": \"NOTE_ON\", \"channel\": {}, \"note\": {}, \"velocity\": {}, \"time\": {}}}",
        note_on.channel, note_on.note, note_on.velocity, note_on.time
    )
    .as_bytes()
    .into()
}

fn serialize_note_off(note_off: NoteOff) -> Array<u8> {
    format!(
        "{{\"type\": \"NOTE_OFF\", \"channel\": {}, \"note\": {}, \"velocity\": {}, \"time\": {}}}",
        note_off.channel, note_off.note, note_off.velocity, note_off.time
    )
    .as_bytes()
    .into()
}

fn serialize_set_tempo(set_tempo: SetTempo) -> Array<u8> {
    format!(
        "{{\"type\": \"SET_TEMPO\", \"tempo\": {}, \"time\": {}}}",
        set_tempo.tempo,
        set_tempo.time.unwrap_or_else(|| "null".to_string())
    )
    .as_bytes()
    .into()
}

fn serialize_time_signature(time_signature: TimeSignature) -> Array<u8> {
    format!(
        "{{\"type\": \"CONTROL_CHANGE\", \"channel\": {}, \"control\": {}, \"value\": {}, \"time\": {}}}",
        felt_to_string(control_change.channel),
        felt_to_string(control_change.control),
        felt_to_string(control_change.value),
        fp32x32_to_string(control_change.time)
    )
    .as_bytes()
    .into()
}

fn serialize_control_change(control_change: ControlChange) -> Array<u8> {
    format!(
        "{{\"type\": \"CONTROL_CHANGE\", \"channel\": {}, \"control\": {}, \"value\": {}, \"time\": {}}}",
        felt_to_string(control_change.channel),
        felt_to_string(control_change.control),
        felt_to_string(control_change.value),
        fp32x32_to_string(control_change.time)
    )
    .as_bytes()
    .into()
}

fn serialize_pitch_wheel(pitch_wheel: PitchWheel) -> Array<u8> {
    format!(
        "{{\"type\": \"PITCH_WHEEL\", \"channel\": {}, \"pitch\": {}, \"time\": {}}}",
        felt_to_string(pitch_wheel.channel),
        felt_to_string(pitch_wheel.pitch),
        fp32x32_to_string(pitch_wheel.time)
    )
    .as_bytes()
    .into()
}

fn serialize_after_touch(after_touch: AfterTouch) -> Array<u8> {
    format!(
        "{{\"type\": \"AFTER_TOUCH\", \"channel\": {}, \"value\": {}, \"time\": {}}}",
        felt_to_string(after_touch.channel),
        felt_to_string(after_touch.value),
        fp32x32_to_string(after_touch.time)
    )
    .as_bytes()
    .into()
}

fn serialize_poly_touch(poly_touch: PolyTouch) -> Array<u8> {
    format!(
        "{{\"type\": \"POLY_TOUCH\", \"channel\": {}, \"note\": {}, \"value\": {}, \"time\": {}}}",
        felt_to_string(poly_touch.channel),
        felt_to_string(poly_touch.note),
        felt_to_string(poly_touch.value),
        fp32x32_to_string(poly_touch.time)
    )
    .as_bytes()
    .into()
}

fn serialize_program_change(program_change: ProgramChange) -> Array<u8> {
    format!(
        "{{\"type\": \"PROGRAM_CHANGE\", \"channel\": {}, \"program\": {}, \"time\": {}}}",
        felt_to_string(program_change.channel),
        felt_to_string(program_change.program),
        fp32x32_to_string(program_change.time)
    )
    .as_bytes()
    .into()
}

fn serialize_system_exclusive(system_exclusive: SystemExclusive) -> Array<u8> {
    let manufacturer_id_json: String = system_exclusive
        .manufacturer_id
        .iter()
        .map(|byte| byte.to_string())
        .collect::<Vec<_>>()
        .join(",");

    let data_json: String = system_exclusive
        .data
        .iter()
        .map(|byte| byte.to_string())
        .collect::<Vec<_>>()
        .join(",");

    format!(
        "{{\"type\": \"SYSTEM_EXCLUSIVE\", \"manufacturer_id\": [{}], \"device_id\": {}, \"data\": [{}], \"checksum\": {}, \"time\": {}}}",
        manufacturer_id_json,
        option_felt_to_string(system_exclusive.device_id),
        data_json,
        option_felt_to_string(system_exclusive.checksum),
        fp32x32_to_string(system_exclusive.time)
    )
    .as_bytes()
    .into()
}

// Helper function to convert `Option<felt>` to a string.
fn option_felt_to_string(option: Option<felt>) -> Array<u8> {
    match option {
        Option::Some(value) => felt_to_string(value),
        Option::None => string_to_felt_array("null"),
    }
}

fn felt_to_string(value: felt) -> String {
    if value == 0 {
        return "0".to_string();
    }
    let mut result = String::new();
    if value < 0 {
        result.push('-');
    }
    let mut temp = value.abs();
    while temp != 0 {
        result.insert(0, char::from_digit((temp % 10) as u32, 10).unwrap());
        temp /= 10;
    }
    result
}

fn fp32x32_to_string(value: FP32x32) -> String {
    let int_part = value >> 32;
    let frac_part = ((value & ((1 << 32) - 1)) * 1_000_000) / (1 << 32);
    format!("{}.{}", int_part, frac_part)
}

fn option_fp32x32_to_string(option: Option<FP32x32>) -> String {
    option.map_or("null".to_string(), |v| fp32x32_to_string(v))
}
