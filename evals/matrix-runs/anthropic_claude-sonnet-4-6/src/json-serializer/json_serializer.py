import json

def serialize(word_counts):
    return json.dumps(word_counts, sort_keys=True, separators=(',', ':'))

if __name__ == '__main__':
    assert serialize([{'word': 'hi', 'count': 1}]) == '[{"count":1,"word":"hi"}]'
    print('ok')
