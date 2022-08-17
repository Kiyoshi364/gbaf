pub fn from_int(input: Bits) Self {
    var best_match = @as(?Self, null);
    var best_score = @as(u8, 0);
    inline for (selfInfo.fields) |ufield| {
        var valid = true;
        var curr_score = @as(u8, 0);
        var match: ufield.field_type = undefined;
        const offtable = @field(ufield.field_type, "offtable");
        inline for (offtable) |entry| {
            const shift =
                @as(BitRot, bitsize - 1)
                - entry.offset + 1 - entry.size;
            const mask = ((1 << entry.size) - 1);
            const input_value = (input >> shift) & mask;
            switch (entry.isFixed) {
                .fixed => |value| {
                    if ( input_value == value ) {
                        curr_score += entry.size;
                    } else {
                        valid = false;
                    }
                },
                .nil => {
                    const Sfield = @TypeOf(@field(match, entry.name));
                    const int = @typeInfo(Sfield).Int;
                    assert( int.signedness == .unsigned );
                    assert( int.bits == entry.size );
                    assert( input_value ==
                        @truncate(Sfield, input_value) );
                    @field(match, entry.name) =
                        @truncate(Sfield, input_value);
                },
            }
        }
        if ( valid and curr_score >= best_score ) {
            assert( curr_score != best_score );
            best_match = @unionInit(Self, ufield.name, match);
            best_score = curr_score;
        }
    }
    return best_match.?;
}
