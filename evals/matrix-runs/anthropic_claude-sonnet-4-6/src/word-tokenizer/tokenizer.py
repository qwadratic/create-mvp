import re

def tokenize(text: str) -> list[str]:
    return [w.lower() for w in re.split(r'[^a-zA-Z]+', text) if w]

if __name__ == '__main__':
    assert tokenize('Hello, World! 123') == ['hello', 'world']
    print('ok')
