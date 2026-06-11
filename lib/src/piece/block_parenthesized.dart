// Copyright (c) 2026, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import '../back_end/code_writer.dart';
import 'piece.dart';

/// A piece for a parenthesized logical (boolean) expression that can split
/// into a "block" style with the content on indented lines and the closing
/// bracket on its own line.
///
/// [State.unsplit] Everything on one line:
///
///     (a && b)
///
/// [State.split] Content indented on its own lines with the closing bracket
/// on its own line:
///
///     (
///         a
///         && b
///     )
final class BlockParenthesizedPiece extends Piece {
    /// The opening bracket, `(`.
    final Piece _left;

    /// The inner logical expression.
    final Piece _content;

    /// The closing bracket, `)`.
    final Piece _right;

    BlockParenthesizedPiece(this._left, this._content, this._right);

    @override
    List<State> get additionalStates => const [State.split];

    @override
    Set<Shape> allowedChildShapes(State state, Piece child) {
        // When unsplit, the content must fit on a single line.
        if (state == State.unsplit && child == _content) return Shape.onlyInline;
        return Shape.all;
    }

    @override
    State? fixedStateForPageWidth(int pageWidth) {
        if (_content.containsHardNewline) return State.split;
        // +2 for the two bracket characters.
        if (_content.totalCharacters + 2 > pageWidth) return State.split;
        return null;
    }

    @override
    void format(CodeWriter writer, State state) {
        writer.format(_left);

        if (state == State.split) {
            writer.pushIndent(Indent.block);
            writer.setShapeMode(ShapeMode.block);
            writer.newline();
        }

        writer.format(_content, separate: state == State.split);

        if (state == State.split) {
            writer.popIndent();
            writer.newline();
        }

        writer.format(_right);
    }

    @override
    void forEachChild(void Function(Piece piece) callback) {
        callback(_left);
        callback(_content);
        callback(_right);
    }
}
