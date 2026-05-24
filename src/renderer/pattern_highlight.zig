const std = @import("std");
const oni = @import("oniguruma");
const configpkg = @import("../config.zig");
const terminal = @import("../terminal/main.zig");
const Allocator = std.mem.Allocator;

const max_matches_per_logical_line = 256;
const oni_search_retry_limit = 100_000;

pub const Rule = struct {
    kind: configpkg.Config.PatternHighlightKind,
    regex: oni.Regex,
    fg: ?terminal.color.RGB,
    bg: ?terminal.color.RGB,
    priority: u16,
    order: u16,

    fn deinit(self: *Rule) void {
        self.regex.deinit();
    }
};

pub const Set = struct {
    rules: []Rule,

    pub fn fromConfig(
        alloc: Allocator,
        config: []const configpkg.Config.PatternHighlightRule,
    ) !Set {
        var rules: std.ArrayList(Rule) = .empty;
        defer rules.deinit(alloc);
        errdefer {
            for (rules.items) |*rule| rule.deinit();
        }

        for (config, 0..) |rule, i| {
            if (!rule.enabled) continue;

            var regex = try oni.Regex.init(
                rule.regex,
                .{},
                oni.Encoding.utf8,
                oni.Syntax.default,
                null,
            );
            errdefer regex.deinit();

            try rules.append(alloc, .{
                .kind = rule.kind,
                .regex = regex,
                .fg = if (rule.fg) |fg| fg.toTerminalRGB() else null,
                .bg = if (rule.bg) |bg| bg.toTerminalRGB() else null,
                .priority = rule.priority,
                .order = @intCast(i),
            });
        }

        return .{ .rules = try rules.toOwnedSlice(alloc) };
    }

    pub fn deinit(self: *Set, alloc: Allocator) void {
        for (self.rules) |*rule| rule.deinit();
        alloc.free(self.rules);
    }

    pub fn updateRenderState(
        self: *Set,
        alloc: Allocator,
        state: *terminal.RenderState,
        tag: u8,
    ) !void {
        if (self.rules.len == 0) return;

        const row_data = state.row_data.slice();
        const row_arenas = row_data.items(.arena);
        const row_raw = row_data.items(.raw);
        const row_cells = row_data.items(.cells);
        const row_highlights = row_data.items(.highlights);
        const row_dirties = row_data.items(.dirty);

        var any_dirty = false;
        var start: usize = 0;
        while (start < row_cells.len) {
            var end = start + 1;
            while (end < row_cells.len and row_raw[end - 1].wrap) end += 1;

            var line_text = try LogicalLineText.init(
                alloc,
                row_cells[start..end],
                @intCast(start),
            );
            defer line_text.deinit(alloc);

            var matches: std.ArrayList(Match) = .empty;
            defer matches.deinit(alloc);

            for (self.rules) |*rule| {
                try matchRule(
                    alloc,
                    &matches,
                    rule,
                    &line_text,
                );
            }

            if (matches.items.len == 0) {
                start = end;
                continue;
            }

            std.mem.sort(Match, matches.items, {}, Match.lessThan);

            for (matches.items) |m| {
                const row_index: usize = @intCast(m.row);
                var arena = row_arenas[row_index].promote(alloc);
                defer row_arenas[row_index] = arena.state;
                const row_alloc = arena.allocator();

                try row_highlights[row_index].append(row_alloc, .{
                    .tag = tag,
                    .range = .{ m.start_col, m.end_col },
                    .fg = m.fg,
                    .bg = m.bg,
                });
                row_dirties[row_index] = true;
                any_dirty = true;
            }

            start = end;
        }

        if (any_dirty and state.dirty == .false) state.dirty = .partial;
    }

    fn matchRule(
        alloc: Allocator,
        matches: *std.ArrayList(Match),
        rule: *Rule,
        line: *const LogicalLineText,
    ) !void {
        if (line.text.len == 0) return;

        switch (rule.kind) {
            .line => {
                var region = search(&rule.regex, line.text) catch |err| switch (err) {
                    error.Mismatch,
                    error.RetryLimitInMatchOver,
                    error.RetryLimitInSearchOver,
                    error.MatchStackLimitOver,
                    error.SubexpCallLimitInSearchOver,
                    => return,
                    else => return err,
                };
                defer region.deinit();

                for (line.rows) |row| {
                    if (row.col_count == 0) continue;
                    try matches.append(alloc, .{
                        .row = row.index,
                        .start_col = 0,
                        .end_col = row.col_count - 1,
                        .priority = rule.priority,
                        .order = rule.order,
                        .fg = rule.fg,
                        .bg = rule.bg,
                    });
                }
            },

            .token => {
                var offset: usize = 0;
                var count: usize = 0;
                while (offset < line.text.len and count < max_matches_per_logical_line) {
                    var region = search(&rule.regex, line.text[offset..]) catch |err| switch (err) {
                        error.Mismatch,
                        error.RetryLimitInMatchOver,
                        error.RetryLimitInSearchOver,
                        error.MatchStackLimitOver,
                        error.SubexpCallLimitInSearchOver,
                        => break,
                        else => return err,
                    };
                    defer region.deinit();

                    const match_start = offset + @as(usize, @intCast(region.starts()[0]));
                    const match_end = offset + @as(usize, @intCast(region.ends()[0]));
                    defer offset = if (match_end > match_start) match_end else match_end + 1;

                    try line.appendMatchSpans(alloc, matches, .{
                        .start_byte = match_start,
                        .end_byte = match_end,
                        .priority = rule.priority,
                        .order = rule.order,
                        .fg = rule.fg,
                        .bg = rule.bg,
                    });
                    count += 1;
                }
            },
        }
    }
};

const MatchStyle = struct {
    start_byte: usize,
    end_byte: usize,
    priority: u16,
    order: u16,
    fg: ?terminal.color.RGB,
    bg: ?terminal.color.RGB,
};

const Match = struct {
    row: u32,
    start_col: terminal.size.CellCountInt,
    end_col: terminal.size.CellCountInt,
    priority: u16,
    order: u16,
    fg: ?terminal.color.RGB,
    bg: ?terminal.color.RGB,

    fn lessThan(_: void, a: Match, b: Match) bool {
        if (a.row != b.row) return a.row < b.row;
        if (a.priority != b.priority) return a.priority > b.priority;
        if (a.order != b.order) return a.order < b.order;
        if (a.start_col != b.start_col) return a.start_col < b.start_col;
        return a.end_col < b.end_col;
    }
};

const LogicalLineText = struct {
    const Row = struct {
        index: u32,
        col_count: terminal.size.CellCountInt,
    };

    const Cell = struct {
        row: u32,
        col: terminal.size.CellCountInt,
    };

    text: []const u8,
    byte_to_cell: []Cell,
    rows: []Row,
    first_row: u32,

    fn init(
        alloc: Allocator,
        rows_cells: []const std.MultiArrayList(terminal.RenderState.Cell),
        first_row: u32,
    ) !LogicalLineText {
        var text: std.ArrayList(u8) = .empty;
        errdefer text.deinit(alloc);
        var byte_to_cell: std.ArrayList(Cell) = .empty;
        errdefer byte_to_cell.deinit(alloc);
        var rows: std.ArrayList(Row) = .empty;
        errdefer rows.deinit(alloc);

        for (rows_cells, 0..) |*cells, row_offset| {
            const row_index: u32 = @intCast(first_row + row_offset);
            const slice = cells.slice();
            const raw = slice.items(.raw);
            const graphemes = slice.items(.grapheme);

            try rows.append(alloc, .{
                .index = row_index,
                .col_count = @intCast(raw.len),
            });

            for (0.., raw, graphemes) |x, cell, cell_graphemes| {
                const cp = cell.codepoint();
                if (cp == 0) {
                    if (cell.wide == .spacer_tail) continue;
                    try text.append(alloc, 0);
                    try byte_to_cell.append(alloc, .{
                        .row = row_index,
                        .col = @intCast(x),
                    });
                    continue;
                }

                try appendCodepoint(
                    alloc,
                    &text,
                    &byte_to_cell,
                    .{ .row = row_index, .col = @intCast(x) },
                    cp,
                );
                if (cell.hasGrapheme()) {
                    for (cell_graphemes) |grapheme_cp| {
                        try appendCodepoint(
                            alloc,
                            &text,
                            &byte_to_cell,
                            .{ .row = row_index, .col = @intCast(x) },
                            grapheme_cp,
                        );
                    }
                }
            }
        }

        const last_row = rows.items[rows.items.len - 1];
        try byte_to_cell.append(alloc, .{
            .row = last_row.index,
            .col = last_row.col_count,
        });
        const text_owned = try text.toOwnedSlice(alloc);
        errdefer alloc.free(text_owned);
        const byte_to_cell_owned = try byte_to_cell.toOwnedSlice(alloc);
        errdefer alloc.free(byte_to_cell_owned);
        const rows_owned = try rows.toOwnedSlice(alloc);
        return .{
            .text = text_owned,
            .byte_to_cell = byte_to_cell_owned,
            .rows = rows_owned,
            .first_row = first_row,
        };
    }

    fn deinit(self: *LogicalLineText, alloc: Allocator) void {
        alloc.free(self.text);
        alloc.free(self.byte_to_cell);
        alloc.free(self.rows);
    }

    fn appendMatchSpans(
        self: *const LogicalLineText,
        alloc: Allocator,
        matches: *std.ArrayList(Match),
        style: MatchStyle,
    ) !void {
        if (style.start_byte >= self.byte_to_cell.len) return;
        if (style.end_byte >= self.byte_to_cell.len) return;
        if (style.start_byte >= style.end_byte) return;

        const start = self.byte_to_cell[style.start_byte];
        const end = self.byte_to_cell[style.end_byte];
        if (start.row > end.row) return;

        if (start.row == end.row) {
            if (start.col >= end.col) return;
            try self.appendSpan(alloc, matches, style, start.row, start.col, end.col);
            return;
        }

        try self.appendSpan(
            alloc,
            matches,
            style,
            start.row,
            start.col,
            self.colCount(start.row) orelse return,
        );

        var row = start.row + 1;
        while (row < end.row) : (row += 1) {
            try self.appendSpan(
                alloc,
                matches,
                style,
                row,
                0,
                self.colCount(row) orelse return,
            );
        }

        try self.appendSpan(alloc, matches, style, end.row, 0, end.col);
    }

    fn appendSpan(
        self: *const LogicalLineText,
        alloc: Allocator,
        matches: *std.ArrayList(Match),
        style: MatchStyle,
        row: u32,
        start_col: terminal.size.CellCountInt,
        end_col: terminal.size.CellCountInt,
    ) !void {
        _ = self;
        if (start_col >= end_col) return;
        try matches.append(alloc, .{
            .row = row,
            .start_col = start_col,
            .end_col = end_col - 1,
            .priority = style.priority,
            .order = style.order,
            .fg = style.fg,
            .bg = style.bg,
        });
    }

    fn colCount(
        self: *const LogicalLineText,
        row: u32,
    ) ?terminal.size.CellCountInt {
        if (row < self.first_row) return null;
        const index = row - self.first_row;
        if (index >= self.rows.len) return null;
        return self.rows[index].col_count;
    }
};

fn appendCodepoint(
    alloc: Allocator,
    text: *std.ArrayList(u8),
    byte_to_cell: *std.ArrayList(LogicalLineText.Cell),
    cell: LogicalLineText.Cell,
    cp: u21,
) !void {
    var buf: [4]u8 = undefined;
    const len = try std.unicode.utf8Encode(cp, &buf);
    try text.appendSlice(alloc, buf[0..len]);
    try byte_to_cell.appendNTimes(alloc, cell, len);
}

fn search(regex: *oni.Regex, bytes: []const u8) !oni.Region {
    var match_param = try oni.MatchParam.init();
    defer match_param.deinit();
    try match_param.setRetryLimitInSearch(oni_search_retry_limit);

    return regex.searchWithParam(
        bytes,
        .{},
        &match_param,
    );
}

test "pattern highlights token and wide cell columns" {
    const testing = std.testing;
    const alloc = testing.allocator;

    try oni.testing.ensureInit();

    var t: terminal.Terminal = try .init(alloc, .{
        .cols = 10,
        .rows = 2,
    });
    defer t.deinit(alloc);

    var s = t.vtStream();
    defer s.deinit();
    s.nextSlice("中ERR");

    var state: terminal.RenderState = .empty;
    defer state.deinit(alloc);
    try state.update(alloc, &t);

    var set = try Set.fromConfig(alloc, &.{
        .{
            .name = "err",
            .kind = .token,
            .regex = "ERR",
            .fg = .{ .r = 0xff, .g = 0, .b = 0 },
            .priority = 10,
        },
    });
    defer set.deinit(alloc);

    try set.updateRenderState(alloc, &state, 42);

    const highlights = state.row_data.items(.highlights)[0].items;
    try testing.expectEqual(@as(usize, 1), highlights.len);
    try testing.expectEqual(@as(terminal.size.CellCountInt, 2), highlights[0].range[0]);
    try testing.expectEqual(@as(terminal.size.CellCountInt, 4), highlights[0].range[1]);
}

test "pattern highlights priority order" {
    const testing = std.testing;
    const alloc = testing.allocator;

    try oni.testing.ensureInit();

    var t: terminal.Terminal = try .init(alloc, .{
        .cols = 8,
        .rows = 1,
    });
    defer t.deinit(alloc);

    var s = t.vtStream();
    defer s.deinit();
    s.nextSlice("ERROR");

    var state: terminal.RenderState = .empty;
    defer state.deinit(alloc);
    try state.update(alloc, &t);

    var set = try Set.fromConfig(alloc, &.{
        .{
            .name = "low",
            .kind = .token,
            .regex = "ERR",
            .priority = 1,
        },
        .{
            .name = "high",
            .kind = .line,
            .regex = "ERROR",
            .priority = 90,
        },
    });
    defer set.deinit(alloc);

    try set.updateRenderState(alloc, &state, 42);

    const highlights = state.row_data.items(.highlights)[0].items;
    try testing.expectEqual(@as(usize, 2), highlights.len);
    try testing.expectEqual(@as(terminal.size.CellCountInt, 0), highlights[0].range[0]);
    try testing.expectEqual(@as(terminal.size.CellCountInt, 7), highlights[0].range[1]);
}

test "pattern highlights token across soft-wrapped rows" {
    const testing = std.testing;
    const alloc = testing.allocator;

    try oni.testing.ensureInit();

    var t: terminal.Terminal = try .init(alloc, .{
        .cols = 20,
        .rows = 4,
    });
    defer t.deinit(alloc);

    var s = t.vtStream();
    defer s.deinit();
    s.nextSlice("sha256=0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef");

    var state: terminal.RenderState = .empty;
    defer state.deinit(alloc);
    try state.update(alloc, &t);

    var set = try Set.fromConfig(alloc, &.{
        .{
            .name = "hash",
            .kind = .token,
            .regex = "\\b[A-Fa-f0-9]{64}\\b",
            .priority = 10,
        },
    });
    defer set.deinit(alloc);

    try set.updateRenderState(alloc, &state, 42);

    const row_highlights = state.row_data.items(.highlights);
    try testing.expectEqual(@as(usize, 1), row_highlights[0].items.len);
    try testing.expectEqual(@as(usize, 1), row_highlights[1].items.len);
    try testing.expectEqual(@as(usize, 1), row_highlights[2].items.len);
    try testing.expectEqual(@as(usize, 1), row_highlights[3].items.len);

    try testing.expectEqual(@as(terminal.size.CellCountInt, 7), row_highlights[0].items[0].range[0]);
    try testing.expectEqual(@as(terminal.size.CellCountInt, 19), row_highlights[0].items[0].range[1]);
    try testing.expectEqual(@as(terminal.size.CellCountInt, 0), row_highlights[1].items[0].range[0]);
    try testing.expectEqual(@as(terminal.size.CellCountInt, 19), row_highlights[1].items[0].range[1]);
    try testing.expectEqual(@as(terminal.size.CellCountInt, 0), row_highlights[2].items[0].range[0]);
    try testing.expectEqual(@as(terminal.size.CellCountInt, 19), row_highlights[2].items[0].range[1]);
    try testing.expectEqual(@as(terminal.size.CellCountInt, 0), row_highlights[3].items[0].range[0]);
    try testing.expectEqual(@as(terminal.size.CellCountInt, 10), row_highlights[3].items[0].range[1]);
}
