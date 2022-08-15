all: cp-replica

cp-replica: main.o
	$(LINK.c) -o $@ -Bstatic main.o -lm
	
main.o: main.c
	$(COMPILE.c) -g main.c

clean:
	$(RM) *.o cp-replica
