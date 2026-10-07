"""Recursive-descent parser for the ATT Lua DSL subset."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

from .lexer import Lexer, LexerError, Token


class ParseError(ValueError):
    def __init__(self, message: str, filename: str, line: int, column: int = 1) -> None:
        self.filename = filename
        self.line = line
        self.column = column
        super().__init__(f"{filename}:{line}:{column}: {message}")


@dataclass(kw_only=True)
class Node:
    line: int
    column: int = 1


@dataclass
class Chunk(Node):
    stats: list[Node] = field(default_factory=list)


@dataclass
class Assign(Node):
    targets: list[Node]
    values: list[Node]
    is_local: bool = False


@dataclass
class FunctionDef(Node):
    name: Node | None
    params: list[str]
    is_local: bool = False
    is_method: bool = False


@dataclass
class CallStat(Node):
    call: Node


@dataclass
class ReturnStat(Node):
    values: list[Node]


@dataclass
class DoBlock(Node):
    body: list[Node]


@dataclass
class IfStat(Node):
    clauses: list[tuple[Node | None, list[Node]]]


@dataclass
class ForNum(Node):
    name: str
    start: Node
    stop: Node
    step: Node | None
    body: list[Node]


@dataclass
class ForIn(Node):
    names: list[str]
    iters: list[Node]
    body: list[Node]


@dataclass
class WhileStat(Node):
    cond: Node
    body: list[Node]


@dataclass
class RepeatStat(Node):
    body: list[Node]
    cond: Node


@dataclass
class BreakStat(Node):
    pass


@dataclass
class Literal(Node):
    value: Any


@dataclass
class Name(Node):
    ident: str


@dataclass
class Vararg(Node):
    pass


@dataclass
class TableField:
    key: Node | None
    value: Node


@dataclass
class Table(Node):
    fields: list[TableField]


@dataclass
class UnaryOp(Node):
    op: str
    operand: Node


@dataclass
class BinOp(Node):
    op: str
    left: Node
    right: Node


@dataclass
class Index(Node):
    obj: Node
    key: Node


@dataclass
class Call(Node):
    func: Node
    args: list[Node]
    method: str | None = None


@dataclass
class FunctionExpr(Node):
    params: list[str]


class Parser:
    def __init__(self, tokens: list[Token], filename: str) -> None:
        self.tokens = tokens
        self.filename = filename
        self.pos = 0

    @property
    def cur(self) -> Token:
        return self.tokens[self.pos]

    def peek(self, kind: str) -> bool:
        return self.cur.kind == kind

    def peek_any(self, *kinds: str) -> bool:
        return self.cur.kind in kinds

    def eat(self, kind: str) -> Token:
        token = self.cur
        if token.kind != kind:
            raise ParseError(
                f"expected {kind}, got {token.kind}",
                self.filename,
                token.line,
                token.column,
            )
        self.pos += 1
        return token

    def try_eat(self, kind: str) -> Token | None:
        if self.peek(kind):
            return self.eat(kind)
        return None

    def parse_chunk(self) -> Chunk:
        stats: list[Node] = []
        while not self.peek("EOF"):
            if self.peek("SEMI"):
                self.eat("SEMI")
                continue
            stats.append(self.parse_stat())
            self.try_eat("SEMI")
        token = self.cur
        return Chunk(line=token.line, column=token.column, stats=stats)

    def parse_stat(self) -> Node:
        token = self.cur
        if self.peek("LOCAL"):
            return self.parse_local()
        if self.peek("FUNCTION"):
            return self.parse_function_stat(is_local=False)
        if self.peek("RETURN"):
            self.eat("RETURN")
            values = self.parse_exp_list() if self._starts_exp() else []
            return ReturnStat(line=token.line, column=token.column, values=values)
        if self.peek("BREAK"):
            self.eat("BREAK")
            return BreakStat(line=token.line, column=token.column)
        if self.peek("DO"):
            self.eat("DO")
            body = self.parse_block()
            self.eat("END")
            return DoBlock(line=token.line, column=token.column, body=body)
        if self.peek("IF"):
            return self.parse_if()
        if self.peek("WHILE"):
            return self.parse_while()
        if self.peek("REPEAT"):
            return self.parse_repeat()
        if self.peek("FOR"):
            return self.parse_for()
        return self.parse_assign_or_call()

    def parse_local(self) -> Node:
        token = self.eat("LOCAL")
        if self.peek("FUNCTION"):
            return self.parse_function_stat(is_local=True, line=token.line, column=token.column)
        names = [self._name_node()]
        while self.try_eat("COMMA"):
            names.append(self._name_node())
        values: list[Node] = []
        if self.try_eat("ASSIGN"):
            values = self.parse_exp_list()
        return Assign(line=token.line, column=token.column, targets=names, values=values, is_local=True)

    def parse_function_stat(self, is_local: bool, line: int | None = None, column: int | None = None) -> FunctionDef:
        token = self.eat("FUNCTION")
        line = line if line is not None else token.line
        column = column if column is not None else token.column
        name = self._name_node()
        is_method = False
        while self.peek("DOT") or self.peek("COLON"):
            sep = self.cur.kind
            self.pos += 1
            ident = self.eat("IDENT")
            key = Literal(line=ident.line, column=ident.column, value=ident.value)
            name = Index(line=ident.line, column=ident.column, obj=name, key=key)
            if sep == "COLON":
                is_method = True
        params = self.parse_param_list()
        self._skip_block_body()
        self.eat("END")
        return FunctionDef(
            line=line,
            column=column,
            name=name,
            params=params,
            is_local=is_local,
            is_method=is_method,
        )

    def parse_if(self) -> IfStat:
        token = self.eat("IF")
        clauses: list[tuple[Node | None, list[Node]]] = []
        cond = self.parse_exp()
        self.eat("THEN")
        body = self.parse_block("ELSEIF", "ELSE", "END")
        clauses.append((cond, body))
        while self.peek("ELSEIF"):
            self.eat("ELSEIF")
            cond = self.parse_exp()
            self.eat("THEN")
            body = self.parse_block("ELSEIF", "ELSE", "END")
            clauses.append((cond, body))
        if self.try_eat("ELSE"):
            body = self.parse_block("END")
            clauses.append((None, body))
        self.eat("END")
        return IfStat(line=token.line, column=token.column, clauses=clauses)

    def parse_while(self) -> WhileStat:
        token = self.eat("WHILE")
        cond = self.parse_exp()
        self.eat("DO")
        body = self.parse_block()
        self.eat("END")
        return WhileStat(line=token.line, column=token.column, cond=cond, body=body)

    def parse_repeat(self) -> RepeatStat:
        token = self.eat("REPEAT")
        body = self.parse_block("UNTIL")
        self.eat("UNTIL")
        cond = self.parse_exp()
        return RepeatStat(line=token.line, column=token.column, body=body, cond=cond)

    def parse_for(self) -> Node:
        token = self.eat("FOR")
        name_tok = self.eat("IDENT")
        if self.peek("ASSIGN"):
            self.eat("ASSIGN")
            start = self.parse_exp()
            self.eat("COMMA")
            stop = self.parse_exp()
            step = None
            if self.try_eat("COMMA"):
                step = self.parse_exp()
            self.eat("DO")
            body = self.parse_block()
            self.eat("END")
            return ForNum(
                line=token.line,
                column=token.column,
                name=str(name_tok.value),
                start=start,
                stop=stop,
                step=step,
                body=body,
            )
        names = [str(name_tok.value)]
        while self.try_eat("COMMA"):
            names.append(str(self.eat("IDENT").value))
        self.eat("IN")
        iters = self.parse_exp_list()
        self.eat("DO")
        body = self.parse_block()
        self.eat("END")
        return ForIn(line=token.line, column=token.column, names=names, iters=iters, body=body)

    def parse_block(self, *until: str) -> list[Node]:
        enders = set(until) | {"END", "EOF", "ELSEIF", "ELSE", "UNTIL"}
        if until:
            enders = set(until) | {"EOF"}
        stats: list[Node] = []
        while self.cur.kind not in enders:
            if self.peek("SEMI"):
                self.eat("SEMI")
                continue
            stats.append(self.parse_stat())
            self.try_eat("SEMI")
        return stats

    def parse_assign_or_call(self) -> Node:
        expr = self.parse_prefixexp()
        if self.peek_any("ASSIGN", "COMMA"):
            targets = [expr]
            while self.try_eat("COMMA"):
                targets.append(self.parse_prefixexp())
            assign_tok = self.eat("ASSIGN")
            values = self.parse_exp_list()
            return Assign(
                line=assign_tok.line,
                column=assign_tok.column,
                targets=targets,
                values=values,
                is_local=False,
            )
        if isinstance(expr, Call):
            return CallStat(line=expr.line, column=expr.column, call=expr)
        raise ParseError(
            "expected assignment or function call",
            self.filename,
            expr.line,
            expr.column,
        )

    def parse_param_list(self) -> list[str]:
        self.eat("LPAREN")
        params: list[str] = []
        if not self.peek("RPAREN"):
            if self.peek("VARARG"):
                self.eat("VARARG")
                params.append("...")
            else:
                params.append(str(self.eat("IDENT").value))
                while self.try_eat("COMMA"):
                    if self.peek("VARARG"):
                        self.eat("VARARG")
                        params.append("...")
                        break
                    params.append(str(self.eat("IDENT").value))
        self.eat("RPAREN")
        return params

    def _skip_block_body(self) -> None:
        """Skip tokens until the `end` that closes the current function/block.

        Used for function bodies we refuse to execute. Nested function/if/for
        /while/do/repeat blocks are tracked so we do not stop too early.
        """
        depth = 1
        while not self.peek("EOF") and depth > 0:
            kind = self.cur.kind
            if kind in {"FUNCTION", "IF", "REPEAT"}:
                depth += 1
                self.pos += 1
                continue
            if kind in {"FOR", "WHILE"}:
                self.pos += 1
                continue
            if kind == "DO":
                depth += 1
                self.pos += 1
                continue
            if kind == "END":
                depth -= 1
                if depth == 0:
                    return
                self.pos += 1
                continue
            if kind == "UNTIL":
                depth -= 1
                self.pos += 1
                continue
            self.pos += 1
        raise ParseError("unterminated function body", self.filename, self.cur.line, self.cur.column)

    def parse_exp_list(self) -> list[Node]:
        values = [self.parse_exp()]
        while self.try_eat("COMMA"):
            values.append(self.parse_exp())
        return values

    def _starts_exp(self) -> bool:
        return self.peek_any(
            "NIL",
            "TRUE",
            "FALSE",
            "NUMBER",
            "STRING",
            "IDENT",
            "FUNCTION",
            "LBRACE",
            "LPAREN",
            "MINUS",
            "NOT",
            "HASH",
            "VARARG",
            "ELLIPSIS",
        )

    def parse_exp(self) -> Node:
        return self.parse_or()

    def parse_or(self) -> Node:
        node = self.parse_and()
        while self.peek("OR"):
            tok = self.eat("OR")
            node = BinOp(line=tok.line, column=tok.column, op="or", left=node, right=self.parse_and())
        return node

    def parse_and(self) -> Node:
        node = self.parse_compare()
        while self.peek("AND"):
            tok = self.eat("AND")
            node = BinOp(line=tok.line, column=tok.column, op="and", left=node, right=self.parse_compare())
        return node

    def parse_compare(self) -> Node:
        node = self.parse_concat()
        while self.peek_any("LT", "GT", "LE", "GE", "EQ", "NE"):
            tok = self.cur
            self.pos += 1
            node = BinOp(line=tok.line, column=tok.column, op=str(tok.value), left=node, right=self.parse_concat())
        return node

    def parse_concat(self) -> Node:
        node = self.parse_add()
        if self.peek("CONCAT"):
            tok = self.eat("CONCAT")
            # Lua `..` is right-associative.
            node = BinOp(line=tok.line, column=tok.column, op="..", left=node, right=self.parse_concat())
        return node

    def parse_add(self) -> Node:
        node = self.parse_mul()
        while self.peek_any("PLUS", "MINUS"):
            tok = self.cur
            self.pos += 1
            node = BinOp(line=tok.line, column=tok.column, op=str(tok.value), left=node, right=self.parse_mul())
        return node

    def parse_mul(self) -> Node:
        node = self.parse_unary()
        while self.peek_any("STAR", "SLASH", "PERCENT", "IDIV"):
            tok = self.cur
            self.pos += 1
            node = BinOp(line=tok.line, column=tok.column, op=str(tok.value), left=node, right=self.parse_unary())
        return node

    def parse_unary(self) -> Node:
        if self.peek_any("NOT", "MINUS", "HASH"):
            tok = self.cur
            self.pos += 1
            op = {"NOT": "not", "MINUS": "-", "HASH": "#"}[tok.kind]
            return UnaryOp(line=tok.line, column=tok.column, op=op, operand=self.parse_unary())
        return self.parse_pow()

    def parse_pow(self) -> Node:
        node = self.parse_prefixexp_or_atom()
        if self.peek("CARET"):
            tok = self.eat("CARET")
            node = BinOp(line=tok.line, column=tok.column, op="^", left=node, right=self.parse_unary())
        return node

    def parse_prefixexp_or_atom(self) -> Node:
        if self.peek_any("NIL", "TRUE", "FALSE", "NUMBER", "STRING", "LBRACE", "FUNCTION", "VARARG"):
            return self.parse_atom()
        return self.parse_prefixexp()

    def parse_atom(self) -> Node:
        token = self.cur
        if self.peek("NIL"):
            self.eat("NIL")
            return Literal(line=token.line, column=token.column, value=None)
        if self.peek("TRUE"):
            self.eat("TRUE")
            return Literal(line=token.line, column=token.column, value=True)
        if self.peek("FALSE"):
            self.eat("FALSE")
            return Literal(line=token.line, column=token.column, value=False)
        if self.peek("NUMBER"):
            tok = self.eat("NUMBER")
            return Literal(line=tok.line, column=tok.column, value=tok.value)
        if self.peek("STRING"):
            tok = self.eat("STRING")
            return Literal(line=tok.line, column=tok.column, value=tok.value)
        if self.peek("VARARG"):
            tok = self.eat("VARARG")
            return Vararg(line=tok.line, column=tok.column)
        if self.peek("FUNCTION"):
            return self.parse_function_expr()
        if self.peek("LBRACE"):
            return self.parse_table()
        raise ParseError(f"unexpected {token.kind}", self.filename, token.line, token.column)

    def parse_function_expr(self) -> FunctionExpr:
        token = self.eat("FUNCTION")
        params = self.parse_param_list()
        self._skip_block_body()
        self.eat("END")
        return FunctionExpr(line=token.line, column=token.column, params=params)

    def parse_prefixexp(self) -> Node:
        token = self.cur
        if self.peek("IDENT"):
            node: Node = self._name_node()
        elif self.peek("LPAREN"):
            self.eat("LPAREN")
            node = self.parse_exp()
            self.eat("RPAREN")
        else:
            raise ParseError(f"expected prefix expression, got {token.kind}", self.filename, token.line, token.column)
        while True:
            if self.peek("DOT"):
                self.eat("DOT")
                ident = self.eat("IDENT")
                key = Literal(line=ident.line, column=ident.column, value=ident.value)
                node = Index(line=ident.line, column=ident.column, obj=node, key=key)
                continue
            if self.peek("LBRACKET"):
                self.eat("LBRACKET")
                key = self.parse_exp()
                self.eat("RBRACKET")
                node = Index(line=key.line, column=key.column, obj=node, key=key)
                continue
            if self.peek("COLON"):
                self.eat("COLON")
                ident = self.eat("IDENT")
                args = self.parse_args()
                node = Call(line=ident.line, column=ident.column, func=node, args=args, method=str(ident.value))
                continue
            if self.peek_any("LPAREN", "LBRACE", "STRING"):
                args = self.parse_args()
                node = Call(line=node.line, column=node.column, func=node, args=args)
                continue
            break
        return node

    def parse_args(self) -> list[Node]:
        if self.peek("LPAREN"):
            self.eat("LPAREN")
            args: list[Node] = []
            if not self.peek("RPAREN"):
                args = self.parse_exp_list()
            self.eat("RPAREN")
            return args
        if self.peek("LBRACE"):
            return [self.parse_table()]
        if self.peek("STRING"):
            tok = self.eat("STRING")
            return [Literal(line=tok.line, column=tok.column, value=tok.value)]
        raise ParseError("expected function arguments", self.filename, self.cur.line, self.cur.column)

    def parse_table(self) -> Table:
        token = self.eat("LBRACE")
        fields: list[TableField] = []
        while not self.peek_any("RBRACE", "EOF"):
            fields.append(self.parse_field())
            if self.try_eat("COMMA") or self.try_eat("SEMI"):
                continue
            break
        self.eat("RBRACE")
        return Table(line=token.line, column=token.column, fields=fields)

    def parse_field(self) -> TableField:
        if self.peek("LBRACKET"):
            self.eat("LBRACKET")
            key = self.parse_exp()
            self.eat("RBRACKET")
            self.eat("ASSIGN")
            value = self.parse_exp()
            return TableField(key=key, value=value)
        if self.peek("IDENT") and self._lookahead_kind() == "ASSIGN":
            ident = self.eat("IDENT")
            self.eat("ASSIGN")
            value = self.parse_exp()
            key = Literal(line=ident.line, column=ident.column, value=ident.value)
            return TableField(key=key, value=value)
        value = self.parse_exp()
        return TableField(key=None, value=value)

    def _lookahead_kind(self) -> str:
        if self.pos + 1 >= len(self.tokens):
            return "EOF"
        return self.tokens[self.pos + 1].kind

    def _name_node(self) -> Name:
        tok = self.eat("IDENT")
        return Name(line=tok.line, column=tok.column, ident=str(tok.value))


def parse_lua(source: str, filename: str = "<lua>") -> Chunk:
    try:
        tokens = Lexer(source, filename).tokens()
    except LexerError as exc:
        raise ParseError(str(exc), filename, exc.line, exc.column) from exc
    parser = Parser(tokens, filename)
    chunk = parser.parse_chunk()
    if not parser.peek("EOF"):
        tok = parser.cur
        raise ParseError(f"unexpected leftover token {tok.kind}", filename, tok.line, tok.column)
    return chunk
