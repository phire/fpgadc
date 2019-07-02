

all: test


obj_dir/Viee754_add.mk: ieee754_add.v ieee754_normalize.v
	verilator ieee754_add.v --cc  --exe ieee754_add_tb.cpp

obj_dir/Viee754_mac.mk: ieee754_mac.v ieee754_normalize.v
	verilator ieee754_mac.v --cc  --exe ieee754_mac_tb.cpp

obj_dir/Viee754_add: obj_dir/Viee754_add.mk ieee754_add_tb.cpp
	make -j  -C obj_dir -f Vieee754_add.mk Vieee754_add

obj_dir/Viee754_mac: obj_dir/Viee754_mac.mk ieee754_mac_tb.cpp
	make -j  -C obj_dir -f Vieee754_mac.mk Vieee754_mac

test: obj_dir/Viee754_mac
	obj_dir/Vieee754_mac

