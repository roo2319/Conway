from matplotlib import pyplot as plt 
from matplotlib2tikz import save

# TODO: Add more data

evolve_xs = [1, 2, 4, 8]
evolve_64 = [19.69, 11.63, 11.64, 11.62]
evolve_128 = [77.72, 39.27, 19.40, 15.91]
evolve_256 = [312.50, 152.28, 77.52, 60.36]

agt_xs = [64, 128, 256]
agt_1 = [19.69, 77.72, 312.50]
agt_2 = [11.63, 39.27, 152.28]
agt_4 = [11.64, 19.40, 77.52]
agt_8 = [11.62, 15.91, 60.36]

plt.plot(evolve_xs, evolve_64, label='64x64')
plt.plot(evolve_xs, evolve_128, label='128x128')
plt.plot(evolve_xs, evolve_256, label='256x256')
plt.xlabel('Workers')
plt.ylabel('AGT (ms)')
plt.legend()
save('evolve.tex')
plt.cla()
plt.clf()

plt.loglog(agt_xs, agt_1, label='1 Worker', basex=2)
plt.loglog(agt_xs, agt_2, label='2 Workers', basex=2)
plt.loglog(agt_xs, agt_4, label='4 Workers', basex=2)
plt.loglog(agt_xs, agt_8, label='8 Workers', basex=2)
plt.xlabel('Image Size')
plt.ylabel('AGT (ms)')
plt.legend()
save('agt.tex')

