// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
import '../back_end/code_writer.dart';
import 'piece.dart';

/// A piece for a series of binary expressions at the same precedence, like:
///
///     a + b + c
abstract base class InfixPiece extends Piece {
    /// The series of operands.
    ///
    /// Since we don't split on both sides of the operator, the operators will be
    /// embedded in the operand pieces. If the operator is a hanging one, it will
    /// be in the preceding operand, so `1 + 2` becomes "Infix(`1 +`, `2`)".
    /// A leading operator like `foo as int` becomes "Infix(`foo`, `as int`)".
    final List<Piece> _operands;

    /// What kind of indentation should be applied to the subsequent operands.
    final Indent _indent;

    /// Creates an [InfixPiece] for the given series of [operands].
    factory InfixPiece(
        List<Piece> operands, {
        required bool is3Dot7,
        bool conditional = false,
        bool hangingOperator = false,
        Indent indent = Indent.expression,
    }) {
        if (is3Dot7) {
            return _InfixPiece3Dot7(operands, indent);
        } else {
            return _InfixPiece(operands, indent, conditional, hangingOperator);
        }
    }

    /// Creates an [InfixPiece] for a conditional (`?:`) expression.
    factory InfixPiece.conditional(List<Piece> operands, {required bool is3Dot7}) {
        if (is3Dot7) {
            return _InfixPiece3Dot7(operands, Indent.expression);
        } else {
            return _InfixPiece(operands, Indent.infix, true, false);
        }
    }

    InfixPiece._(this._operands, this._indent);

    @override
    void forEachChild(void Function(Piece piece) callback) {
        _operands.forEach(callback);
    }
}

/// InfixPiece subclass for 3.8 and newer style.
final class _InfixPiece extends InfixPiece {
    /// Whether this piece is for a conditional expression.
    final bool _isConditional;

    /// Whether the operator hangs at the end of the left operand (trailing
    /// operator style like `==`). When true, enables the [_blockSplitOperands]
    /// state which allows operands to be block-shaped without inserting a
    /// newline between them.
    final bool _hangingOperator;

    /// A state where operands stay on the same line (no split between them) but
    /// children are allowed to be block-shaped. This handles cases like:
    ///
    ///     fn(
    ///         arg1,
    ///         arg2,
    ///     ) == value
    ///
    /// where the function call is block-split but `== value` stays on the
    /// closing line. Only available for hanging (trailing) operator style.
    static const State _blockSplitOperands = State(1, cost: 0);

    _InfixPiece(super.operands, super.indent, this._isConditional, this._hangingOperator) : super._();

    @override
    List<State> get additionalStates => [
        if (_hangingOperator && _operands.length == 2) _blockSplitOperands,
        State.split,
    ];

    @override
    Set<Shape> allowedChildShapes(State state, Piece child) {
        if (state == _blockSplitOperands) return Shape.inlineOrBlock;
        return Shape.anyIf(state == State.split);
    }

    @override
    State? fixedStateForPageWidth(int pageWidth) {
        // Whether this piece has the _blockSplitOperands state available.
        var hasBlockSplit = _hangingOperator && _operands.length == 2;
        var totalLength = 0;

        for (var operand in _operands) {
            // If any operand contains a newline, we can't fit on one line.
            if (operand.containsHardNewline) {
                // For pieces with _blockSplitOperands, let the solver try it.
                if (hasBlockSplit) return null;
                return State.split;
            }

            // If any operand has stateful children that could be block-split,
            // totalCharacters doesn't reliably represent the actual line width.
            if (hasBlockSplit && operand.statefulOffspring.isNotEmpty) return null;

            totalLength += operand.totalCharacters;
            if (totalLength > pageWidth) break;
        }

        // If the total length doesn't fit in the page, then we have to split.
        if (totalLength > pageWidth) {
            // For pieces with _blockSplitOperands, the operands might fit when
            // children are block-split, so let the solver decide.
            if (hasBlockSplit) return null;
            return State.split;
        }

        return null;
    }

    @override
    void format(CodeWriter writer, State state) {
        writer.pushIndent(_indent);

        // If this is a conditional expression (or chain of them), then allow the
        // leading condition to be headline formatted in an assignment, like:
        //
        //     variable = condition
        //         ? thenBranch
        //         : elseBranch;
        //
        // We only do this for conditional expressions and not other infix operators
        // because with other operators, the operands are homogeneous and it makes
        // more sense to split before the first one so that they are aligned in
        // parallel:
        //
        //     variable =
        //         operand +
        //         another;
        if (_isConditional) writer.setShapeMode(ShapeMode.beforeHeadline);
        writer.format(_operands[0]);
        if (_isConditional) writer.setShapeMode(ShapeMode.afterHeadline);

        for (var i = 1; i < _operands.length; i++) {
            writer.splitIf(state == State.split);

            // We can format each operand separately if the operand is on its own
            // line. This happens when the operator is split and we aren't the first
            // or last operand.
            var separate = state == State.split && i < _operands.length - 1;
            writer.format(_operands[i], separate: separate);
        }

        writer.popIndent();
    }
}

/// [InfixPiece] subclass for 3.7 style.
final class _InfixPiece3Dot7 extends InfixPiece {
    _InfixPiece3Dot7(super.operands, super.indent) : super._();

    @override
    List<State> get additionalStates => const [State.split];

    @override
    Set<Shape> allowedChildShapes(State state, Piece child) => Shape.anyIf(state == State.split);

    @override
    State? fixedStateForPageWidth(int pageWidth) {
        var totalLength = 0;

        for (var operand in _operands) {
            // If any operand contains a newline, then we have to split.
            if (operand.containsHardNewline) return State.split;

            totalLength += operand.totalCharacters;
            if (totalLength > pageWidth) break;
        }

        // If the total length doesn't fit in the page, then we have to split.
        if (totalLength > pageWidth) return State.split;

        return null;
    }

    @override
    void format(CodeWriter writer, State state) {
        writer.pushIndent(_indent);

        for (var i = 0; i < _operands.length; i++) {
            // We can format each operand separately if the operand is on its own
            // line. This happens when the operator is split and we aren't the first
            // or last operand.
            var separate = state == State.split && i > 0 && i < _operands.length - 1;

            writer.format(_operands[i], separate: separate);
            if (i < _operands.length - 1) writer.splitIf(state == State.split);
        }

        writer.popIndent();
    }
}
