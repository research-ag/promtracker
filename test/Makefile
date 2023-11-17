MOPS_PKGS=$(shell mops sources)

all: promtracker

promtracker:
	moc $(MOPS_PKGS) -wasi-system-api promtracker.mo && wasmtime promtracker.wasm
