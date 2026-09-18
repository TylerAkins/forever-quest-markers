"""Lua tokenizer for the ATT DSL subset."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Iterator


KEYWORDS = {
    "and",
    "break",
    "do",
    "else",
    "elseif",
    "end",
    "false",
    "for",
    "function",
    "goto",
    "if",
    "in",
    "local",
    "nil",
    "not",
    "or",
    "repeat",
    "return",
    "then",
    "true",
    "until",
    "while",
}


@dataclass(frozen=True, slots=True)
class Token:
    kind: str
    value: str | int | float | None
    line: int
    column: int


class LexerError(ValueError):
    def __init__(self, message: str, line: int, column: int) -> None:
        self.line = line
        self.column = column
        super().__init__(f"{line}:{column}: {message}")


class Lexer:
    def __init__(self, source: str, filename: str = "<lua>") -> None:
        self.source = source
        self.filename = filename
        self.pos = 0
        self.line = 1
        self.column = 1
        self._length = len(source)

    def tokens(self) -> list[Token]:
        return list(self.iter_tokens())

    def iter_tokens(self) -> Iterator[Token]:
        while True:
            token = self._next()
            yield token
            if token.kind == "EOF":
                return

    def _peek(self, n: int = 0) -> str:
        index = self.pos + n
        if index >= self._length:
            return ""
        return self.source[index]

    def _advance(self) -> str:
        ch = self.source[self.pos]
        self.pos += 1
        if ch == "\n":
            self.line += 1
            self.column = 1
        else:
            self.column += 1
        return ch

    def _next(self) -> Token:
        self._skip_whitespace_and_comments()
        if self.pos >= self._length:
            return Token("EOF", None, self.line, self.column)

        line, column = self.line, self.column
        ch = self._peek()

        if ch == '"' or ch == "'":
            return Token("STRING", self._read_short_string(), line, column)

        if ch == "[" and self._long_string_open_len() is not None:
            return Token("STRING", self._read_long_string(), line, column)

        if ch.isdigit() or (ch == "." and self._peek(1).isdigit()):
            return Token("NUMBER", self._read_number(), line, column)

        if ch.isalpha() or ch == "_":
            ident = self._read_ident()
            if ident in KEYWORDS:
                return Token(ident.upper(), ident, line, column)
            return Token("IDENT", ident, line, column)

        two = ch + self._peek(1)
        if two in {"==", "~=", "<=", ">=", "..", "//"}:
            self._advance()
            self._advance()
            kind = {"==": "EQ", "~=": "NE", "<=": "LE", ">=": "GE", "..": "CONCAT", "//": "IDIV"}[two]
            return Token(kind, two, line, column)

        if two == "...":
            # handled below if three dots; Lua vararg
            pass
        if ch == "." and self._peek(1) == "." and self._peek(2) == ".":
            self._advance()
            self._advance()
            self._advance()
            return Token("VARARG", "...", line, column)

        self._advance()
        symbols = {
            "+": "PLUS",
            "-": "MINUS",
            "*": "STAR",
            "/": "SLASH",
            "%": "PERCENT",
            "^": "CARET",
            "#": "HASH",
            "=": "ASSIGN",
            "(": "LPAREN",
            ")": "RPAREN",
            "{": "LBRACE",
            "}": "RBRACE",
            "[": "LBRACKET",
            "]": "RBRACKET",
            ";": "SEMI",
            ",": "COMMA",
            ":": "COLON",
            ".": "DOT",
            "<": "LT",
            ">": "GT",
        }
        kind = symbols.get(ch)
        if kind is None:
            raise LexerError(f"unexpected character {ch!r}", line, column)
        return Token(kind, ch, line, column)

    def _skip_whitespace_and_comments(self) -> None:
        while self.pos < self._length:
            ch = self._peek()
            if ch in " \t\r\n\f":
                self._advance()
                continue
            if ch == "-" and self._peek(1) == "-":
                self._advance()
                self._advance()
                if self._long_string_open_len() is not None:
                    self._read_long_string()
                else:
                    while self.pos < self._length and self._peek() != "\n":
                        self._advance()
                continue
            break

    def _long_string_open_len(self) -> int | None:
        if self._peek() != "[":
            return None
        n = 0
        while self._peek(1 + n) == "=":
            n += 1
        if self._peek(1 + n) == "[":
            return n
        return None

    def _read_long_string(self) -> str:
        n = self._long_string_open_len()
        if n is None:
            raise LexerError("invalid long string", self.line, self.column)
        # consume opening
        self._advance()  # [
        for _ in range(n):
            self._advance()
        self._advance()  # [
        # Lua skips a newline immediately after the opener
        if self._peek() == "\n":
            self._advance()
        start = self.pos
        closer = "]" + ("=" * n) + "]"
        index = self.source.find(closer, self.pos)
        if index < 0:
            raise LexerError("unterminated long string", self.line, self.column)
        value = self.source[start:index]
        # advance including closer
        skip = (index + len(closer)) - self.pos
        for _ in range(skip):
            self._advance()
        return value

    def _read_short_string(self) -> str:
        quote = self._advance()
        chars: list[str] = []
        while self.pos < self._length:
            ch = self._advance()
            if ch == quote:
                return "".join(chars)
            if ch == "\\":
                nxt = self._advance() if self.pos < self._length else ""
                escapes = {
                    "n": "\n",
                    "t": "\t",
                    "r": "\r",
                    "a": "\a",
                    "b": "\b",
                    "f": "\f",
                    "v": "\v",
                    "\\": "\\",
                    '"': '"',
                    "'": "'",
                    "\n": "\n",
                }
                chars.append(escapes.get(nxt, nxt))
                continue
            if ch == "\n":
                raise LexerError("unterminated string", self.line, self.column)
            chars.append(ch)
        raise LexerError("unterminated string", self.line, self.column)

    def _read_number(self) -> int | float:
        start = self.pos
        if self._peek() == "0" and self._peek(1) in "xX":
            self._advance()
            self._advance()
            while self._peek().isalnum() or self._peek() == "_":
                self._advance()
            raw = self.source[start : self.pos].replace("_", "")
            try:
                return int(raw, 16)
            except ValueError as exc:
                raise LexerError(f"invalid hex number {raw}", self.line, self.column) from exc
        while self._peek().isdigit():
            self._advance()
        is_float = False
        if self._peek() == "." and self._peek(1).isdigit():
            is_float = True
            self._advance()
            while self._peek().isdigit():
                self._advance()
        if self._peek() in "eE":
            is_float = True
            self._advance()
            if self._peek() in "+-":
                self._advance()
            while self._peek().isdigit():
                self._advance()
        raw = self.source[start : self.pos]
        try:
            return float(raw) if is_float or "." in raw else int(raw)
        except ValueError as exc:
            raise LexerError(f"invalid number {raw}", self.line, self.column) from exc

    def _read_ident(self) -> str:
        start = self.pos
        self._advance()
        while True:
            ch = self._peek()
            if ch.isalnum() or ch == "_":
                self._advance()
                continue
            break
        return self.source[start : self.pos]
