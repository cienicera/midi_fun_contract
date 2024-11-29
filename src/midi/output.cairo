use core::array::ArrayTrait;
use core::array::SpanTrait;
use core::traits::TryInto;
use core::option::OptionTrait;
use core::num::traits::Bounded;
use core::byte_array::ByteArrayTrait;
use koji::midi::types::{
    Midi, Message, NoteOn, NoteOff, SetTempo, TimeSignature, ControlChange, 
    PitchWheel, AfterTouch, PolyTouch, ProgramChange, SystemExclusive
};

#[derive(Drop)]
struct MidiOutput {
    data: Array<u8>
}

trait MidiOutputTrait {
    fn new() -> MidiOutput;
    fn append_byte(ref self: MidiOutput, value: u8);
    fn append_bytes(ref self: MidiOutput, values: Array<u8>);
    fn len(self: @MidiOutput) -> usize;
    fn get_data(self: @MidiOutput) -> Array<u8>;
}

impl MidiOutputImpl of MidiOutputTrait {
    fn new() -> MidiOutput {
        MidiOutput { data: ArrayTrait::new() }
    }

    fn append_byte(ref self: MidiOutput, value: u8) {
        self.data.append(value);
    }

    fn append_bytes(ref self: MidiOutput, mut values: Array<u8>) {
        let mut i = 0;
        loop {
            match values.pop_front() {
                Option::Some(value) => {
                    self.data.append(*value);
                },
                Option::None => { break; }
            };
        }
    }

    fn len(self: @MidiOutput) -> usize {
        self.data.len()
    }

    fn get_data(self: @MidiOutput) -> Array<u8> {
        let mut result = ArrayTrait::new();
        let mut data = self.data.clone();
        loop {
            match data.pop_front() {
                Option::Some(value) => { result.append(*value); },
                Option::None => { break; }
            };
        }
        result
    }
}

fn output_midi_object(midi: @Midi) -> Array<u8> {
    let mut output = MidiOutputTrait::new();
    
    // Add MIDI header chunk
    output.append_bytes(array![0x4D, 0x54, 0x68, 0x64]); // MThd
    output.append_bytes(array![0x00, 0x00, 0x00, 0x06]); // Length
    output.append_bytes(array![0x00, 0x00]); // Format 0
    output.append_bytes(array![0x00, 0x01]); // Number of tracks
    output.append_bytes(array![0x01, 0xE0]); // Division

    // Add track chunk header
    output.append_bytes(array![0x4D, 0x54, 0x72, 0x6B]); // MTrk
    let track_length_pos = output.len();
    output.append_bytes(array![0x00, 0x00, 0x00, 0x00]); // Length placeholder

    let mut prev_time: u32 = 0;
    let mut ev = *midi.events;

    loop {
        match ev.pop_front() {
            Option::Some(event) => {
                match event {
                    Message::NOTE_ON(note) => {
                        let delta = note.time.mag - prev_time;
                        prev_time = note.time.mag;
                        write_variable_length(delta, ref output);
                        
                        output.append_byte(0x90 + note.channel.try_into().unwrap());
                        output.append_byte(note.note.try_into().unwrap());
                        output.append_byte(note.velocity.try_into().unwrap());
                    },
                    Message::NOTE_OFF(note) => {
                        let delta = note.time.mag - prev_time;
                        prev_time = note.time.mag;
                        write_variable_length(delta, ref output);
                        
                        output.append_byte(0x80 + note.channel.try_into().unwrap());
                        output.append_byte(note.note.try_into().unwrap());
                        output.append_byte(note.velocity.try_into().unwrap());
                    },
                    Message::SET_TEMPO(tempo) => {
                        let time = match tempo.time {
                            Option::Some(t) => t.mag,
                            Option::None => prev_time
                        };
                        let delta = time - prev_time;
                        prev_time = time;
                        
                        write_variable_length(delta, ref output);
                        output.append_bytes(array![0xFF, 0x51, 0x03]);
                        
                        let tempo_val: u32 = tempo.tempo;
                        output.append_byte((tempo_val / 65536).try_into().unwrap());
                        output.append_byte(((tempo_val / 256) % 256).try_into().unwrap());
                        output.append_byte((tempo_val % 256).try_into().unwrap());
                    },
                    // Handle other message types as needed
                    _ => {},
                }
            },
            Option::None => { break; }
        };
    }

    // Write End of Track
    output.append_bytes(array![0x00, 0xFF, 0x2F, 0x00]);

    // Update track length
    let track_length = output.len() - track_length_pos - 4;
    let mut final_output = MidiOutputTrait::new();

    // Copy header
    let mut header_data = ArrayTrait::new();
    let mut i = 0;
    loop {
        if i >= track_length_pos {
            break;
        }
        match output.data.get(i) {
            Option::Some(value) => { final_output.append_byte(*value); },
            Option::None => { break; }
        }
        i += 1;
    };

    // Write track length
    final_output.append_byte((track_length / 16777216).try_into().unwrap());
    final_output.append_byte(((track_length / 65536) % 256).try_into().unwrap());
    final_output.append_byte(((track_length / 256) % 256).try_into().unwrap());
    final_output.append_byte((track_length % 256).try_into().unwrap());

    // Copy remaining data
    let mut i = track_length_pos + 4;
    loop {
        if i >= output.len() {
            break;
        }
        match output.data.get(i) {
            Option::Some(value) => { final_output.append_byte(*value); },
            Option::None => { break; }
        }
        i += 1;
    };

    final_output.get_data()
}

fn write_variable_length(mut value: u32, ref output: MidiOutput) {
    if value == 0 {
        output.append_byte(0);
        return;
    }

    let mut buffer = ArrayTrait::new();
    
    loop {
        if value == 0 {
            break;
        }
        buffer.append((value % 128 + 128).try_into().unwrap());
        value = value / 128;
    };

    let mut i = buffer.len();
    if i > 0 {
        i -= 1;
        match buffer.get(i) {
            Option::Some(byte) => {
                output.append_byte(byte % 128);
            },
            Option::None => {},
        }
    }

    loop {
        if i == 0 {
            break;
        }
        i -= 1;
        match buffer.get(i) {
            Option::Some(byte) => { output.append_byte(*byte); },
            Option::None => {},
        }
    }
}