import argparse

parser = argparse.ArgumentParser(
    prog="bintoascii",
    description="Convert binaries to hexadecimal ascii"
)

parser.add_argument("file")
parser.add_argument("-o", required=True)

args = parser.parse_args()

lines = list()

with open(args.file, "rb") as binary:
    outfile = open(args.o, "w")
    outfile.write(binary.read().hex('\n'))
    outfile.close()