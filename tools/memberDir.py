#!/usr/bin/env python3

import argparse

def memberStr():
  # Parse command line
  ap = argparse.ArgumentParser()
  ap.add_argument('datype', type=str,
                  help='Type of DA algorithm')
  ap.add_argument('member', type=int,
                  help='Member count')

  ## directory string formatter for ensemble members
  ap.add_argument('fmt', default='/mem{:03d}', type=str, nargs = '?',
                  help='Member string format')

  args = ap.parse_args()
  out = ''
  if ('eda' in args.datype or
      args.datype in ['ens','ensemble']):
    out += str(args.fmt).format(args.member)

  print(out)

if __name__ == '__main__': memberStr()
