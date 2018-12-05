import sys, random, struct
if len(sys.argv) != 4:
    print("Use noise.py <w> <h> <file>", file=sys.stderr)
    exit()
w, h = int(sys.argv[1]), int(sys.argv[2])
with open(sys.argv[3], 'wb+') as f:
    f.write(b'P5\n%d %d\n255\n' % (w, h))
    pixels = [ random.randrange(0, 256, 255) for y in range(h) for x in range(w) ]
    f.write(struct.pack('B' * len(pixels), *pixels))
