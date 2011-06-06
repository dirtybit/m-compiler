all: clean antlrbuild build

antlrbuild:
	java -cp antlr-3.3-complete.jar org.antlr.Tool M.g MTree.g -o mcompiler
	
build: antlrbuild		
	javac -Xlint -nowarn -cp antlr-3.3-complete.jar mcompiler/*.java -d bin

antlrclean:
	rm -rf mcompiler/MLexer.java mcompiler/MParser.java mcompiler/MTree.java mcompiler/MTree.tokens mcompiler/M.tokens
clean: antlrclean
	rm -rf bin/*
