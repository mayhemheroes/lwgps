fuzz: fuzz_nmea_parser.c ../lwgps/src/lwgps/lwgps.c
	clang -g -fsanitize=fuzzer,address,undefined -I/LWGPS/lwgps/src/include -DLWGPS_IGNORE_USER_OPTS $? -o $@
