package mcompiler;

import java.io.FileReader;
import java.io.IOException;
import java.io.Reader;
import java.util.HashMap;
import java.util.Scanner;
import java.util.Set;

import org.antlr.runtime.ANTLRReaderStream;
import org.antlr.runtime.CommonTokenStream;
import org.antlr.runtime.RecognitionException;
import org.antlr.runtime.tree.CommonTree;
import org.antlr.runtime.tree.CommonTreeNodeStream;


public class Main {
	
	private static String intStr = "int";
	private static String floatStr = "float";
	private static String stringStr = "string";
	private static String arrIntStr = "array int";
	private static String arrFloatStr = "array float";
	private static String arrStringStr = "array string";
	
	public static String printType(int t) {
		switch(t) {
			case 0:
				return intStr;
			case 1:
				return floatStr;
			case 2:
				return stringStr;
			case 3:
				return arrIntStr;
			case 4:
				return arrFloatStr;
			case 5:
				return arrStringStr;
			default:
				return intStr;
		}
	}
	
    public static void main(String[] args) throws IOException, RecognitionException {
    	Scanner scanner = new Scanner(System.in);
    	//String file = "/home/sertac/Desktop/mcodes/" + scanner.nextLine().trim();
    	String file = args[0];
    	MParser tokenParser = new MParser(getTokenStream(new FileReader(file)));
    	CommonTree ast = getAST(tokenParser);
        //System.out.println(ast.toStringTree()); // for debugging
    	MTree treeParser = new MTree(new CommonTreeNodeStream(ast));
    	treeParser.setSourcePath(file);
    	treeParser.setHasError(tokenParser.hasError());
    	treeParser.setFunctionTable(tokenParser.getFunctionTable());
    	treeParser.prog(); // start rule method
        
		if(args.length == 2) {
			if(args[1].equals("-printSymbolTable")) {
				HashMap<String,ScopeTable> funcTable = tokenParser.getFunctionTable();
				Set<String> functions = funcTable.keySet();
				System.out.println("************** Symbol Table **************");
				for (String string : functions) {
					ScopeTable table = funcTable.get(string);
					System.out.print("Function: " + printType(table.getReturnType()) + " " + table.getID());
					//System.out.println("\tReturn Type: " + );
					System.out.print("( ");
					for (int i = 0; i < table.getArgNum(); i++) {
						System.out.print(printType(table.getArgType(i)));
						System.out.print(" ");
					}
					System.out.println(")");
					System.out.println("\tVariables:");
					for (String string2 : table.table.keySet()) {
						Symbol s = table.table.get(string2);
						System.out.print("\t\t" + s.getID() + "\t" + printType(s.getType()));
						System.out.println("");
					}
					System.out.println("");	   	
				}
				
			}
		}
    }

    private static CommonTree getAST(MParser tokenParser) throws RecognitionException {
    	MParser.prog_return parserResult = tokenParser.prog(); // start rule method
        
        return (CommonTree) parserResult.getTree();
    }

    private static CommonTokenStream getTokenStream(Reader reader) throws IOException {
        MLexer lexer = new MLexer(new ANTLRReaderStream(reader));
        return new CommonTokenStream(lexer);
    }


} // end of Main class
