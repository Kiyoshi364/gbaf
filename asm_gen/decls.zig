pub fn from_int(input: Bits) Self {
    var best_match = @as(?Self, null);
    var best_score = @as(u8, 0);
    inline for (selfInfo.fields) |ufield| {
        var valid = true;
        var curr_score = @as(u8, 0);
        var match: ufield.field_type = undefined;
        const offtable = @field(ufield.field_type, "offtable");
        inline for (offtable) |entry| {
            const shift = bitsize - entry.offset - entry.size;
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

pub fn to_int(self: Self) Bits {
    const debug = std.debug.print;

    const self_tag_name = @tagName(@as(selfInfo.tag_type.?, self));
    const tag_info = inline for ( selfInfo.fields ) |ufield| {
        if ( strEq(ufield.name, self_tag_name) ) {
            debug("\n{s} . {s}\n", .{ ufield.name, self_tag_name });
            break .{ .typ = ufield.field_type, .name = ufield.name, };
        }
    } else @panic("unreachable");
    var builder = UintBuilder(bitsize){};
    @setEvalBranchQuota(1500);
    inline for (@field(tag_info.typ, "offtable")) |entry| {
        const s = entry.size;
        switch (entry.isFixed) {
            .fixed => |value|
                builder = builder.append(s, value),
            .nil => {
                debug("{s}: {}\n", .{ tag_info.name, self });
                builder = builder.append(s,
                    @field(@field(self, tag_info.name),
                        entry.name))
                    ;
            },
        }
    }
    return builder.done();
}
