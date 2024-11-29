use koji::midi::output::{output_midi_object, write_variable_length};
use koji::midi::types::{Midi, Message, NoteOn, ProgramChange, MidiTrait};
use core::byte_array::ByteArray;

#[cfg(test)]
mod tests {
    use super::*;
    use core::array::ArrayTrait;
    use koji::midi::types::MidiTrait;

    #[test]
    fn test_basic_midi_output() {
        let midi = MidiTrait::new();
        let output = output_midi_object(@midi);
        
        // Check MIDI header
        assert(output.at(0) == 0x4D, 'Invalid header M'); // 'M'
        assert(output.at(1) == 0x54, 'Invalid header T'); // 'T'
        assert(output.at(2) == 0x68, 'Invalid header h'); // 'h'
        assert(output.at(3) == 0x64, 'Invalid header d'); // 'd'
        
        // Check header length
        assert(output.at(4) == 0x00, 'Invalid header length 1');
        assert(output.at(5) == 0x00, 'Invalid header length 2');
        assert(output.at(6) == 0x00, 'Invalid header length 3');
        assert(output.at(7) == 0x06, 'Invalid header length 4');
    }

    #[test]
    fn test_note_events() {
        let mut midi = MidiTrait::new();
        
        // Add a note on event
        let note_on = NoteOn {
            channel: 0,
            note: 60, // Middle C
            velocity: 100,
            time: FP32x32 { mag: 0, sign: false }
        };
        midi = midi.append_message(Message::NOTE_ON(note_on));

        let output = output_midi_object(@midi);
        
        // Find the note event in the track data (after header and track header)
        let track_start = 18; // Header (14) + MTrk header (4)
        assert(output.at(track_start + 1) == 0x90, 'Invalid Note On status');
        assert(output.at(track_start + 2) == 60, 'Invalid note number');
        assert(output.at(track_start + 3) == 100, 'Invalid velocity');
    }

    #[test]
    fn test_program_change() {
        let mut midi = MidiTrait::new();
        
        // Add a program change event
        let prog_change = ProgramChange {
            channel: 0,
            program: 1, // Acoustic Grand Piano
            time: FP32x32 { mag: 0, sign: false }
        };
        midi = midi.append_message(Message::PROGRAM_CHANGE(prog_change));

        let output = output_midi_object(@midi);
        
        // Find the program change event
        let track_start = 18;
        assert(output.at(track_start + 1) == 0xC0, 'Invalid Program Change status');
        assert(output.at(track_start + 2) == 1, 'Invalid program number');
    }
}