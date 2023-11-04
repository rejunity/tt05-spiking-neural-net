import numpy as np


inputs = 16
connections = 0
total = 0

for layer in [	("connections_0.mem", 16, 0.5), \
				("connections_1.mem", 16, 0.5), \
				("connections_2.mem",  8, 0.5) ]:

	filename = layer[0]
	neurons = layer[1]
	density = layer[2]

	sparsity = np.random.binomial(n=1, p=density, size=[neurons * inputs])

	ratio = (100.0-100.0*sum(sparsity)/len(sparsity))
	print(f"Writing connection mask to {filename}, sparsity {ratio:.2f}%, {sum(sparsity)} connections")
	with open(filename, 'w') as f:
		splits = np.array_split(sparsity, len(sparsity)//neurons)
		for s in splits:
			for i in s:
				f.write(str(i))
			f.write('\n')
	
	connections += sum(sparsity)
	total += len(sparsity)
	inputs = neurons

print(f"Total connections {connections} out of {total} possible")