#[cfg(test)]
mod tests {
    use debug::PrintTrait;
    use core::traits::Into;
    use core::traits::TryInto;
    use orion::operators::tensor::{Tensor, U32Tensor,};
    use orion::numbers::{FP32x32};
    use core::option::OptionTrait;
    use dict::Felt252DictTrait;
    use koji::midi::types::{
        Midi, Message, Modes, ArpPattern, VelocityCurve, NoteOn, NoteOff, SetTempo, TimeSignature,
        ControlChange, PitchWheel, AfterTouch, PolyTouch, Direction, PitchClass, ProgramChange,
        SystemExclusive,
    };
    use alexandria_data_structures::stack::{StackTrait, Felt252Stack, NullableStack};
    use alexandria_data_structures::array_ext::{ArrayTraitExt, SpanTraitExt};

    use koji::midi::instruments::{
        GeneralMidiInstrument, instrument_name, instrument_to_program_change,
        program_change_to_instrument, next_instrument_in_group
    };
    use koji::midi::time::round_to_nearest_nth;
    use koji::midi::modes::{mode_steps};
    use koji::midi::core::{MidiTrait};
    use koji::midi::pitch::{PitchClassTrait, keynum_to_pc};
    use koji::midi::modes::{major_steps};

    #[test]
    #[available_gas(10000000)]
    fn extract_notes_test() {
        let mut eventlist = ArrayTrait::<Message>::new();

        let newtempo = SetTempo { tempo: 0, time: Option::Some(FP32x32 { mag: 0, sign: false }) };

        let newnoteon1 = NoteOn {
            channel: 0, note: 60, velocity: 100, time: FP32x32 { mag: 0, sign: false }
        };

        let newnoteon2 = NoteOn {
            channel: 0, note: 21, velocity: 100, time: FP32x32 { mag: 1000, sign: false }
        };

        let newnoteon3 = NoteOn {
            channel: 0, note: 90, velocity: 100, time: FP32x32 { mag: 1500, sign: false }
        };

        let newnoteoff1 = NoteOff {
            channel: 0, note: 60, velocity: 100, time: FP32x32 { mag: 2000, sign: false }
        };

        let newnoteoff2 = NoteOff {
            channel: 0, note: 21, velocity: 100, time: FP32x32 { mag: 1500, sign: false }
        };

        let newnoteoff3 = NoteOff {
            channel: 0, note: 90, velocity: 100, time: FP32x32 { mag: 5000, sign: false }
        };

        let notemessageon1 = Message::NOTE_ON((newnoteon1));
        let notemessageon2 = Message::NOTE_ON((newnoteon2));
        let notemessageon3 = Message::NOTE_ON((newnoteon3));

        let notemessageoff1 = Message::NOTE_OFF((newnoteoff1));
        let notemessageoff2 = Message::NOTE_OFF((newnoteoff2));
        let notemessageoff3 = Message::NOTE_OFF((newnoteoff3));

        let tempomessage = Message::SET_TEMPO((newtempo));

        eventlist.append(tempomessage);

        eventlist.append(notemessageon1);
        eventlist.append(notemessageon2);
        eventlist.append(notemessageon3);

        eventlist.append(notemessageoff1);
        eventlist.append(notemessageoff2);
        eventlist.append(notemessageoff3);

        let midiobj = Midi { events: eventlist.span() };

        let midiobjnotesup = midiobj.extract_notes(20);

        // Assert the correctness of the modified Midi object

        // test to ensure correct positive note transpositions

        let mut ev = midiobjnotesup.clone().events;
        loop {
            match ev.pop_front() {
                Option::Some(currentevent) => {
                    match currentevent {
                        Message::NOTE_ON(NoteOn) => {
                            //find test notes and assert that notes are within range 
                            assert(*NoteOn.note <= 80, 'result > 80');
                            assert(*NoteOn.note >= 40, 'result < 40');
                        },
                        Message::NOTE_OFF(NoteOff) => {
                            //find test notes and assert that notes are within range 
                            assert(*NoteOff.note <= 80, 'result > 80');
                            assert(*NoteOff.note >= 40, 'result < 40');
                        },
                        Message::SET_TEMPO(_SetTempo) => { assert(1 == 2, 'MIDI has Tempo MSG'); },
                        Message::TIME_SIGNATURE(_TimeSignature) => {
                            assert(1 == 2, 'MIDI has TimeSig MSG');
                        },
                        Message::CONTROL_CHANGE(_ControlChange) => {
                            assert(1 == 2, 'MIDI has CC MSG');
                        },
                        Message::PITCH_WHEEL(_PitchWheel) => {
                            assert(1 == 2, 'MIDI has PitchWheel MSG');
                        },
                        Message::AFTER_TOUCH(_AfterTouch) => {
                            assert(1 == 2, 'MIDI has AfterTouch MSG');
                        },
                        Message::POLY_TOUCH(_PolyTouch) => {
                            assert(1 == 2, 'MIDI has PolyTouch MSG');
                        },
                        Message::PROGRAM_CHANGE(_ProgramChange) => {
                            assert(1 == 2, 'MIDI has PolyTouch MSG');
                        },
                        Message::SYSTEM_EXCLUSIVE(_SystemExclusive) => {
                            assert(1 == 2, 'MIDI has PolyTouch MSG');
                        },
                    }
                },
                Option::None(_) => { break; }
            };
        };
    }

    #[test]
    #[available_gas(100000000000)]
    fn quantize_notes_test() {
        let mut eventlist = ArrayTrait::<Message>::new();

        let newtempo = SetTempo { tempo: 0, time: Option::Some(FP32x32 { mag: 0, sign: false }) };

        let newnoteon1 = NoteOn {
            channel: 0, note: 60, velocity: 100, time: FP32x32 { mag: 1, sign: false }
        };

        let newnoteon2 = NoteOn {
            channel: 0, note: 71, velocity: 100, time: FP32x32 { mag: 1001, sign: false }
        };

        let newnoteon3 = NoteOn {
            channel: 0, note: 90, velocity: 100, time: FP32x32 { mag: 1500, sign: false }
        };

        let newnoteoff1 = NoteOff {
            channel: 0, note: 60, velocity: 100, time: FP32x32 { mag: 2000, sign: false }
        };

        let newnoteoff2 = NoteOff {
            channel: 0, note: 71, velocity: 100, time: FP32x32 { mag: 1500, sign: false }
        };

        let newnoteoff3 = NoteOff {
            channel: 0, note: 90, velocity: 100, time: FP32x32 { mag: 5000, sign: false }
        };

        let notemessageon1 = Message::NOTE_ON((newnoteon1));
        let notemessageon2 = Message::NOTE_ON((newnoteon2));
        let notemessageon3 = Message::NOTE_ON((newnoteon3));

        let notemessageoff1 = Message::NOTE_OFF((newnoteoff1));
        let notemessageoff2 = Message::NOTE_OFF((newnoteoff2));
        let notemessageoff3 = Message::NOTE_OFF((newnoteoff3));

        let tempomessage = Message::SET_TEMPO((newtempo));

        eventlist.append(tempomessage);

        eventlist.append(notemessageon1);
        eventlist.append(notemessageon2);
        eventlist.append(notemessageon3);

        eventlist.append(notemessageoff1);
        eventlist.append(notemessageoff2);
        eventlist.append(notemessageoff3);

        let midiobj = Midi { events: eventlist.span() };

        let midiobjnotesup = midiobj.quantize_notes(1000);

        // Assert the correctness of the modified Midi object

        // test to ensure correct positive time quanitzations

        let mut ev = midiobjnotesup.clone().events;
        loop {
            match ev.pop_front() {
                Option::Some(currentevent) => {
                    match currentevent {
                        Message::NOTE_ON(NoteOn) => {
                            //find test notes and assert that times are unchanged

                            if *NoteOn.note == 60 {
                                assert(
                                    *NoteOn.time.mag.try_into().unwrap() == 0,
                                    '1 should quantize to 0'
                                );
                                let num = *NoteOn.time.mag.try_into().unwrap();
                                'num'.print();
                                num.print();
                            } else if *NoteOn.note == 71 {
                                let num2 = *NoteOn.time.mag.try_into().unwrap();
                                assert(num2 == 1000, '1001 should quantize to 1000');

                                'num2'.print();
                                num2.print();
                            } else if *NoteOn.note == 90 {
                                let num3 = *NoteOn.time.mag.try_into().unwrap();
                                assert(num3 == 2000, '1500 should quantize to 2000');

                                'num3'.print();
                                num3.print();
                            } else {}
                        },
                        Message::NOTE_OFF(_NoteOff) => {},
                        Message::SET_TEMPO(_SetTempo) => {},
                        Message::TIME_SIGNATURE(_TimeSignature) => {},
                        Message::CONTROL_CHANGE(_ControlChange) => {},
                        Message::PITCH_WHEEL(_PitchWheel) => {},
                        Message::AFTER_TOUCH(_AfterTouch) => {},
                        Message::POLY_TOUCH(_PolyTouch) => {},
                        Message::PROGRAM_CHANGE(_ProgramChange) => {},
                        Message::SYSTEM_EXCLUSIVE(_SystemExclusive) => {},
                    }
                },
                Option::None(_) => { break; }
            };
        };
    }

    #[test]
    #[available_gas(100000000000)]
    fn change_tempo_test() {
        let mut eventlist = ArrayTrait::<Message>::new();

        let newnoteon1 = NoteOn {
            channel: 0, note: 60, velocity: 100, time: FP32x32 { mag: 0, sign: false }
        };

        let newnoteon2 = NoteOn {
            channel: 0, note: 71, velocity: 100, time: FP32x32 { mag: 1000, sign: false }
        };

        let newnoteon3 = NoteOn {
            channel: 0, note: 90, velocity: 100, time: FP32x32 { mag: 1500, sign: false }
        };

        let newnoteoff1 = NoteOff {
            channel: 0, note: 60, velocity: 100, time: FP32x32 { mag: 2000, sign: false }
        };

        let newnoteoff2 = NoteOff {
            channel: 0, note: 71, velocity: 100, time: FP32x32 { mag: 1500, sign: false }
        };

        let newnoteoff3 = NoteOff {
            channel: 0, note: 90, velocity: 100, time: FP32x32 { mag: 5000, sign: false }
        };

        let notemessageon1 = Message::NOTE_ON((newnoteon1));
        let notemessageon2 = Message::NOTE_ON((newnoteon2));
        let notemessageon3 = Message::NOTE_ON((newnoteon3));

        let notemessageoff1 = Message::NOTE_OFF((newnoteoff1));
        let notemessageoff2 = Message::NOTE_OFF((newnoteoff2));
        let notemessageoff3 = Message::NOTE_OFF((newnoteoff3));

        //Set Tempo

        let tempo = SetTempo { tempo: 121, time: Option::Some(FP32x32 { mag: 1500, sign: false }) };
        let tempomessage = Message::SET_TEMPO((tempo));

        eventlist.append(tempomessage);

        eventlist.append(notemessageon1);
        eventlist.append(notemessageon2);
        eventlist.append(notemessageon3);

        eventlist.append(notemessageoff1);
        eventlist.append(notemessageoff2);
        eventlist.append(notemessageoff3);

        let midiobj = Midi { events: eventlist.span() };

        let midiobjnotes = midiobj.change_tempo(120);

        // Assert the correctness of the modified Midi object

        // test to ensure correct positive note transpositions

        let mut ev = midiobjnotes.clone().events;
        loop {
            match ev.pop_front() {
                Option::Some(currentevent) => {
                    match currentevent {
                        Message::NOTE_ON(_NoteOn) => {},
                        Message::NOTE_OFF(_NoteOff) => {},
                        Message::SET_TEMPO(SetTempo) => {
                            assert(*SetTempo.tempo == 120, 'Tempo should be 120');
                        },
                        Message::TIME_SIGNATURE(_TimeSignature) => {},
                        Message::CONTROL_CHANGE(_ControlChange) => {},
                        Message::PITCH_WHEEL(_PitchWheel) => {},
                        Message::AFTER_TOUCH(_AfterTouch) => {},
                        Message::POLY_TOUCH(_PolyTouch) => {},
                        Message::PROGRAM_CHANGE(_ProgramChange) => {},
                        Message::SYSTEM_EXCLUSIVE(_SystemExclusive) => {},
                    }
                },
                Option::None(_) => { break; }
            };
        };
    }

    #[test]
    #[available_gas(10000000)]
    fn reverse_notes_test() {
        let mut eventlist = ArrayTrait::<Message>::new();

        let newtempo = SetTempo { tempo: 0, time: Option::Some(FP32x32 { mag: 0, sign: false }) };

        let newnoteon1 = NoteOn {
            channel: 0, note: 60, velocity: 100, time: FP32x32 { mag: 0, sign: false }
        };

        let newnoteon2 = NoteOn {
            channel: 0, note: 21, velocity: 100, time: FP32x32 { mag: 1000, sign: false }
        };

        let newnoteon3 = NoteOn {
            channel: 0, note: 90, velocity: 100, time: FP32x32 { mag: 1500, sign: false }
        };

        let newnoteoff1 = NoteOff {
            channel: 0, note: 60, velocity: 100, time: FP32x32 { mag: 2000, sign: false }
        };

        let newnoteoff2 = NoteOff {
            channel: 0, note: 21, velocity: 100, time: FP32x32 { mag: 1500, sign: false }
        };

        let newnoteoff3 = NoteOff {
            channel: 0, note: 90, velocity: 100, time: FP32x32 { mag: 5000, sign: false }
        };

        let notemessageon1 = Message::NOTE_ON((newnoteon1));
        let notemessageon2 = Message::NOTE_ON((newnoteon2));
        let notemessageon3 = Message::NOTE_ON((newnoteon3));

        let notemessageoff1 = Message::NOTE_OFF((newnoteoff1));
        let notemessageoff2 = Message::NOTE_OFF((newnoteoff2));
        let notemessageoff3 = Message::NOTE_OFF((newnoteoff3));

        let tempomessage = Message::SET_TEMPO((newtempo));

        eventlist.append(tempomessage);

        eventlist.append(notemessageon1);
        eventlist.append(notemessageon2);
        eventlist.append(notemessageon3);

        eventlist.append(notemessageoff1);
        eventlist.append(notemessageoff2);
        eventlist.append(notemessageoff3);

        let midiobj = Midi { events: eventlist.span() };
        let midiobjnotes = midiobj.reverse_notes();
        let mut ev = midiobjnotes.clone().events;

        loop {
            match ev.pop_front() {
                Option::Some(currentevent) => {
                    match currentevent {
                        Message::NOTE_ON(NoteOn) => {
                            //find test notes and assert that times are unchanged

                            if *NoteOn.note == 60 {
                                let ptest = *NoteOn.time.mag.try_into().unwrap();
                                'reverse note time'.print();
                                ptest.print();
                            //  assert(*NoteOn.time.mag == 0, 'result should be 0');
                            } else if *NoteOn
                                .note == 71 { //   assert(*NoteOn.time.mag == 1000, 'result should be 1000');
                            } else if *NoteOn
                                .note == 90 { //   assert(*NoteOn.time.mag == 1500, 'result should be 1500');
                            } else {}
                        },
                        Message::NOTE_OFF(NoteOff) => {
                            if *NoteOff
                                .note == 60 { //    assert(*NoteOff.time.mag == 0, 'result should be 6000');
                            } else if *NoteOff.note == 71 { // 'ptest'.print();
                            // let ptest = *NoteOff.velocity.try_into().unwrap();
                            // ptest.print();
                            // 'ptest'.print();
                            //   assert(*NoteOff.time.mag == 4500, 'result should be 4500');
                            } else if *NoteOff
                                .note == 90 { //    assert(*NoteOff.time.mag == 15000, 'result should be 15000');
                            } else {}
                        // let notemessage = Message::NOTE_OFF((newnote));
                        // eventlist.append(notemessage);
                        },
                        Message::SET_TEMPO(_SetTempo) => {},
                        Message::TIME_SIGNATURE(_TimeSignature) => {},
                        Message::CONTROL_CHANGE(_ControlChange) => {},
                        Message::PITCH_WHEEL(_PitchWheel) => {},
                        Message::AFTER_TOUCH(_AfterTouch) => {},
                        Message::POLY_TOUCH(_PolyTouch) => {},
                        Message::PROGRAM_CHANGE(_ProgramChange) => {},
                        Message::SYSTEM_EXCLUSIVE(_SystemExclusive) => {},
                    }
                },
                Option::None(_) => { break; }
            };
        };
    }


    #[test]
    #[available_gas(100000000000)]
    fn remamp_instruments_test() {
        let mut eventlist = ArrayTrait::<Message>::new();

        let newnoteon1 = NoteOn {
            channel: 0, note: 60, velocity: 100, time: FP32x32 { mag: 0, sign: false }
        };

        let newnoteon2 = NoteOn {
            channel: 0, note: 71, velocity: 100, time: FP32x32 { mag: 1000, sign: false }
        };

        let newnoteon3 = NoteOn {
            channel: 0, note: 90, velocity: 100, time: FP32x32 { mag: 1500, sign: false }
        };

        let newnoteoff1 = NoteOff {
            channel: 0, note: 60, velocity: 100, time: FP32x32 { mag: 2000, sign: false }
        };

        let newnoteoff2 = NoteOff {
            channel: 0, note: 71, velocity: 100, time: FP32x32 { mag: 1500, sign: false }
        };

        let newnoteoff3 = NoteOff {
            channel: 0, note: 90, velocity: 100, time: FP32x32 { mag: 5000, sign: false }
        };

        let notemessageon1 = Message::NOTE_ON((newnoteon1));
        let notemessageon2 = Message::NOTE_ON((newnoteon2));
        let notemessageon3 = Message::NOTE_ON((newnoteon3));

        let notemessageoff1 = Message::NOTE_OFF((newnoteoff1));
        let notemessageoff2 = Message::NOTE_OFF((newnoteoff2));
        let notemessageoff3 = Message::NOTE_OFF((newnoteoff3));

        // Set Instrument

        let outpc = ProgramChange {
            channel: 0, program: 7, time: FP32x32 { mag: 6000, sign: false }
        };

        let outpc2 = ProgramChange {
            channel: 0, program: 1, time: FP32x32 { mag: 6100, sign: false }
        };

        let outpc3 = ProgramChange {
            channel: 0, program: 8, time: FP32x32 { mag: 6200, sign: false }
        };
        let outpc4 = ProgramChange {
            channel: 0, program: 126, time: FP32x32 { mag: 6300, sign: false }
        };
        let outpc5 = ProgramChange {
            channel: 0, program: 126, time: FP32x32 { mag: 6300, sign: false }
        };

        let pcmessage = Message::PROGRAM_CHANGE((outpc));
        let pcmessage2 = Message::PROGRAM_CHANGE((outpc2));
        let pcmessage3 = Message::PROGRAM_CHANGE((outpc3));
        let pcmessage4 = Message::PROGRAM_CHANGE((outpc4));
        let pcmessage5 = Message::PROGRAM_CHANGE((outpc5));

        //Set Tempo

        let tempo = SetTempo { tempo: 121, time: Option::Some(FP32x32 { mag: 1500, sign: false }) };
        let tempomessage = Message::SET_TEMPO((tempo));

        eventlist.append(tempomessage);

        eventlist.append(notemessageon1);
        eventlist.append(notemessageon2);
        eventlist.append(notemessageon3);

        eventlist.append(notemessageoff1);
        eventlist.append(notemessageoff2);
        eventlist.append(notemessageoff3);

        eventlist.append(pcmessage);
        eventlist.append(pcmessage2);
        eventlist.append(pcmessage3);
        eventlist.append(pcmessage4);
        eventlist.append(pcmessage5);

        let midiobj = Midi { events: eventlist.span() };

        let midiobjnotes = midiobj.remap_instruments(2);

        // Assert the correctness of the modified Midi object

        // test to ensure correct instrument remappings occur for ProgramChange msgs

        let mut ev = midiobjnotes.clone().events;
        loop {
            match ev.pop_front() {
                Option::Some(currentevent) => {
                    match currentevent {
                        Message::NOTE_ON(_NoteOn) => {},
                        Message::NOTE_OFF(_NoteOff) => {},
                        Message::SET_TEMPO(_SetTempo) => {},
                        Message::TIME_SIGNATURE(_TimeSignature) => {},
                        Message::CONTROL_CHANGE(_ControlChange) => {},
                        Message::PITCH_WHEEL(_PitchWheel) => {},
                        Message::AFTER_TOUCH(_AfterTouch) => {},
                        Message::POLY_TOUCH(_PolyTouch) => {},
                        Message::PROGRAM_CHANGE(ProgramChange) => {
                            let pc = *ProgramChange.program;

                            if *ProgramChange.time.mag == 6000 {
                                assert(pc == 0, 'instruments improperly mapped');
                            } else if *ProgramChange.time.mag == 6100 {
                                assert(pc == 2, 'instruments improperly mapped');
                            } else if *ProgramChange.time.mag == 6200 {
                                assert(pc == 9, 'instruments improperly mapped');
                            } else if *ProgramChange.time.mag == 6300 {
                                assert(pc == 127, 'instruments improperly mapped');
                            } else if *ProgramChange.time.mag == 6400 {
                                assert(pc == 0, 'instruments improperly mapped');
                            } else {}
                        },
                        Message::SYSTEM_EXCLUSIVE(_SystemExclusive) => {},
                    }
                },
                Option::None(_) => { break; }
            };
        };
    }

    #[test]
    #[available_gas(100000000000)]
    fn detect_chords_test() {
        let mut eventlist = ArrayTrait::<Message>::new();

        // Create three notes that should form a chord (even closer in time)
        let chord_note1 = NoteOn {
            channel: 0,
            note: 60, // Middle C
            velocity: 100,
            time: FP32x32 { mag: 1000, sign: false }
        };

        let chord_note2 = NoteOn {
            channel: 0,
            note: 64, // E
            velocity: 100,
            time: FP32x32 { mag: 1005, sign: false } // Reduced time difference
        };

        let chord_note3 = NoteOn {
            channel: 0,
            note: 67, // G
            velocity: 100,
            time: FP32x32 { mag: 1010, sign: false } // Reduced time difference
        };

        // Create corresponding note-off events (closer together)
        let chord_note1_off = NoteOff {
            channel: 0,
            note: 60,
            velocity: 100,
            time: FP32x32 { mag: 1200, sign: false }
        };

        let chord_note2_off = NoteOff {
            channel: 0,
            note: 64,
            velocity: 100,
            time: FP32x32 { mag: 1205, sign: false }
        };

        let chord_note3_off = NoteOff {
            channel: 0,
            note: 67,
            velocity: 100,
            time: FP32x32 { mag: 1210, sign: false }
        };

        // Convert notes to messages
        let msg1_on = Message::NOTE_ON((chord_note1));
        let msg2_on = Message::NOTE_ON((chord_note2));
        let msg3_on = Message::NOTE_ON((chord_note3));

        let msg1_off = Message::NOTE_OFF((chord_note1_off));
        let msg2_off = Message::NOTE_OFF((chord_note2_off));
        let msg3_off = Message::NOTE_OFF((chord_note3_off));

        // Add messages to event list in chronological order
        eventlist.append(msg1_on);
        eventlist.append(msg2_on);
        eventlist.append(msg3_on);
        eventlist.append(msg1_off);
        eventlist.append(msg2_off);
        eventlist.append(msg3_off);

        let midiobj = Midi { events: eventlist.span() };

        // Detect chords with a window size of 20 ticks and minimum 3 notes
        let chords = midiobj.detect_chords(20, 3);

        // Debug print the events
        'Number of events:'.print();
        chords.events.len().print();

        // Verify the results
        let mut ev = chords.events;
        let mut chord_count = 0;
        let mut notes_in_chord = 0;

        loop {
            match ev.pop_front() {
                Option::Some(currentevent) => {
                    match currentevent {
                        Message::NOTE_ON(NoteOn) => {
                            // Debug print
                            'Found note:'.print();
                            (*NoteOn.note).print();
                            
                            // Verify the notes are part of our expected chord (C major: 60, 64, 67)
                            assert(
                                *NoteOn.note == 60 || *NoteOn.note == 64 || *NoteOn.note == 67,
                                'Unexpected note in chord'
                            );
                            notes_in_chord += 1;
                        },
                        Message::NOTE_OFF(_NoteOff) => {
                            // Count note-offs to verify we have the right number
                            chord_count += 1;
                        },
                        _ => {},
                    }
                },
                Option::None(_) => { break; }
            };
        };

        // Debug print the counts
        'Notes in chord:'.print();
        notes_in_chord.print();
        'Note-offs found:'.print();
        chord_count.print();

        // Verify we found exactly one chord with three notes
        assert(notes_in_chord == 3, 'Should find exactly 3 notes');
        assert(chord_count == 3, 'Should find exactly 3 note-offs');
    }
}
