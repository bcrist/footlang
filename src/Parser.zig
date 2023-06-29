const std = @import("std");
const console = @import("console");
const Token = @import("Token.zig");
const Error = @import("Error.zig");
const Source = @import("Source.zig");
const Ast = @import("Ast.zig");
const Compiler = @import("Compiler");

const Parser = @This();

gpa: std.mem.Allocator,
temp_arena: std.mem.Allocator,
errors: std.ArrayListUnmanaged(Error) = .{},

source_handle: Source.Handle = 0,
token_kinds: []Token.Kind = &.{},
next_token: Token.Handle = 0,

ast: std.ArrayListUnmanaged(Ast) = .{},
module: ?Ast.Handle = null,

expression_memos: std.AutoHashMapUnmanaged(ExpressionMemoKey, AstMemo) = .{},
expression_list_memos: std.AutoHashMapUnmanaged(Token.Handle, AstMemo) = .{},
field_init_list_memos: std.AutoHashMapUnmanaged(Token.Handle, AstMemo) = .{},
decl_list_memos: std.AutoHashMapUnmanaged(Token.Handle, AstMemo) = .{},

const ExpressionMemoKey = struct {
    token_handle: Token.Handle,
    options: ExpressionOptions,
};

const AstMemo = struct {
    ast_handle: ?Ast.Handle,
    next_token: Token.Handle,
};

const SyncError = error{Sync};

pub fn init(gpa: std.mem.Allocator, temp_arena: std.mem.Allocator) Parser {
    return .{
        .gpa = gpa,
        .temp_arena = temp_arena,
    };
}

pub fn deinit(self: *Parser) void {
    self.decl_list_memos.deinit(self.gpa);
    self.field_init_list_memos.deinit(self.gpa);
    self.expression_list_memos.deinit(self.gpa);
    self.expression_memos.deinit(self.gpa);
    self.ast.deinit(self.gpa);
    self.errors.deinit(self.gpa);
}

pub fn parse(self: *Parser, source_handle: Source.Handle, token_kinds: []Token.Kind) void {
    self.errors.clearRetainingCapacity();
    self.ast.clearRetainingCapacity();
    self.module = null;
    self.expression_memos.clearRetainingCapacity();
    self.expression_list_memos.clearRetainingCapacity();
    self.field_init_list_memos.clearRetainingCapacity();
    self.decl_list_memos.clearRetainingCapacity();
    self.source_handle = source_handle;
    self.token_kinds = token_kinds;
    self.next_token = 0;

    while (!self.tryToken(.eof)) {
        const decl_start_token = self.next_token;
        const maybe_decl = self.tryDeclaration() catch {
            self.syncPastToken(.newline);
            continue;
        };
        if (maybe_decl) |decl_handle| {
            if (!self.tryNewline()) {
                self.recordErrorAbs("Failed to parse declaration", self.ast.items[decl_handle].token_handle, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
                self.recordError("Expected end of line", .{});
                self.syncPastToken(.newline);
                continue;
            }

            if (self.module) |prev| {
                self.module = self.addBinary(.list, decl_start_token, prev, decl_handle);
            } else {
                self.module = decl_handle;
            }
        } else if (self.tryNewline()) {
            continue;
        } else {
            self.skipLinespace();
            const first = self.next_token;
            self.syncPastToken(.newline);
            var last = self.backtrackToken(self.next_token, .{});
            if (first + 50 < last) {
                self.recordErrorAbs("Expected a declaration", first, Error.FlagSet.initOne(.has_continuation));
                self.recordErrorAbs("End of declaration/assignment/expression", last, Error.FlagSet.initOne(.supplemental));
            } else {
                self.recordErrorAbsRange("Expected a declaration", .{
                    .first = first,
                    .last = last,
                }, .{});
            }
        }
    }
}

fn tryDeclaration(self: *Parser) SyncError!?Ast.Handle {
    const start_token = self.next_token;

    self.skipLinespace();
    const token_handle = self.tryIdentifier() orelse self.trySymbol() orelse {
        self.next_token = start_token;
        return null;
    };

    self.skipLinespace();
    if (!self.tryToken(.colon)) {
        self.next_token = start_token;
        return null;
    }

    var ast_kind: Ast.Kind = undefined;
    var type_expr_handle: Ast.Handle = undefined;
    var init_expr_handle: Ast.Handle = undefined;

    var has_init = false;

    self.skipLinespace();
    if (token_handle > 0 and self.token_kinds[token_handle - 1] == .dot) {
        ast_kind = .field_declaration;
        if (try self.tryExpression(.{})) |type_expr| {
            type_expr_handle = type_expr;
        } else {
            self.recordErrorAbs("Failed to parse field declaration", token_handle, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
            self.recordError("Expected type expression", .{});
            return error.Sync;
        }

        self.skipLinespace();
        if (self.tryToken(.eql)) {
            has_init = true;
        }
    } else if (self.tryToken(.colon)) {
        type_expr_handle = self.addTerminal(.inferred_type, self.next_token - 1);
        ast_kind = .constant_declaration;
        has_init = true;
    } else if (self.tryToken(.eql)) {
        type_expr_handle = self.addTerminal(.inferred_type, self.next_token - 1);
        ast_kind = .variable_declaration;
        has_init = true;
    } else {
        if (try self.tryExpression(.{ .allow_calls = false })) |type_expr| {
            type_expr_handle = type_expr;
        } else if (self.tryToken(.kw_mut)) {
            type_expr_handle = self.addTerminal(.mut_inferred_type, self.next_token - 1);
        } else {
            self.recordErrorAbs("Failed to parse declaration", token_handle, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
            self.recordError("Expected type expression or ':' or '=' followed by initializer expression", .{});
            return error.Sync;
        }

        self.skipLinespace();
        if (self.tryToken(.colon)) {
            ast_kind = .constant_declaration;
            has_init = true;
        } else if (self.tryToken(.eql)) {
            ast_kind = .variable_declaration;
            has_init = true;
        } else {
            ast_kind = .variable_declaration;
        }
    }

    if (has_init) {
        self.skipLinespace();
        init_expr_handle = try self.tryExpression(.{}) orelse {
            self.recordErrorAbs("Failed to parse declaration", token_handle, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
            self.recordError("Expected initializer expression", .{});
            return error.Sync;
        };
    } else {
        init_expr_handle = self.addTerminal(.empty, token_handle);
    }

    return self.addBinary(ast_kind, token_handle, type_expr_handle, init_expr_handle);
}

fn tryDeclarationList(self: *Parser) SyncError!?Ast.Handle {
    self.skipLinespace();
    const token_handle = self.next_token;
    if (self.decl_list_memos.get(token_handle)) |memo| {
        self.next_token = memo.next_token;
        return memo.ast_handle;
    }
    var maybe_list: ?Ast.Handle = null;

    while (true) {
        const start_of_decl = self.next_token;
        const decl = try self.tryDeclaration() orelse break;
        if (maybe_list) |list| {
            maybe_list = self.addBinary(.list, start_of_decl, list, decl);
        } else {
            maybe_list = decl;
        }

        if (self.tryToken(.comma)) {
            self.skipWhitespace();
        } else {
            break;
        }
    }

    self.decl_list_memos.put(self.gpa, token_handle, .{
        .next_token = self.next_token,
        .ast_handle = maybe_list,
    }) catch @panic("OOM");
    return maybe_list;
}

fn fieldInitList(self: *Parser) SyncError!Ast.Handle {
    self.skipWhitespace();
    const token_handle = self.next_token;
    if (self.field_init_list_memos.get(token_handle)) |memo| {
        self.next_token = memo.next_token;
        return memo.ast_handle.?;
    }
    var maybe_list: ?Ast.Handle = null;

    while (true) {
        const item_token_handle = self.next_token;
        const ast_handle = (try self.tryAssignmentOrExpression()) orelse break;
        if (maybe_list) |list| {
            maybe_list = self.addBinary(.list, item_token_handle, list, ast_handle);
        } else {
            maybe_list = ast_handle;
        }

        if (self.tryToken(.comma) or self.tryNewline()) {
            self.skipWhitespace();
        } else {
            break;
        }
    }

    const list = maybe_list orelse self.addTerminal(.empty, token_handle);

    self.field_init_list_memos.put(self.gpa, token_handle, .{
        .next_token = self.next_token,
        .ast_handle = list,
    }) catch @panic("OOM");
    return list;
}

fn expressionList(self: *Parser) SyncError!Ast.Handle {
    self.skipWhitespace();
    const token_handle = self.next_token;
    if (self.expression_list_memos.get(token_handle)) |memo| {
        self.next_token = memo.next_token;
        return memo.ast_handle.?;
    }
    var maybe_list: ?Ast.Handle = null;

    while (true) {
        const item_token_handle = self.next_token;
        const ast_handle = (try self.tryExpression(.{})) orelse break;
        if (maybe_list) |list| {
            maybe_list = self.addBinary(.list, item_token_handle, list, ast_handle);
        } else {
            maybe_list = ast_handle;
        }

        if (self.tryToken(.comma) or self.tryNewline()) {
            self.skipWhitespace();
        } else {
            break;
        }
    }

    const list = maybe_list orelse self.addTerminal(.empty, token_handle);

    self.expression_list_memos.put(self.gpa, token_handle, .{
        .next_token = self.next_token,
        .ast_handle = list,
    }) catch @panic("OOM");
    return list;
}

fn tryStatement(self: *Parser) SyncError!?Ast.Handle {
    const begin_token_handle = self.next_token;
    if (self.tryToken(.kw_defer)) {
        self.skipLinespace();
        if (try self.tryExpression(.{})) |expr_handle| {
            return self.addUnary(.defer_expr, begin_token_handle, expr_handle);
        } else {
            self.recordErrorAbs("Failed to parse defer expression", begin_token_handle, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
            self.recordError("Expected expression", .{});
            return error.Sync;
        }
    } else if (self.tryToken(.kw_errordefer)) {
        self.skipLinespace();
        if (try self.tryExpression(.{})) |expr_handle| {
            return self.addUnary(.errordefer_expr, begin_token_handle, expr_handle);
        } else {
            self.recordErrorAbs("Failed to parse errordefer expression", begin_token_handle, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
            self.recordError("Expected expression", .{});
            return error.Sync;
        }
    } else return self.tryAssignmentOrExpression();
}

fn tryAssignmentOrExpression(self: *Parser) SyncError!?Ast.Handle {
    if (try self.tryExpression(.{})) |lhs_handle| {
        self.skipLinespace();
        const assign_token_handle = self.next_token;
        if (self.tryToken(.eql)) {
            if (try self.tryExpression(.{})) |rhs_handle| {
                return self.addBinary(.assignment, assign_token_handle, lhs_handle, rhs_handle);
            } else {
                self.recordErrorAbs("Failed to parse assignment", assign_token_handle, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
                self.recordError("Expected expression", .{});
                return error.Sync;
            }
        } else return lhs_handle;
    } else return null;
}

const ExpressionOptions = struct {
    allow_calls: bool = true,
};
fn tryExpression(self: *Parser, options: ExpressionOptions) SyncError!?Ast.Handle {
    const key = ExpressionMemoKey{
        .token_handle = self.next_token,
        .options = options,
    };
    if (self.expression_memos.get(key)) |memo| {
        self.next_token = memo.next_token;
        return memo.ast_handle;
    }
    const expr = try self.tryExpressionPratt(0, options);
    self.expression_memos.put(self.gpa, key, .{
        .next_token = self.next_token,
        .ast_handle = expr,
    }) catch @panic("OOM");
    return expr;
}

const OperatorInfo = struct {
    token: Token.Handle,

    // If used, this should be a memoized node to ensure that if the operator is rejected, it won't leak
    other: ?Ast.Handle,

    kind: Ast.Kind,

    // For prefix operators, this should usually be set to 0xFF.
    left_bp: u8,

    // When null, this must be used as a suffix operator, otherwise it can be a binary operator.
    right_bp: ?u8,

    // When both right_bp and alt_when_suffix are non-null, this may be either an infix or a suffix operator.
    // When it functions as a suffix, these override the values from the outer struct:
    alt_when_suffix: ?struct {
        left_bp: u8,
        kind: Ast.Kind,
    },
};
fn tryPrefixOperator(self: *Parser, options: ExpressionOptions) SyncError!?OperatorInfo {
    const begin = self.next_token;
    self.skipLinespace();
    const t = self.next_token;
    const kind = self.token_kinds[t];

    if (kind == .eof) {
        self.next_token = begin;
        return null;
    }

    self.next_token += 1;

    const base_bp: u8 = if (self.tryLinespace()) 0x40 else 0xC0;
    var info = OperatorInfo{
        .token = t,
        .other = null,
        .kind = undefined,
        .left_bp = 0xFF,
        .right_bp = base_bp + 1,
        .alt_when_suffix = null,
    };
    switch (kind) {
        .kw_if => {
            info.right_bp = base_bp - 0x3A;
            info.kind = .if_expr;
            // TODO handle optional unwrapping lists
            info.other = (try self.tryExpression(options)) orelse {
                self.recordErrorAbs("Failed to parse if expression", t, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
                self.recordError("Expected condition expression", .{});
                return error.Sync;
            };
        },
        .kw_while => {
            info.right_bp = base_bp - 0x3A;
            info.kind = .while_expr;
            // TODO handle optional unwrapping lists
            info.other = (try self.tryExpression(options)) orelse {
                self.recordErrorAbs("Failed to parse while expression", t, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
                self.recordError("Expected condition expression", .{});
                return error.Sync;
            };
        },
        .kw_until => {
            info.right_bp = base_bp - 0x3A;
            info.kind = .until_expr;
            info.other = (try self.tryExpression(options)) orelse {
                self.recordErrorAbs("Failed to parse until expression", t, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
                self.recordError("Expected condition expression", .{});
                return error.Sync;
            };
        },
        .kw_repeat => {
            info.right_bp = base_bp - 0x3A;
            if (try self.tryExpression(options)) |loop_expr_handle| {
                self.skipLinespace();
                if (self.tryToken(.kw_while)) {
                    info.other = loop_expr_handle;
                    info.kind = .repeat_while;
                } else if (self.tryToken(.kw_until)) {
                    info.other = loop_expr_handle;
                    info.kind = .repeat_until;
                } else {
                    info.kind = .repeat_infinite;
                    self.next_token = t + 1;
                }
            } else {
                self.recordErrorAbs("Failed to parse repeat expression", t, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
                self.recordError("Expected loop expression", .{});
                return error.Sync;
            }
        },

        .kw_with => {
            info.right_bp = base_bp - 0x3A;
            info.kind = if (self.tryToken(.kw_only)) .with_only else .with_expr;
            while (true) {
                self.skipLinespace();
                const token_handle = self.next_token;
                const decl_handle = (try self.tryDeclaration()) orelse break;
                if (info.other) |list| {
                    info.other = self.addBinary(.list, token_handle, list, decl_handle);
                } else {
                    info.other = decl_handle;
                }

                if (self.tryToken(.comma)) {
                    self.skipWhitespace();
                } else {
                    break;
                }
            }

            if (info.other == null) {
                self.recordErrorAbs("Failed to parse with-scope expression", t, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
                self.recordError("Expected at least one declaration", .{});
                return error.Sync;
            }
        },

        .kw_for => {
            info.right_bp = base_bp - 0x3A;
            // TODO handle @rev
            info.kind = .for_expr;
            while (true) {
                self.skipLinespace();
                const token_handle = self.next_token;
                const decl_handle = (try self.tryDeclaration()) orelse break;
                if (info.other) |list| {
                    info.other = self.addBinary(.list, token_handle, list, decl_handle);
                } else {
                    info.other = decl_handle;
                }

                if (self.tryToken(.comma)) {
                    self.skipWhitespace();
                } else {
                    break;
                }
            }

            if (info.other == null) {
                self.recordErrorAbs("Failed to parse for expression", t, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
                self.recordError("Expected at least one declaration", .{});
                return error.Sync;
            }
        },

        .kw_return   => { info.right_bp = base_bp - 0x38; info.kind = .return_expr; },
        .kw_break    => { info.right_bp = base_bp - 0x38; info.kind = .break_expr; },
        .kw_try      => { info.right_bp = base_bp - 0x30; info.kind = .try_expr; },
        .kw_not      => { info.right_bp = base_bp - 0x05; info.kind = .logical_not; },

        .kw_mut      => { info.kind = .mut_type; },
        .kw_distinct => { info.kind = .distinct_type; },
        .kw_error    => { info.kind = .error_type; },

        .tilde       => { info.right_bp = base_bp + 0x2D; info.kind = .range_expr_infer_start_exclusive_end; },
        .tilde_tilde => { info.right_bp = base_bp + 0x2D; info.kind = .range_expr_infer_start_inclusive_end; },

        .question    => { info.right_bp = base_bp + 0x3D; info.kind = .optional_type; },
        .star        => { info.right_bp = base_bp + 0x3D; info.kind = .make_pointer; },
        .dash        => { info.right_bp = base_bp + 0x3D; info.kind = .negate; },

        .index_open => {
            info.right_bp = base_bp + 0x3D;
            const index_expr = try self.tryExpression(.{});
            info.kind = if (index_expr) |_| .array_type else .slice_type;
            info.other = index_expr;
            self.skipLinespace();
            try self.closeRegion(t, .index_close, "]", "array/slice type prefix");
        },

        else => {
            self.next_token = begin;
            return null;
        },
    }
    return info;
}
fn tryOperator(self: *Parser, options: ExpressionOptions) SyncError!?OperatorInfo {
    const begin = self.next_token;
    const linespace_before = self.tryLinespace();
    const t = self.next_token;
    const kind = self.token_kinds[t];

    if (kind == .eof) {
        self.next_token = begin;
        return null;
    }

    self.next_token += 1;
    const linespace_after = self.tryLinespace();

    const left_base: u8 = if (linespace_before) 0x40 else 0xC0;
    const right_base: u8 = if (linespace_after) 0x40 else 0xC0;
    var info = OperatorInfo{
        .token = t,
        .other = null,
        .kind = undefined,
        .left_bp = left_base,
        .right_bp = right_base + 1,
        .alt_when_suffix = null,
    };

    switch (kind) {
        .octothorpe  => { info.left_bp = left_base - 0x3F; info.right_bp = right_base - 0x3E; info.kind = .apply_tag; },

        .kw_else     => { info.left_bp = left_base - 0x3B; info.right_bp = right_base - 0x3A; info.kind = .coalesce; },
        .kw_catch    => { info.left_bp = left_base - 0x3B; info.right_bp = right_base - 0x3A; info.kind = .catch_expr; },

        .bar         => { info.left_bp = left_base - 0x13; info.right_bp = right_base - 0x12; info.kind = .type_sum_operator; },
        .amp         => { info.left_bp = left_base - 0x11; info.right_bp = right_base - 0x10; info.kind = .type_product_operator; },
        .kw_or       => { info.left_bp = left_base - 0x0A; info.right_bp = right_base - 0x09; info.kind = .logical_or; },
        .kw_and      => { info.left_bp = left_base - 0x08; info.right_bp = right_base - 0x07; info.kind = .logical_and; },
        .eql_eql     => { info.left_bp = left_base - 0x04; info.right_bp = right_base - 0x03; info.kind = .test_equal; },
        .diamond     => { info.left_bp = left_base - 0x04; info.right_bp = right_base - 0x03; info.kind = .test_inequal; },

        .lt          => { info.left_bp = left_base - 0x02; info.right_bp = right_base - 0x01; info.kind = .test_less_than; },
        .gt          => { info.left_bp = left_base - 0x02; info.right_bp = right_base - 0x01; info.kind = .test_greater_than; },
        .lt_eql      => { info.left_bp = left_base - 0x02; info.right_bp = right_base - 0x01; info.kind = .test_less_than_or_equal; },
        .gt_eql      => { info.left_bp = left_base - 0x02; info.right_bp = right_base - 0x01; info.kind = .test_greater_than_or_equal; },
        .spaceship   => { info.left_bp = left_base - 0x02; info.right_bp = right_base - 0x01; info.kind = .compare; },
        .kw_is       => { info.left_bp = left_base - 0x02; info.right_bp = right_base - 0x01; info.kind = .test_active_field; },

        .apostrophe => {
            if (!options.allow_calls) {
                self.next_token = begin;
                return null;
            }

            if (linespace_before == linespace_after) {
                info.kind = .ambiguous_call;
            } else if (linespace_before) {
                info.kind = .suffix_call;
            } else {
                info.kind = .prefix_call;
            }
        },

        .tilde               => { info.left_bp = left_base + 0x20; info.right_bp = right_base + 0x21; info.kind = .range_expr_exclusive_end;
            info.alt_when_suffix = .{ .left_bp = left_base + 0x20,                                        .kind = .range_expr_infer_end };
        },
        .tilde_tilde         => { info.left_bp = left_base + 0x20; info.right_bp = right_base + 0x21; info.kind = .range_expr_inclusive_end;
            info.alt_when_suffix = .{ .left_bp = left_base + 0x20,                                        .kind = .range_expr_infer_end };
        },

        .kw_as     => { info.left_bp = left_base + 0x2E; info.right_bp = right_base + 0x2F; info.kind = .coerce; },
        .kw_in     => { info.left_bp = left_base + 0x31;info.right_bp = right_base + 0x30; info.kind = .apply_dim; },
        .plus_plus => { info.left_bp = left_base + 0x32; info.right_bp = right_base + 0x33; info.kind = .array_concat; },
        .star_star => { info.left_bp = left_base + 0x34; info.right_bp = right_base + 0x35; info.kind = .array_repeat; },
        .plus      => { info.left_bp = left_base + 0x36; info.right_bp = right_base + 0x37; info.kind = .add; },
        .dash      => { info.left_bp = left_base + 0x36; info.right_bp = right_base + 0x37; info.kind = .subtract; },

        .star                => { info.left_bp = left_base + 0x38; info.right_bp = right_base + 0x39; info.kind = .multiply;
            info.alt_when_suffix = .{ .left_bp = left_base + 0x3E,                                        .kind = .unmake_pointer };
        },
        .slash     => { info.left_bp = left_base + 0x38; info.right_bp = right_base + 0x39; info.kind = .divide_exact; },
        .caret     => { info.left_bp = left_base + 0x3B; info.right_bp = right_base + 0x3A; info.kind = .raise_exponent; },
        .dot       => { info.left_bp = left_base + 0x3E; info.right_bp = right_base + 0x3F; info.kind = .member_access; },

        .dot_block_open => {
            info.left_bp = left_base + 0x3E;
            info.right_bp = null;
            info.kind = .typed_struct_literal;
            info.other = try self.fieldInitList();
            try self.closeMultiLineRegion(t, .block_close, "}", "struct literal");
        },
        .dot_paren_open => {
            info.left_bp = left_base + 0x3E;
            info.right_bp = null;
            info.kind = .typed_union_literal;
            info.other = try self.fieldInitList();
            try self.closeMultiLineRegion(t, .paren_close, ")", "union literal");
        },
        .dot_index_open => {
            info.left_bp = left_base + 0x3E;
            info.right_bp = null;
            info.kind = .typed_array_literal;
            info.other = try self.expressionList();
            try self.closeMultiLineRegion(t, .index_close, "]", "array literal");
        },
        .index_open => {
            if (try self.tryExpression(.{})) |index_expr| {
                info.left_bp = left_base + 0x3E;
                info.right_bp = null;
                info.kind = .indexed_access;
                info.other = index_expr;
                self.skipLinespace();
                try self.closeRegion(t, .index_close, "]", "index expression");
            } else {
                const error_token = self.next_token;
                self.syncPastTokenOrLine(.index_close);
                const end_token = self.backtrackToken(self.next_token, .{});

                self.recordErrorAbsRange("Failed to parse index expression", .{
                    .first = t,
                    .last = end_token,
                }, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
                self.recordErrorAbs("Expected expression", error_token, .{});
                return error.Sync;
            }
        },

        else => {
            self.next_token = begin;
            return null;
        },
    }
    return info;
}

fn tryExpressionPratt(self: *Parser, min_binding_power: u8, options: ExpressionOptions) SyncError!?Ast.Handle {
    const before_prefix_operator = self.next_token;

    var expr = if (try self.tryPrefixOperator(options)) |operator| e: {
        if (operator.left_bp >= min_binding_power) {
            if (try self.tryExpressionPratt(operator.right_bp.?, options)) |right| {
                if (operator.other) |left| {
                    break :e self.addBinary(operator.kind, operator.token, left, right);
                } else {
                    break :e self.addUnary(operator.kind, operator.token, right);
                }
            }
        }
        self.next_token = before_prefix_operator;
        return null;
    } else (try self.tryPrimaryExpression()) orelse return null;

    var is_suffix_call = false;
    while (true) {
        const expr_is_suffix_call = is_suffix_call;
        is_suffix_call = false;
        const before_operator = self.next_token;
        if (try self.tryOperator(options)) |operator| {
            if (operator.left_bp >= min_binding_power) {
                if (operator.right_bp) |binding_power| {
                    std.debug.assert(operator.other == null);
                    if (try self.tryExpressionPratt(binding_power, options)) |right| {
                        if (operator.kind == .prefix_call and expr_is_suffix_call) {
                            const suffix_call = self.ast.items[expr].info.suffix_call;
                            var args_expr = self.addBinary(.infix_call_args, operator.token, suffix_call.left, right);

                            self.ast.items[expr].info = .{ .infix_call = .{
                                .left = suffix_call.right,
                                .right = args_expr
                            }};
                            continue;
                        }

                        expr = self.addBinary(operator.kind, operator.token, expr, right);
                        is_suffix_call = operator.kind == .suffix_call;
                        continue;
                    } else if (operator.alt_when_suffix) |alt_operator| {
                        if (alt_operator.left_bp >= min_binding_power and try self.tryExpression(options) == null) {
                            expr = self.addUnary(alt_operator.kind, operator.token, expr);
                            continue;
                        }
                    }
                } else if (operator.other) |right| {
                    expr = self.addBinary(operator.kind, operator.token, expr, right);
                    continue;
                } else {
                    expr = self.addUnary(operator.kind, operator.token, expr);
                    continue;
                }
            } else if (operator.alt_when_suffix) |alt_operator| {
                if (alt_operator.left_bp >= min_binding_power and try self.tryExpression(options) == null) {
                    expr = self.addUnary(alt_operator.kind, operator.token, expr);
                    continue;
                }
            }
        }
        self.next_token = before_operator;
        break;
    }

    return expr;
}

fn tryPrimaryExpression(self: *Parser) SyncError!?Ast.Handle {
    const begin = self.next_token;
    self.skipLinespace();
    const token_handle = self.next_token;
    return switch (self.token_kinds[token_handle]) {
        .id => self.consumeTerminal(.id_ref),
        .paren_open => try self.parenExpression(),
        .string_literal, .line_string_literal => self.stringLiteral(),
        .numeric_literal => self.consumeTerminal(.numeric_literal),
        .dot => if (self.trySymbol()) |symbol_token_handle| self.addTerminal(.symbol, symbol_token_handle) else null,
        .block_open => try self.proceduralBlock(),
        .dot_block_open => {
            self.next_token += 1;
            const list = try self.fieldInitList();
            try self.closeMultiLineRegion(token_handle, .block_close, "}", "struct literal");
            return self.addUnary(.anonymous_struct_literal, token_handle, list);
        },
        .dot_paren_open => {
            self.next_token += 1;
            const list = try self.fieldInitList();
            try self.closeMultiLineRegion(token_handle, .paren_close, ")", "union literal");
            return self.addUnary(.anonymous_union_literal, token_handle, list);
        },
        .dot_index_open => {
            self.next_token += 1;
            const list = try self.expressionList();
            try self.closeMultiLineRegion(token_handle, .index_close, "]", "array literal");
            return self.addUnary(.anonymous_array_literal, token_handle, list);
        },
        .kw_fn => try self.tryFunctionDefinition() orelse try self.tryFunctionType(),
        .kw_struct => try self.structTypeLiteral(),
        .kw_union => try self.unionTypeLiteral(),

        .kw_match => {
            // TODO
            unreachable;
        },

        else => {
            self.next_token = begin;
            return null;
        },
    };
}

fn parenExpression(self: *Parser) SyncError!Ast.Handle {
    const expr_begin = self.next_token;
    std.debug.assert(self.token_kinds[expr_begin] == .paren_open);
    self.next_token += 1;
    self.skipLinespace();
    if (try self.tryExpression(.{})) |expr_handle| {
        self.skipLinespace();
        try self.closeRegion(expr_begin, .paren_close, ")", "parenthesized expression");
        return self.addUnary(.group, expr_begin, expr_handle);
    }

    const error_token = self.next_token;
    self.syncPastTokenOrLine(.paren_close);
    const end_token = self.backtrackToken(self.next_token, .{});

    self.recordErrorAbsRange("Failed to parse parenthesized expression", .{
        .first = expr_begin,
        .last = end_token,
    }, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
    self.recordErrorAbs("Expected expression", error_token, .{});
    return error.Sync;
}

fn proceduralBlock(self: *Parser) SyncError!Ast.Handle {
    const begin_token = self.next_token;
    std.debug.assert(self.token_kinds[begin_token] == .block_open);
    self.next_token += 1;
    self.skipWhitespace();

    var maybe_list: ?Ast.Handle = null;

    while (true) {
        const item_token_handle = self.next_token;
        const ast_handle = (try self.tryDeclaration()) orelse (try self.tryStatement()) orelse break;
        if (maybe_list) |list| {
            maybe_list = self.addBinary(.list, item_token_handle, list, ast_handle);
        } else {
            maybe_list = ast_handle;
        }

        if (self.tryToken(.comma) or self.tryNewline()) {
            self.skipWhitespace();
        } else {
            break;
        }
    }

    try self.closeMultiLineRegion(begin_token, .block_close, "}", "procedural block");
    const list = maybe_list orelse self.addTerminal(.empty, begin_token);
    return self.addUnary(.proc_block, begin_token, list);
}

fn tryFunctionType(self: *Parser) SyncError!?Ast.Handle {
    self.skipLinespace();
    const fn_begin = self.next_token;
    if (!self.tryToken(.kw_fn)) return null;
    self.skipLinespace();

    var maybe_left: ?Ast.Handle = null;
    var maybe_right: ?Ast.Handle = null;

    if (self.tryToken(.apostrophe)) {
        self.skipLinespace();
        if (try self.tryExpression(.{ .allow_calls = false })) |expr_handle| {
            maybe_right = expr_handle;
        } else {
            const error_token = self.next_token;
            self.recordErrorAbsRange("Failed to parse function type", .{
                .first = fn_begin,
                .last = error_token,
            }, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
            self.recordErrorAbs("Expected type expression", error_token, .{});
            return error.Sync;
        }
    } else {
        maybe_left = try self.tryExpression(.{ .allow_calls = false });

        self.skipLinespace();
        if (self.tryToken(.apostrophe)) {
            self.skipLinespace();
            if (try self.tryExpression(.{ .allow_calls = false })) |expr_handle| {
                maybe_right = expr_handle;
            } else {
                const error_token = self.next_token;
                self.recordErrorAbsRange("Failed to parse function type", .{
                    .first = fn_begin,
                    .last = error_token,
                }, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
                self.recordErrorAbs("Expected type expression", error_token, .{});
                return error.Sync;
            }
        }
    }

    var maybe_result: ?Ast.Handle = null;

    self.skipLinespace();
    if (self.tryToken(.thin_arrow)) {
        self.skipLinespace();
        if (try self.tryExpression(.{ .allow_calls = false })) |expr_handle| {
            maybe_result = expr_handle;
        } else {
            const error_token = self.next_token;
            self.recordErrorAbsRange("Failed to parse function type", .{
                .first = fn_begin,
                .last = error_token,
            }, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
            self.recordErrorAbs("Expected type expression", error_token, .{});
            return error.Sync;
        }
    }

    const left = maybe_left orelse self.addTerminal(.inferred_type, fn_begin);
    const right = maybe_right orelse self.addTerminal(.inferred_type, fn_begin);
    const result = maybe_result orelse self.addTerminal(.inferred_type, fn_begin);
    const args = self.addBinary(.fn_sig_args, fn_begin, left, right);
    return self.addBinary(.fn_sig, fn_begin, args, result);
}

fn tryFunctionDefinition(self: *Parser) SyncError!?Ast.Handle {
    const begin = self.next_token;
    self.skipLinespace();
    const fn_begin = self.next_token;
    if (!self.tryToken(.kw_fn)) return null;
    self.skipLinespace();

    const maybe_left = try self.tryDeclarationList();

    var maybe_right: ?Ast.Handle = null;

    self.skipLinespace();
    if (self.tryToken(.apostrophe)) {
        maybe_right = try self.tryDeclarationList();
    }

    var maybe_result: ?Ast.Handle = null;
    var body: Ast.Handle = undefined;

    self.skipLinespace();
    if (self.tryToken(.thick_arrow)) {
        self.skipLinespace();
        if (try self.tryExpression(.{})) |expr_handle| {
            body = expr_handle;
        } else if (maybe_left != null or maybe_right != null) {
            const error_token = self.next_token;
            self.recordErrorAbsRange("Failed to parse function definition", .{
                .first = fn_begin,
                .last = error_token,
            }, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
            self.recordErrorAbs("Expected body expression", error_token, .{});
            return error.Sync;
        } else {
            self.next_token = begin;
            return null;
        }
    } else {
        var after_arrow = self.next_token;
        if (self.tryToken(.thin_arrow)) {
            self.skipLinespace();
            after_arrow = self.next_token;
            if (try self.tryExpression(.{ .allow_calls = false })) |expr_handle| {
                maybe_result = expr_handle;
            } else {
                const error_token = self.next_token;
                self.recordErrorAbsRange("Failed to parse function type", .{
                    .first = fn_begin,
                    .last = error_token,
                }, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
                self.recordErrorAbs("Expected type expression", error_token, .{});
                return error.Sync;
            }
        }

        self.skipLinespace();
        if (self.token_kinds[self.next_token] == .block_open) {
            body = try self.proceduralBlock();
        } else if (maybe_left != null or maybe_right != null) {
            if (maybe_result) |result_handle| {
                if (self.ast.items[result_handle].info == .proc_block) {
                    self.recordErrorAbsRange("Failed to parse function definition", .{
                        .first = fn_begin,
                        .last = after_arrow,
                    }, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
                    self.recordErrorAbs("Expected result type", after_arrow, .{});
                    return error.Sync;
                }
            }

            const error_token = self.next_token;
            self.recordErrorAbsRange("Failed to parse function definition", .{
                .first = fn_begin,
                .last = error_token,
            }, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
            self.recordErrorAbs("Expected body block", error_token, .{});
            return error.Sync;
        } else {
            self.next_token = begin;
            return null;
        }
    }

    const left = maybe_left orelse self.addTerminal(.empty, fn_begin);
    const right = maybe_right orelse self.addTerminal(.empty, fn_begin);
    const result = maybe_result orelse self.addTerminal(.inferred_type, fn_begin);

    const args = self.addBinary(.fn_sig_args, fn_begin, left, right);
    const sig = self.addBinary(.fn_sig, fn_begin, args, result);
    return self.addBinary(.fn_def, fn_begin, sig, body);
}

fn structTypeLiteral(self: *Parser) SyncError!Ast.Handle {
    const literal_begin = self.next_token;
    std.debug.assert(self.token_kinds[literal_begin] == .kw_struct);
    self.next_token += 1;
    self.skipLinespace();
    const block_begin = self.next_token;
    if (!self.tryToken(.block_open)) {
        self.recordErrorAbs("Failed to parse struct type literal", literal_begin, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
        self.recordError("Expected '{'", .{});
        return error.Sync;
    }

    var maybe_list: ?Ast.Handle = null;

    while (true) {
        self.skipLinespace();
        const decl_start_token = self.next_token;
        const maybe_decl = self.tryDeclaration() catch {
            self.syncPastTokenOrLine(.block_close);
            if (self.token_kinds[self.backtrackToken(self.next_token, .{})] == .block_close) {
                break;
            } else {
                continue;
            }
        };
        if (maybe_decl) |decl_handle| {
            if (self.tryToken(.block_close)) {
                if (maybe_list) |list| {
                    maybe_list = self.addBinary(.list, decl_start_token, list, decl_handle);
                } else {
                    maybe_list = decl_handle;
                }
                break;
            } else if (!self.tryNewline()) {
                self.recordErrorAbs("Failed to parse declaration", self.ast.items[decl_handle].token_handle, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
                self.recordError("Expected end of line", .{});
                self.syncPastToken(.newline);
                continue;
            }

            if (maybe_list) |list| {
                maybe_list = self.addBinary(.list, decl_start_token, list, decl_handle);
            } else {
                maybe_list = decl_handle;
            }

        } else if (self.tryToken(.block_close)) {
            break;
        } else if (self.tryNewline()) {
            continue;
        } else {
            const first = self.next_token;
            self.syncPastTokenOrLine(.block_close);
            var last = self.backtrackToken(self.next_token, .{});
            if (first + 50 < last) {
                self.recordErrorAbs("Expected a declaration", first, Error.FlagSet.initOne(.has_continuation));
                self.recordErrorAbs("End of declaration/assignment/expression", last, Error.FlagSet.initOne(.supplemental));
            } else {
                self.recordErrorAbsRange("Expected a declaration", .{
                    .first = first,
                    .last = last,
                }, .{});
            }
        }
    }

    const list = maybe_list orelse self.addTerminal(.empty, block_begin);

    return self.addUnary(.struct_type_literal, block_begin, list);
}

fn unionTypeLiteral(self: *Parser) SyncError!Ast.Handle {
    _ = self;
    // TODO
    return 0;
}

fn stringLiteral(self: *Parser) Ast.Handle {
    const literal_token = self.next_token;
    if (self.tryToken(.string_literal)) {
        return self.addTerminal(.string_literal, literal_token);
    } else if (self.tryToken(.line_string_literal)) {
        while (true) {
            const end = self.next_token;
            if (!self.tryToken(.newline)) break;
            self.skipLinespace();
            if (self.tryToken(.line_string_literal)) continue;

            self.next_token = end;
            break;
        }
        return self.addTerminal(.string_literal, literal_token);
    } else unreachable;
}

fn trySymbol(self: *Parser) ?Token.Handle {
    const start_token = self.next_token;
    if (self.tryToken(.dot)) {
        if (self.tryIdentifier()) |token_handle| {
            return token_handle;
        }
    }
    self.next_token = start_token;
    return null;
}

fn tryIdentifier(self: *Parser) ?Token.Handle {
    if (self.tryToken(.id)) {
        return self.next_token - 1;
    }
    return null;
}

fn closeRegion(self: *Parser, begin_token: Token.Handle, token_kind: Token.Kind, comptime token_str: []const u8, comptime region_str: []const u8) SyncError!void {
    self.skipLinespace();
    if (self.tryToken(token_kind)) {
        return;
    }

    const error_token = self.next_token;
    self.syncPastTokenOrLine(token_kind);
    const end_token = self.backtrackToken(self.next_token, .{});

    self.recordErrorAbsRange("Failed to parse " ++ region_str, .{
        .first = begin_token,
        .last = end_token,
    }, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
    self.recordErrorAbs("Expected '" ++ token_str ++ "'", error_token, .{});

    return error.Sync;
}

fn closeMultiLineRegion(self: *Parser, begin_token: Token.Handle, token_kind: Token.Kind, comptime token_str: []const u8, comptime region_str: []const u8) SyncError!void {
    self.skipWhitespace();
    if (self.tryToken(token_kind)) {
        return;
    }

    const error_token = self.next_token;
    self.syncPastToken(token_kind);
    const end_token = self.backtrackToken(self.next_token, .{});

    if (begin_token + 50 < error_token) {
        self.recordErrorAbs("Failed to parse " ++ region_str ++ " starting here", begin_token, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
        self.recordErrorAbs("Expected '" ++ token_str ++ "'", error_token, Error.FlagSet.initOne(.has_continuation));
        self.recordErrorAbs("End of " ++ region_str, end_token, Error.FlagSet.initOne(.supplemental));
    } else if (error_token + 50 < end_token) {
        self.recordErrorAbsRange("Failed to parse " ++ region_str, .{
            .first = begin_token,
            .last = error_token,
        }, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
        self.recordErrorAbs("Expected '" ++ token_str ++ "'", error_token, Error.FlagSet.initOne(.has_continuation));
        self.recordErrorAbs("End of " ++ region_str, end_token, Error.FlagSet.initOne(.supplemental));
    } else {
        self.recordErrorAbsRange("Failed to parse " ++ region_str, .{
            .first = begin_token,
            .last = end_token,
        }, Error.FlagSet.initMany(&.{ .supplemental, .has_continuation }));
        self.recordErrorAbs("Expected '" ++ token_str ++ "'", error_token, .{});
    }

    return error.Sync;
}

fn tryNewline(self: *Parser) bool {
    const begin = self.next_token;
    self.skipLinespace();
    switch (self.token_kinds[self.next_token]) {
        .newline => {
            self.next_token += 1;
            return true;
        },
        .eof => return true,
        else => {
            self.next_token = begin;
            return false;
        }
    }
}

fn tryWhitespace(self: *Parser) bool {
    var found = false;
    while (switch (self.token_kinds[self.next_token]) {
        .linespace, .newline, .comment => true,
        else => false,
    }) {
        self.next_token += 1;
        found = true;
    }
    return found;
}

fn skipWhitespace(self: *Parser) void {
    while (switch (self.token_kinds[self.next_token]) {
        .linespace, .newline, .comment => true,
        else => false,
    }) {
        self.next_token += 1;
    }
}

fn tryLinespace(self: *Parser) bool {
    var found = false;
    while (switch (self.token_kinds[self.next_token]) {
        .linespace, .comment => true,
        else => false,
    }) {
        self.next_token += 1;
        found = true;
    }
    return found;
}

fn skipLinespace(self: *Parser) void {
    while (switch (self.token_kinds[self.next_token]) {
        .linespace, .comment => true,
        else => false,
    }) {
        self.next_token += 1;
    }
}

fn tryToken(self: *Parser, kind: Token.Kind) bool {
    if (self.token_kinds[self.next_token] == kind) {
        self.next_token += 1;
        return true;
    } else {
        return false;
    }
}

fn syncPastTokenOrLine(self: *Parser, kind: Token.Kind) void {
    while (true) {
        const found = self.token_kinds[self.next_token];
        self.next_token += 1;
        if (found == kind or found == .newline) {
            return;
        }
        switch (found) {
            .block_open, .dot_block_open => self.syncPastToken(.block_close),
            .index_open, .dot_index_open => self.syncPastToken(.index_close),
            .paren_open, .dot_paren_open => self.syncPastToken(.paren_close),

            .eof => {
                self.next_token -= 1;
                return;
            },

            else => {},
        }
    }
}

fn syncPastToken(self: *Parser, kind: Token.Kind) void {
    while (true) {
        const found = self.token_kinds[self.next_token];
        self.next_token += 1;
        if (found == kind) {
            return;
        }
        switch (found) {
            .block_open, .dot_block_open => self.syncPastToken(.block_close),
            .index_open, .dot_index_open => self.syncPastToken(.index_close),
            .paren_open, .dot_paren_open => self.syncPastToken(.paren_close),

            .eof => {
                self.next_token -= 1;
                return;
            },

            else => {},
        }
    }
}

const BacktrackOptions = struct {
    any_one_token: bool = true,
    eof: bool = true,
    newline: bool = true,
    comment: bool = true,
    linespace: bool = true,
};
fn backtrackToken(self: *Parser, token_handle: Token.Handle, options: BacktrackOptions) Token.Handle {
    var t = token_handle;
    if (t == 0) return t;

    const token_kinds = self.token_kinds;

    if (options.any_one_token or options.eof and token_kinds[t] == .eof) {
        t -= 1;
        if (t == 0) return t;
    }

    if (options.newline and token_kinds[t] == .newline) {
        t -= 1;
        if (t == 0) return t;
    }

    if (options.comment and token_kinds[t] == .comment) {
        t -= 1;
        if (t == 0) return t;
    }

    if (options.linespace and token_kinds[t] == .linespace) {
        t -= 1;
    }

    return t;
}

fn consumeTerminal(self: *Parser, kind: Ast.Kind) Ast.Handle {
    const token_handle = self.next_token;
    self.next_token += 1;
    return self.addTerminal(kind, token_handle);
}

fn addTerminal(self: *Parser, kind: Ast.Kind, token_handle: Token.Handle) Ast.Handle {
    @setEvalBranchQuota(10000);
    switch (kind) {
        inline else => |k| if (std.meta.FieldType(Ast.Info, k) == void) {
            const info = @unionInit(Ast.Info, @tagName(k), {});
            return self.addAst(token_handle, info);
        },
    }
    unreachable;
}

fn addUnary(self: *Parser, kind: Ast.Kind, token_handle: Token.Handle, inner: Ast.Handle) Ast.Handle {
    @setEvalBranchQuota(10000);
    switch (kind) {
        inline else => |k| if (std.meta.FieldType(Ast.Info, k) == Ast.Handle) {
            const info = @unionInit(Ast.Info, @tagName(k), inner);
            return self.addAst(token_handle, info);
        },
    }
    unreachable;
}

fn addBinary(self: *Parser, kind: Ast.Kind, token_handle: Token.Handle, left: Ast.Handle, right: Ast.Handle) Ast.Handle {
    @setEvalBranchQuota(10000);
    switch (kind) {
        inline else => |k| if (std.meta.FieldType(Ast.Info, k) == Ast.Binary) {
            const info = @unionInit(Ast.Info, @tagName(k), .{ .left = left, .right = right });
            return self.addAst(token_handle, info);
        },
    }
    unreachable;
}

fn addAst(self: *Parser, token_handle: Token.Handle, info: Ast.Info) Ast.Handle {
    const handle = @intCast(Ast.Handle, self.ast.items.len);
    self.ast.append(self.gpa, .{
        .token_handle = token_handle,
        .info = info,
    }) catch @panic("OOM");
    return handle;
}

fn recordError(self: *Parser, desc: []const u8, flags: Error.FlagSet) void {
    self.recordErrorAbs(desc, self.next_token, flags);
}
fn recordErrorRel(self: *Parser, desc: []const u8, token_offset: i8, flags: Error.FlagSet) void {
    self.recordErrorAbs(desc, @intCast(Token.Handle, @as(i64, self.next_token) + token_offset), flags);
}
fn recordErrorAbs(self: *Parser, desc: []const u8, token: Token.Handle, flags: Error.FlagSet) void {
    self.errors.append(self.gpa, .{
        .source_handle = self.source_handle,
        .context = .{ .token = token },
        .desc = desc,
        .flags = flags,
    }) catch @panic("OOM");
}

fn recordErrorAbsRange(self: *Parser, desc: []const u8, range: Token.Range, flags: Error.FlagSet) void {
    self.errors.append(self.gpa, .{
        .source_handle = self.source_handle,
        .context = .{ .token_range = range },
        .desc = desc,
        .flags = flags,
    }) catch @panic("OOM");
}

const DumpContext = struct {
    source_text: []const u8,
    token_offsets: []const u32,
    styles: []const console.Style,
    next_style: usize = 0,
};

pub fn dump(self: *Parser, ctx: DumpContext, writer: anytype) !void {
    var mut_ctx = ctx;

    if (mut_ctx.styles.len > 0) {
        try mut_ctx.styles[mut_ctx.next_style].apply(writer);
        mut_ctx.next_style = (mut_ctx.next_style + 1) % mut_ctx.styles.len;
    }

    if (self.module) |module| {
        try self.dumpAst(&mut_ctx, writer, "Module:", module, .{}, .{});
    } else {
        try writer.writeAll("Module: null\n");
    }

    if (mut_ctx.styles.len > 0) {
        try (console.Style{}).apply(writer);
    }
}

const DumpPrefix = struct {
    prev: ?*const DumpPrefix = null,
    prefix: []const u8 = "",

    pub fn dump(self: DumpPrefix, writer: anytype) !void {
        if (self.prev) |prev| try prev.dump(writer);
        try writer.writeAll(self.prefix);
    }
};

fn dumpAst(self: *Parser, ctx: *DumpContext, writer: anytype, label: []const u8, ast_handle: Ast.Handle, first: DumpPrefix, extra: DumpPrefix) @TypeOf(writer).Error!void {
    try first.dump(writer);

    var style_buf1: [32]u8 = undefined;
    var style_buf2: [32]u8 = undefined;

    var set_style: []const u8 = "";
    var reset_style: []const u8 = "";
    if (ctx.styles.len > 0) {
        var stream1 = std.io.fixedBufferStream(&style_buf1);
        try ctx.styles[ctx.next_style].apply(stream1.writer());
        set_style = stream1.getWritten();

        var stream2 = std.io.fixedBufferStream(&style_buf2);
        try (console.Style{}).apply(stream2.writer());
        reset_style = stream2.getWritten();

        ctx.next_style = (ctx.next_style + 1) % ctx.styles.len;
    }

    try writer.writeAll(label);
    try writer.writeAll(set_style);

    const ast = self.ast.items[ast_handle];
    const tag = @as(Ast.Kind, ast.info);
    if (label.len > 0) {
        try writer.writeByte(' ');
    }
    try writer.print("{s}", .{ @tagName(tag) });

    var buf1: [40]u8 = undefined;
    var buf2: [40]u8 = undefined;

    var new_first = DumpPrefix{ .prev = &extra, .prefix = undefined };
    var new_extra = DumpPrefix{ .prev = &extra, .prefix = undefined };

    new_first.prefix = try std.fmt.bufPrint(&buf1, "{s} *= ", .{ set_style });
    new_extra.prefix = try std.fmt.bufPrint(&buf2, "{s} |  ", .{ set_style });

    @setEvalBranchQuota(10000);
    switch (tag) {
        .list => {
            try writer.writeAll(reset_style);
            try writer.writeByte('\n');
            _ = try self.dumpAstList(ctx, writer, 0, true, ast.info.list, new_first, new_extra);
        },
        .id_ref, .symbol, .numeric_literal, .string_literal => {
            const token = Token.init(.{
                .kind = self.token_kinds[ast.token_handle],
                .offset = ctx.token_offsets[ast.token_handle],
            }, ctx.source_text);
            try writer.writeByte(' ');
            if (tag == .symbol) {
                try writer.writeByte('.');
            }
            try writer.print("{s}", .{ std.fmt.fmtSliceEscapeUpper(token.text) });
            try writer.writeAll(reset_style);
            try writer.writeByte('\n');
        },
        .field_declaration,
        .variable_declaration,
        .constant_declaration => {
            const token = Token.init(.{
                .kind = self.token_kinds[ast.token_handle],
                .offset = ctx.token_offsets[ast.token_handle],
            }, ctx.source_text);
            try writer.writeByte(' ');
            if (tag == .field_declaration) {
                try writer.writeByte('.');
            }
            try writer.print("{s}", .{ std.fmt.fmtSliceEscapeUpper(token.text) });
            try writer.writeAll(reset_style);
            try writer.writeByte('\n');
            const bin = switch (ast.info) {
                .field_declaration, .variable_declaration, .constant_declaration => |bin| bin,
                else => unreachable,
            };
            try self.dumpAst(ctx, writer, "L:", bin.left, new_first, new_extra);
            buf2[new_extra.prefix.len - 3] = ' ';
            try self.dumpAst(ctx, writer, "R:", bin.right, new_first, new_extra);
        },
        inline else => |k| {
            const F = std.meta.FieldType(Ast.Info, k);
            if (F == Ast.Handle) {
                buf2[new_extra.prefix.len - 3] = ' ';
                try self.dumpAst(ctx, writer, " ", @field(ast.info, @tagName(k)), .{}, extra);

            } else if (F == Ast.Binary) {
                try writer.writeAll(reset_style);
                try writer.writeByte('\n');
                const bin = @field(ast.info, @tagName(k));
                try self.dumpAst(ctx, writer, "L:", bin.left, new_first, new_extra);
                buf2[new_extra.prefix.len - 3] = ' ';
                try self.dumpAst(ctx, writer, "R:", bin.right, new_first, new_extra);

            } else if (F == void) {
                try writer.writeAll(reset_style);
                try writer.writeByte('\n');
            } else {
                unreachable;
            }
        },
    }
}

fn dumpAstList(self: *Parser, ctx: *DumpContext, writer: anytype, n: usize, is_last: bool, initial_list: Ast.Binary, first: DumpPrefix, extra: DumpPrefix) @TypeOf(writer).Error!usize {
    var mut_n = n;
    var list: Ast.Binary = initial_list;
    while (true) {
        switch (self.ast.items[list.left].info) {
            .list => |bin| {
                mut_n = try self.dumpAstList(ctx, writer, mut_n, false, bin, first, extra);
            },
            else => {
                var label_buf: [20]u8 = undefined;
                const label = try std.fmt.bufPrint(&label_buf, "{}:", .{ mut_n });
                try self.dumpAst(ctx, writer, label, list.left, first, extra);
                mut_n += 1;
            },
        }

        switch (self.ast.items[list.right].info) {
            .list => |bin| {
                list = bin;
            },
            else => {
                var label_buf: [20]u8 = undefined;
                const label = try std.fmt.bufPrint(&label_buf, "{}:", .{ mut_n });

                var extra_buf: [40]u8 = undefined;
                const new_extra_prefix = extra_buf[0..extra.prefix.len];
                @memcpy(new_extra_prefix, extra.prefix);
                if (is_last) {
                    new_extra_prefix[new_extra_prefix.len - 3] = ' ';
                }
                var new_extra = DumpPrefix{ .prev = extra.prev, .prefix = new_extra_prefix };

                try self.dumpAst(ctx, writer, label, list.right, first, new_extra);
                mut_n += 1;
                return mut_n;
            },
        }
    }
}
