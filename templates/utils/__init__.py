#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import json
import hashlib
from pymorphy2 import MorphAnalyzer


morph = MorphAnalyzer()
prefix = './_site' if 'PREFIX' not in os.environ else os.environ['PREFIX']


def _(fp):
    return prefix + '/' + fp


def load_json(filename):
    with open(filename, "r") as f:
        return json.load(f)


def md5file(f_path, block_size=2**20):
    md5 = hashlib.md5()
    with open(f_path, 'rb') as f:
        while True:
            data = f.read(block_size)
            if not data:
                break
            md5.update(data)
    return md5.hexdigest()


def json_escape(x):
    if isinstance(x, bool):
        return 'true' if x else 'false'
    elif isinstance(x, int):
        return x
    else:
        escaped_str = str(x).replace('"', '\\"')
        return f'"{escaped_str}"'


def join(separator=''):
    def decorator(func):
        def wrapped(*args, **kwargs):
            return separator.join(list(func(*args, **kwargs)))
        return wrapped
    return decorator


@join('\n')
def indent(x, level):
    return [f'{" " * level}{line}' for line in x.split('\n')]


# https://stackoverflow.com/a/18603065
def last_line(fp):
    if not os.path.isfile(fp):
        return None

    with open(fp, 'rb') as f:
        f.seek(-2, os.SEEK_END)
        while f.read(1) != b"\n":
            f.seek(-2, os.SEEK_CUR)
        return f.readline().decode('utf-8')


# https://stackoverflow.com/a/1019572
def count_lines(fp):
    if not os.path.isfile(fp):
        return None

    with open(fp, 'r') as f:
        return sum(1 for line in f)


def dir_size(path):
    if not os.path.isdir(path):
        return os.path.getsize(path)

    total = 0

    for f in os.listdir(path):
        if os.path.isfile(f'{path}/{f}'):
            total += os.path.getsize(f'{path}/{f}')
        else:
            total += dir_size(f'{path}/{f}')

    return total


def numword(num, word):
    p = morph.parse(word)[0]
    return f'{num} {p.make_agree_with_number(num).word}'
