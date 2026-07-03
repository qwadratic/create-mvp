#!/usr/bin/env python3
"""stage0: minimal Forth interpreter, python3 stdlib only.

Usage: python3 src/stage0/stage0.py <prog.fs> [input.fs]
"""
import sys
import re

NUM_RE = re.compile(r'^[+-]?\d+$')


class Forth:
    def __init__(self, src, input_path=None):
        self.src = src
        self.pos = 0
        self.stack = []
        self.words = {}        # name -> compiled code list
        self.mem = []          # variable cells
        self.lstack = []       # do-loop stack: [index, limit]
        self.input_path = input_path  # source for `token`
        self.out = sys.stdout
        self.strings = ['']    # string table; handle 0 is never valid
        self.in_tokens = None  # lazily loaded input.fs tokens
        self.in_pos = 0

    # ---- source scanning ----
    def next_token(self):
        s, n = self.src, len(self.src)
        i = self.pos
        while i < n and s[i].isspace():
            i += 1
        if i >= n:
            self.pos = n
            return None
        j = i
        while j < n and not s[j].isspace():
            j += 1
        self.pos = j
        return s[i:j]

    def read_string(self):
        """Read literal text up to closing double-quote (after ." or s")."""
        s = self.src
        i = self.pos
        if i < len(s) and s[i].isspace():
            i += 1  # single delimiter after the word
        j = s.index('"', i)
        self.pos = j + 1
        return s[i:j]

    # ---- compiler-support: string table + input token stream ----
    def intern(self, s):
        self.strings.append(s)
        return len(self.strings) - 1

    def word_token(self):
        if self.in_tokens is None:
            if self.input_path:
                with open(self.input_path) as f:
                    self.in_tokens = f.read().split()
            else:
                self.in_tokens = []
        if self.in_pos < len(self.in_tokens):
            t = self.in_tokens[self.in_pos]
            self.in_pos += 1
            self.stack.append(self.intern(t))
        else:
            self.stack.append(0)

    def skip_line(self):
        j = self.src.find('\n', self.pos)
        self.pos = len(self.src) if j < 0 else j + 1

    def skip_paren(self):
        j = self.src.index(')', self.pos)
        self.pos = j + 1

    # ---- compiling ----
    def compile_def(self):
        name = self.next_token().lower()
        code = []
        cstack = []
        while True:
            tok = self.next_token()
            if tok is None:
                raise SystemExit("stage0: unterminated definition: " + name)
            t = tok.lower()
            if t == ';':
                break
            elif t == '\\':
                self.skip_line()
            elif t == '(':
                self.skip_paren()
            elif t == '."':
                code.append(('str', self.read_string()))
            elif t == 's"':
                code.append(('lit', self.intern(self.read_string())))
            elif t == 'if':
                code.append(['0branch', None])
                cstack.append(len(code) - 1)
            elif t == 'else':
                orig = cstack.pop()
                code.append(['branch', None])
                code[orig][1] = len(code)
                cstack.append(len(code) - 1)
            elif t == 'then':
                code[cstack.pop()][1] = len(code)
            elif t == 'begin':
                cstack.append(len(code))
            elif t == 'until':
                code.append(['0branch', cstack.pop()])
            elif t == 'do':
                code.append(('do',))
                cstack.append(len(code))
            elif t == 'loop':
                code.append(['loop', cstack.pop()])
            elif NUM_RE.match(t):
                code.append(('lit', int(t)))
            else:
                code.append(('call', t))
        self.words[name] = code

    # ---- executing ----
    def run_code(self, code):
        st = self.stack
        ip = 0
        while ip < len(code):
            item = code[ip]
            ip += 1
            op = item[0]
            if op == 'lit':
                st.append(item[1])
            elif op == 'call':
                self.exec_word(item[1])
            elif op == 'str':
                self.out.write(item[1])
            elif op == '0branch':
                if st.pop() == 0:
                    ip = item[1]
            elif op == 'branch':
                ip = item[1]
            elif op == 'do':
                start = st.pop()
                limit = st.pop()
                self.lstack.append([start, limit])
            elif op == 'loop':
                l = self.lstack[-1]
                l[0] += 1
                if l[0] < l[1]:
                    ip = item[1]
                else:
                    self.lstack.pop()

    def exec_word(self, t):
        st = self.stack
        if t in self.words:
            self.run_code(self.words[t])
        elif t == '+':
            b = st.pop(); st.append(st.pop() + b)
        elif t == '-':
            b = st.pop(); st.append(st.pop() - b)
        elif t == '*':
            b = st.pop(); st.append(st.pop() * b)
        elif t == '/':
            b = st.pop(); st.append(st.pop() // b)
        elif t == 'mod':
            b = st.pop(); st.append(st.pop() % b)
        elif t == 'negate':
            st.append(-st.pop())
        elif t == '=':
            st.append(-1 if st.pop() == st.pop() else 0)
        elif t == '<':
            b = st.pop(); st.append(-1 if st.pop() < b else 0)
        elif t == '>':
            b = st.pop(); st.append(-1 if st.pop() > b else 0)
        elif t == 'dup':
            st.append(st[-1])
        elif t == 'drop':
            st.pop()
        elif t == 'swap':
            st[-2], st[-1] = st[-1], st[-2]
        elif t == 'over':
            st.append(st[-2])
        elif t == 'rot':
            st.append(st.pop(-3))
        elif t == '.':
            self.out.write(str(st.pop()) + ' ')
        elif t == 'emit':
            self.out.write(chr(st.pop()))
        elif t == 'cr':
            self.out.write('\n')
        elif t == 'i':
            st.append(self.lstack[-1][0])
        elif t == '@':
            st.append(self.mem[st.pop()])
        elif t == '!':
            a = st.pop(); self.mem[a] = st.pop()
        elif t == 'token':
            self.word_token()
        elif t == 'h.':
            self.out.write(self.strings[st.pop()])
        elif t == 'h=':
            b = st.pop(); a = st.pop()
            st.append(-1 if self.strings[a] == self.strings[b] else 0)
        elif t == 'h>n':
            s = self.strings[st.pop()]
            if NUM_RE.match(s):
                st.append(int(s)); st.append(-1)
            else:
                st.append(0); st.append(0)
        else:
            raise SystemExit("stage0: unknown word: " + t)

    # ---- top-level interpreter ----
    def interpret(self):
        while True:
            tok = self.next_token()
            if tok is None:
                break
            t = tok.lower()
            if t == '\\':
                self.skip_line()
            elif t == '(':
                self.skip_paren()
            elif t == ':':
                self.compile_def()
            elif t == 'variable':
                name = self.next_token().lower()
                addr = len(self.mem)
                self.mem.append(0)
                self.words[name] = [('lit', addr)]
            elif t == '."':
                self.out.write(self.read_string())
            elif t == 's"':
                self.stack.append(self.intern(self.read_string()))
            elif NUM_RE.match(t):
                self.stack.append(int(t))
            else:
                self.exec_word(t)


def main(argv):
    if len(argv) < 2:
        sys.stderr.write("usage: python3 stage0.py <prog.fs> [input.fs]\n")
        return 2
    with open(argv[1]) as f:
        src = f.read()
    input_path = argv[2] if len(argv) > 2 else None
    Forth(src, input_path).interpret()
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv))
