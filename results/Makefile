TRACES := $(wildcard ../data/traces/*.dat)

.PHONY: runall

# parameter sets?
results/%.log: ../data/traces/%.dat scripts/sim.py
	./scripts/sim.py < $< > $@
	
