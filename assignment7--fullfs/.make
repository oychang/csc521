#!/usr/bin/env python

'''
pseudo-make for filesystem project
'''

from subprocess import call
from glob import glob

STANDALONE = (
    'filesystem',
)


def make():
    '''
    warn: even on failure, bcpl & assemble return 0, so the call
    checks do nothing
    '''
    bcpls = glob('*.bcpl')
    fns = [f.replace('.bcpl', '') for f in bcpls]

    for exe in STANDALONE:
        fns.remove(exe)
    for lib in fns:
        bcpl_cmd = 'bcpl ' + lib
        print bcpl_cmd
        if call(bcpl_cmd.split(' ')) != 0:
            raise SystemExit(1)

        assemble_cmd = 'assemble ' + lib
        print assemble_cmd
        if call(assemble_cmd.split(' ')) != 0:
            raise SystemExit(1)
    for exe in STANDALONE:
        prep_cmd = 'prep ' + exe
        print prep_cmd
        call(prep_cmd.split(' '))


if __name__ == '__main__':
    make()
