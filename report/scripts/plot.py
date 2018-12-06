import matplotlib.pyplot as plt
from matplotlib2tikz import save

xs = [2, 4, 8]
raw = [ 11.64, 11.65, 11.66, 11.64, 11.65, 11.64, 39.88, 20.12, 11.64, 161.39, 80.77, 40.31, 621.29, 313.71, 157.88, 2472.33, 1250.44, 622.59]
ys = [ raw[:3], raw[3:6], raw[6:9], raw[9:12], raw[12:15], raw[15:18]]
print(ys)

plt.plot(xs, ys[0], label='32x32')
plt.plot(xs, ys[1], label='64x64')
plt.plot(xs, ys[2], label='128x128')
plt.plot(xs, ys[3], label='256x256')
plt.plot(xs, ys[4], label='512x512')
plt.plot(xs, ys[5], label='1024x1024')
plt.yscale('log', basey=2)
plt.ylabel('Average Generation Time (ms)')
plt.xlabel('Workers')
plt.grid(True)
plt.legend()
save('agtplot.tex', figurewidth='\\figurewidth', 
                    figureheight='\\figureheight')