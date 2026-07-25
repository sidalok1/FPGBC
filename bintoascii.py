import argparse

parser = argparse.ArgumentParser(
    prog="bintoascii",
    description="Convert binaries to hexadecimal ascii"
)

parser.add_argument("file")
parser.add_argument("-o", required=True)
parser.add_argument("-n", default=-1, type=int)

args = parser.parse_args()

lines = list()

with open(args.file, "rb") as binary:
    outfile = open(args.o, "w")
    outfile.write(binary.read(args.n).hex('\n'))
    outfile.close()