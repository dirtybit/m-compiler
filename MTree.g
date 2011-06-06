tree grammar MTree;

options {
	ASTLabelType = CommonTree;
	tokenVocab = M;
}

tokens {
	PROG;
	FUNC;
	FUNC_ARG;
	FUNC_CALL;
	VAR;
	VAR_DECL;
	ARG;
	STMT;
	INIT;
	INC;
	COND;
	NEGATE;
	INDEX;
	BLOCK;
	SINGLE_STMT;
	BODY;
}

@header {
	package mcompiler;
	import java.util.HashMap;
	import java.util.Set;
	import java.util.Iterator;
	import java.io.File;
	import java.io.FileWriter;
	import java.io.BufferedWriter;
	import java.io.PrintWriter;
	import java.lang.NullPointerException;
}

@members {
	public HashMap functionTable;
	public HashMap stringTable;
	private boolean hasError;
	private String sourcePath;
	private String outputPath;
	private File outputFile;
	private PrintWriter writer;
	private int labelCounter;
	
	public void setSourcePath(String p) {
		sourcePath = p;
		outputPath = p.substring(0, p.lastIndexOf("/")+1) + p.substring(p.lastIndexOf("/"), p.lastIndexOf(".")) + ".s";
	}
	
	public void setFunctionTable(HashMap t) {
		functionTable = t;
	}
	
	public void setHasError(boolean e) {
		hasError = e;
	}
	
	public void reportError(RecognitionException e) {
		// if we've already reported an error and have not matched a token
		// yet successfully, don't report any errors.
		if ( state.errorRecovery ) {
			//System.err.print("[SPURIOUS] ");
			return;
		}
		state.syntaxErrors++; // don't count spurious
		state.errorRecovery = true;

		//displayRecognitionError(this.getTokenNames(), e);
	}
	
	public void printError(String errMsg) {
		hasError = true;
		System.err.println(errMsg);
	}
	
	private static String intStr = "int";
	private static String floatStr = "float";
	private static String stringStr = "string";
	private static String arrIntStr = "array int";
	private static String arrFloatStr = "array float";
	private static String arrStringStr = "array string";
	private static int maxStrLen = 256;
	
	public String printType(int t) {
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
	
	private void macro_push(String arg) {
		writer.println("\tsub\t\$sp, \$sp, 4\t# PUSH " + arg);
		writer.println("\tsw\t" + arg + ", (\$sp)");
	}
	
	private void macro_push_float(String arg) {
		writer.println("\tsub\t\$sp, \$sp, 4\t# PUSH " + arg);
		writer.println("\ts.s\t" + arg + ", (\$sp)");
	}
	
	private void macro_pop(String arg) {
		writer.println("\tlw\t" + arg + ", (\$sp)\t# POP " + arg);
		writer.println("\taddi\t\$sp, \$sp, 4");
	}
	
	private void macro_pop_float(String arg) {
		writer.println("\tl.s\t" + arg + ", (\$sp)\t# POP " + arg);
		writer.println("\taddi\t\$sp, \$sp, 4");
	}
	
	private void macro_leave() {
		writer.println("\tmove\t\$sp, \$fp");
		macro_pop("\$fp");
	}
	
	private void macro_ret() {
		macro_pop("\$ra");
		writer.println("\tj\t\$ra");
	}
	
	private void macro_caller_save() {
		writer.println("\t# SAVE CALLER-SAVED REGS");
		macro_push("\$s0");
		macro_push("\$s1");
		writer.println("\tsub\t\$sp, \$sp, 4\t# PUSH \$f24");
		writer.println("\ts.s\t\$f24, (\$sp)");
		writer.println("\tsub\t\$sp, \$sp, 4\t# PUSH \$f26");
		writer.println("\ts.s\t\$f26, (\$sp)");
		writer.println("\tsub\t\$sp, \$sp, 4\t# PUSH \$f28");
		writer.println("\ts.s\t\$f28, (\$sp)");
		writer.println("\tsub\t\$sp, \$sp, 4\t# PUSH \$f30");
		writer.println("\ts.s\t\$f30, (\$sp)");
		writer.println("\t# SAVE COMPLETE");
	}

	private void restore_caller_save() {
		writer.println("\t# RESTORE CALLER-SAVED REGS");
		writer.println("\tl.s\t\$f30, (\$sp)\t# POP \$f30");
		writer.println("\taddi\t\$sp, \$sp, 4");
		writer.println("\tl.s\t\$f28, (\$sp)\t# POP \$f28");
		writer.println("\taddi\t\$sp, \$sp, 4");
		writer.println("\tl.s\t\$f26, (\$sp)\t# POP \$f26");
		writer.println("\taddi\t\$sp, \$sp, 4");
		writer.println("\tl.s\t\$f24, (\$sp)\t# POP \$f24");
		writer.println("\taddi\t\$sp, \$sp, 4");
		macro_pop("\$s1");
		macro_pop("\$s0");
		writer.println("\t# RESTORE COMPLETE");
	}
		
	private void macro_callee_save() {
		writer.println("\t# SAVE CALLEE-SAVED REGS");
		for(int i=5; i < 10; i++) {
			macro_push("\$t" + Integer.toString(i));
		}
		writer.println("\t# SAVE COMPLETE");
	}

	private void restore_callee_save() {
		writer.println("\t# RESTORE CALLEE-SAVED REGS");
		for(int i=10; i > 5; i--) {
			macro_pop("\$t" + Integer.toString(i-1));
		}
		writer.println("\t# RESTORE COMPLETE");
	}
	
	private void macro_input_int(String addr) {
		writer.println("\tli\t\$v0, 5");
		writer.println("\tsyscall");
		writer.println("\tsw\t\$v0, (" + addr + ")");		
	}
	
	private void macro_input_float(String addr) {
		writer.println("\tli\t\$v0, 6");
		writer.println("\tsyscall");
		writer.println("\ts.s\t\$f0, (" + addr + ")");		
	}
	
	private void macro_input_string(String addr) {
    	writer.println("\tli\t\$v0, 9");
    	writer.println("\tli\t\$a0, " + Integer.toString(maxStrLen));
    	writer.println("\tsyscall");
    	writer.println("\tmove\t\$a0, \$v0");
    	writer.println("\tli\t\$v0, 8");
    	writer.println("\tli\t\$a1, " + Integer.toString(maxStrLen));
    	writer.println("\tsyscall");
		writer.println("\tsw\t\$a0, (" + addr + ")");
	}
	
	private void macro_output_int(String valReg) {
		writer.println("\tli\t\$v0, 1");
		writer.println("\tmove\t\$a0, " + valReg);
		writer.println("\tsyscall");
	}
	
	private void macro_output_float(String valReg) {
		writer.println("\tli\t\$v0, 2");
		writer.println("\tmov.s\t\$f12, " + valReg);
		writer.println("\tsyscall");
	}
	
	private void macro_output_string(String valReg) {
		writer.println("\tli\t\$v0, 4");
		writer.println("\tmove\t\$a0, " + valReg);
		writer.println("\tsyscall");
	}
	
	private void floatArithmetic(String op) {
		if(op.equals("+")) {
			writer.println("\tadd.s\t\$f30, \$f28, \$f30");
		}
		else if(op.equals("-")) {
			writer.println("\tsub.s\t\$f30, \$f28, \$f30");
		}
		else if(op.equals("*")) {
			writer.println("\tmul.s\t\$f30, \$f28, \$f30");
		}
		else if(op.equals("/")) {
			writer.println("\tdiv.s\t\$f30, \$f28, \$f30");
		}
		macro_push_float("\$f30");
	}
	
	private void integerArithmetic(String op) {
		if(op.equals("+")) {
			writer.println("\tadd\t\$t9, \$t8, \$t9");
		}
		else if(op.equals("-")) {
			writer.println("\tsub\t\$t9, \$t8, \$t9");
		}
		else if(op.equals("*")) {
			writer.println("\tmul\t\$t9, \$t8, \$t9");
		}
		else if(op.equals("/")) {
			writer.println("\tdiv\t\$t9, \$t8, \$t9");
		}
		macro_push("\$t9");
	}
	
	private void integerLogical(String op) {
		if(op.equals("and")) {
			writer.println("\tand\t\$t9, \$t8, \$t9");
		}
		else if(op.equals("or")) {
			writer.println("\tor\t\$t9, \$t8, \$t9");
		}
		else if(op.equals("<")) {
			writer.println("\tslt\t\$t9, \$t8, \$t9");
		}
		else if(op.equals("<=")) {
			writer.println("\tsle\t\$t9, \$t8, \$t9");
		}
		else if(op.equals(">")) {
			writer.println("\tsgt\t\$t9, \$t8, \$t9");
		}
		else if(op.equals(">=")) {
			writer.println("\tsge\t\$t9, \$t8, \$t9");
		}
		else if(op.equals("==")) {
			writer.println("\tseq\t\$t9, \$t9, \$t8");
		}
		else if(op.equals("!=")) {
			writer.println("\tsne\t\$t9, \$t9, \$t8");
		}
		macro_push("\$t9");
	}
	
	private void floatLogical(String op) {
		String label1 = Integer.toString(labelCounter++);
		String label2 = Integer.toString(labelCounter++);
	
		if(op.equals("and")) {
			writer.println("\tli.s\t\$f24, 2.0");
			writer.println("\tadd.s\t\$f26, \$f28, \$f30");
			writer.println("\tc.eq.s\t\$f26, \$f24");
			writer.println("\tbc1t\tLC" + label1);
		}
		else if(op.equals("or")) {
			writer.println("\tli.s\t\$f24, 0.0");
			writer.println("\tadd.s\t\$f26, \$f28, \$f30");
			writer.println("\tc.lt.s\t\$f24, \$f26");
			writer.println("\tbc1t\tLC" + label1);
		}
		else if(op.equals("<")) {
			writer.println("\tc.lt.s\t\$f28, \$f30");
			writer.println("\tbc1t\tLC" + label1);
		}
		else if(op.equals("<=")) {
			writer.println("\tc.le.s\t\$f28, \$f30");
			writer.println("\tbc1t\tLC" + label1);
		}
		else if(op.equals(">")) {
			writer.println("\tc.le.s\t\$f28, \$f30");
			writer.println("\tbc1f\tLC" + label1);
		}
		else if(op.equals(">=")) {
			writer.println("\tc.lt.s\t\$f28, \$f30");
			writer.println("\tbc1f\tLC" + label1);
		}
		else if(op.equals("==")) {
			writer.println("\tc.eq.s\t\$f28, \$f30");
			writer.println("\tbc1t\tLC" + label1);
			
		}
		else if(op.equals("!=")) {
			writer.println("\tc.eq.s\t\$f28, \$f30");
			writer.println("\tbc1f\tLC" + label1);
		}
		writer.println("\tli.s\t\$f30, 0.0");
		writer.println("\tj\tLC" + label2);		
		writer.println("LC" + label1 + ":\tli.s\t\$f30, 1.0");
		writer.println("\tLC" + label2 + ":");
		macro_push_float("\$f30");
	}
}

// Tree Parser Rules
prog
	@init {
		outputFile = null;
		writer = null;
		stringTable = new HashMap<String, String>();
		labelCounter = 0;
		
		try {
			outputFile = new File(outputPath);
			writer = new PrintWriter(new BufferedWriter(new FileWriter(outputFile)));
		}
		catch (Exception ex) {
			ex.printStackTrace();
		}
		writer.println("\t.align\t2");
		writer.println("\t.text");
		
    	Set keys = functionTable.keySet();
    	for (Iterator iterator = keys.iterator(); iterator.hasNext();) {
			String key = (String) iterator.next();
			writer.print("\t.globl\t");
			writer.println(key);			
		}
	}
	@after {
		if(hasError) {
			outputFile.delete();
		}
		
		writer.println("\n\t.data");
		Set keysL = stringTable.keySet();
    	for (Iterator iterator = keysL.iterator(); iterator.hasNext();) {
			String keyL = (String) iterator.next();
			writer.print(keyL);
			writer.print(":\t.asciiz \"");
			writer.print(((String)stringTable.get(keyL)).replace("\\\%","\%"));
			writer.println("\"");
		}	
		writer.close();
	}
	:
	^(PROG func+);

array_type:
	ARRAY SIMPLE_TYPE;

type:
	SIMPLE_TYPE | array_type;

func
	scope {
		ScopeTable table;
		boolean hasReturn;
	}
	@init {
		$func::hasReturn = false;
	}
	@after {
		if(!$func::hasReturn)
			printError("error: line " + $f.line + ": Function \'" + $id.text + "\' must return a value: missing return statement");
	}
	:
	^(f=FUN type id=ID
		{
			$func::table = (ScopeTable) functionTable.get($id.text);
		} 
	arg* var_decl*
		{
			int frameSize = ($func::table.getLocalSize())*4;
			writer.print($id.text);
			writer.println(":\t");
			macro_push("\$ra");
			macro_push("\$fp");
			// create frame
			writer.println("\tmove\t\$fp, \$sp");
			if(frameSize > 0) {
				writer.print("\tsubu\t\$sp, \$sp, ");
				writer.println(Integer.toString(frameSize));
			}
			// save callee saved regs
			macro_callee_save();
		}
	stmt)
	;

arg:
	^(ARG_KEY type ID);
	
var_decl:
	^(VAR_KEY (normal_var | array_var));
	
normal_var:
	SIMPLE_TYPE ID+;
	
array_var:
	array_type ID INT;

func_call[String var, int varType, String addr] returns [int type]
	@init {
		ScopeTable table = null;
		Symbol sym = null;
		int disp;
		int i = 0;
	}
	:
	^(FUNC_CALL id=ID
		{	
		
			table = (ScopeTable) functionTable.get($id.text);
			// save caller saved regs	
			macro_caller_save();
		}
			(val=value[$var, $type, $addr] 
				{ 
					if(table != null) {					
						int argType = 0;
						if(table.getArgNum() > i)
							argType = table.getArgType(i);
						
						if(argType == $val.type) {
							if($val.type > 2) {
								Symbol s = table.getSymbol(table.getArgName(i));
								s.setSize($val.size);
							}
						}
						else if(argType == 0 && $val.type == 1) {
							macro_pop_float("\$f30");
							writer.println("\tcvt.w.s\t\$f30, \$f30");
							macro_push_float("\$f30");
						}
						else if(argType == 1 && $val.type == 0) {
							macro_pop_float("\$f30");
							writer.println("\tcvt.s.w\t\$f30, \$f30");
							macro_push_float("\$f30");
						}
						else
							printError("error: line " + $id.line + ": For function \'" + $id.text + "\' Argument " + Integer.toString(i+1) + " is an \'" + printType(argType) + "\' instead of \'" + printType($val.type));
						
						i++;
					}
				}
			)*
		)
		{
			if(!functionTable.containsKey($id.text))
				printError("error: line " + $id.line + ": Function \'" + $id.text + "\' undeclared");
			else
			{
				$type = table.getReturnType();
				
				if(table.getArgNum() != i)
					printError("error: line " + $id.line + ": For function \'" + $id.text + "\' formal and actual parameters does not match in number");
				else {
					writer.print("\tjal\t");
					writer.println($id.text);
					writer.println("\taddi\t\$sp, \$sp, " + Integer.toString(table.getArgNum()*4));
					restore_caller_save();
				}
			}

		}
	| ^(FUNC_CALL INPUT id=ID)	// array basename icin input?
		{
			if($var == null) {
				sym = $func::table.getSymbol($id.text);
				
				if(sym == null)
					printError("error: line " + $id.line + ": Variable \'" + $id.text + "\' undeclared");
				else if(sym.isArray() != 0)
					printError("error: line " + $id.line + ": input is not applicable on arrays");
				else {
					if(sym.isArg()) {
						disp = ($func::table.getArgNum()-sym.getNumber()+1)*4;		
					}
					else {
						disp = (sym.getNumber()-$func::table.getArgNum()+1)*(-4);
					}
					writer.print("\tla\t\$s0, ");
					writer.print(Integer.toString(disp));
					writer.println("(\$fp)");				
					switch(sym.getType()) {
						case 0:
							macro_input_int("\$s0");
							break;
						case 1:
							macro_input_float("\$s0");
							break;
						case 2:
							macro_input_string("\$s0");
							break;
					}
				}
			}
		}		
	| ^(FUNC_CALL INPUT ^(INDEX id=ID v=value[$var, $type, $addr]))
		{
			if($var == null) {
				sym = $func::table.getSymbol($id.text);
				
				if(sym == null)
					printError("error: line " + $id.line + ": Variable \'" + $id.text + "\' undeclared");
				else
				{
					if($v.type != 0)
						printError("error: line " + $id.line + ": Array subscript must be an \'int\' instead of \'" + printType($v.type) + "\'");
					else {
						if(sym.isArg()) {
							disp = ($func::table.getArgNum()-sym.getNumber()+1)*4;		
						}
						else {
							disp = (sym.getNumber()-$func::table.getArgNum()+1)*(-4);
						}
						
						writer.print("\tla\t\$s0, ");
						writer.print(Integer.toString(disp));
						writer.println("(\$fp)");
						if(sym.isArg()) {
							writer.println("\tlw\t\$s0, (\$s0)");
						}
						macro_pop("\$t9");
						writer.println("\tsub\t\$t9, \$t9, 1");
						writer.println("\tmul\t\$s1, \$t9, 4");
						writer.println("\tsub\t\$s0, \$s0, \$s1");
						
						switch(sym.getType()-3) {
						case 0:
							macro_input_int("\$s0");
							break;
						case 1:
							macro_input_float("\$s0");
							break;
						case 2:
							macro_input_string("\$s0");
							break;
						}			
					}
				}
			}
			else {
				printError("error: line " + $id.line + ": Binding variable \'" + $id.text + "\' cannot be an array");
			}	
		}
	| ^(fc=FUNC_CALL OUTPUT v=value[$var, $type, $addr])
		{
			switch($v.type) {
				case 0:
					macro_pop("\$t9");
					macro_output_int("\$t9");
					break;
				case 1:
					macro_pop_float("\$f30");
					macro_output_float("\$f30");
					break;
				case 2:
					macro_pop("\$t9");
					macro_output_string("\$t9");
					break;
				default:
					printError("error: line " + $fc.line + ": output is not applicable on arrays");
					break;
			}
		}
	;
		
value[String var, int varType, String addr] returns [int type, int size]
	@init {
		Symbol sym = null;
		int disp = 0;
	}
	:
	^(op=(MINUS | PLUS | MULT | DIV) v1=value[$var, $type, $addr] v2=value[$var, $type, $addr])
		{
			if($v1.type > 2 || $v2.type > 2)
			{
				printError("error: line " + $op.line + ": Array names cannot be an operand of arithmetic operators");
			}
			else if($v1.type > 1 || $v2.type > 1)
			{
				printError("error: line " + $op.line + ": Strings cannot be an operand of arithmetic operators");
			}
			else if($v1.type == 1 && $v2.type == 1)	{				// float - float
				$type = 1;
				macro_pop_float("\$f30");
				macro_pop_float("\$f28");
				floatArithmetic($op.text);
			}
			else if($v1.type == 1 && $v2.type == 0) {				// float - int
				$type = 1;
				macro_pop_float("\$f30");
				writer.println("\tcvt.s.w\t\$f30, \$f30");
				macro_pop_float("\$f28");
				floatArithmetic($op.text);
			}
			else if($v1.type == 0 && $v2.type == 1) {				// int - float
				$type = 1;
				macro_pop_float("\$f30");
				macro_pop_float("\$f28");
				writer.println("\tcvt.s.w\t\$f28, \$f28");
				floatArithmetic($op.text);
			}
			else {													// int - int
				$type = 0;
				macro_pop("\$t9");
				macro_pop("\$t8");
				integerArithmetic($op.text);
			}
		}
	| id=ID 
		{
			if($var == null) {	
				sym = $func::table.getSymbol($id.text);
				
				if(sym == null)
					printError("error: line " + $id.line + ": Variable \'" + $id.text + "\' undeclared");
				else {
					$type = sym.getType();
					if(sym.isArg()) {
						disp = ($func::table.getArgNum()-sym.getNumber()+1)*4;		
					}
					else {
						disp = (sym.getNumber()-$func::table.getArgNum()+1)*(-4);
					}	
					switch(sym.getType()) {
						case 0:
							writer.println("\tlw\t\$t9, " + Integer.toString(disp) + "(\$fp)");
							macro_push("\$t9");
							break;
						case 1:
							writer.println("\tl.s\t\$f30, " + Integer.toString(disp) + "(\$fp)");
							macro_push_float("\$f30");
							break;
						case 2:
							writer.println("\tlw\t\$t9, " + Integer.toString(disp) + "(\$fp)");
							macro_push("\$t9");
							break;
						default:	
							$size = sym.getSize();
							writer.print("\tla\t\$t9, ");
							writer.print(Integer.toString(disp));
							writer.println("(\$fp)");
							if(sym.isArg()) {
								writer.println("\tlw\t\$t9, (\$t9)");
							}
							macro_push("\$t9");				
							break;
					}
				}
			}
			else {
				$type = $varType;
				if($varType == 1) {
					writer.println("\tl.s\t\$f30, (" + $addr + ")");
					macro_push_float("\$f30");
				}
				else {
					writer.println("\tlw\t\$t9, (" + $addr + ")");
					macro_push("\$t9");
				}
			}
		}
	| ^(INDEX id=ID v=value[$var, $type, $addr])
		{
			sym = $func::table.getSymbol($id.text);
			
			if(sym == null)
				printError("error: line " + $id.line + ": Variable \'" + $id.text + "\' undeclared");
			else
			{
				if($v.type != 0)
					printError("error: line " + $id.line + ": Array subscript must be an \'int\' instead of \'" + printType($v.type) + "\'");
				else {
					$type = sym.getType()-3;
					if(sym.isArg()) {
						disp = ($func::table.getArgNum()-sym.getNumber()+1)*4;		
					}
					else {
						disp = (sym.getNumber()-$func::table.getArgNum()+1)*(-4);
					}
					
					writer.print("\tla\t\$s0, ");
					writer.print(Integer.toString(disp));
					writer.println("(\$fp)");
					if(sym.isArg()) {
						writer.println("\tlw\t\$s0, (\$s0)");
					}					
					macro_pop("\$t9");
					writer.println("\tsub\t\$t9, \$t9, 1");
					writer.println("\tmul\t\$s1, \$t9, 4");
					writer.println("\tsub\t\$s0, \$s0, \$s1");
					switch($type) {
					case 0:
						writer.println("\tlw\t\$t9, (\$s0)");
						macro_push("\$t9");
						break;
					case 1:
						writer.println("\tl.s\t\$f30, (\$s0)");
						macro_push_float("\$f30");
						break;
					case 2:
						writer.println("\tlw\t\$t9, (\$s0)");
						macro_push("\$t9");
						break;
					}			
				}
			}
		} 
	| i=INT 
		{
			$type = 0;
			writer.println("\tli\t\$t9, " + $i.text);
			macro_push("\$t9");
		} 
	| f=FLOAT 
		{
			$type = 1;
			writer.println("\tli.s\t\$f30, " + $f.text);
			macro_push_float("\$f30");
		} 
	| fc=func_call[$var, $type, $addr]
		{
			$type = $fc.type;
			if($type == 1) {
				macro_push_float("\$f0");
			}
			else {
				macro_push("\$v0");
			}
		} 
	| ^(NEGATE v=value[$var, $type, $addr]) 
		{ 
			if($v.type > 1)
				printError("Negation can be applied only to int and float");
			else {
				if($type == 1) {
					macro_pop_float("\$f30");
					writer.println("\tneg.s\t\$f30, \$f30");
					macro_push_float("\$f30");				
				}	
				else {
					macro_pop("\$t9");
					writer.println("\tneg\t\$t9, \$t9");
					macro_push("\$t9");
				}
			}
		}
	| s=STRING 
		{
			$type = 2;
			String label = "LC" + Integer.toString(labelCounter++);
			stringTable.put(label, $s.text.replaceAll("\'",""));
			writer.println("\tla\t\$t9, " + label);	
			macro_push("\$t9");
		}
	;
	
log_op returns [int line, String text]:
	op=(AND | OR | LT | LTE | GT | GTE | EQ | NEQ) { $line = $op.line; $text = $op.text;};
	
bool_exp returns [int type]:
	^(op=log_op b1=bool_exp b2=bool_exp)
		{
			if($b1.type > 2 || $b2.type > 2)
			{
				printError("error: line " + $op.line + ": Array names cannot be an operand of logical operators");
			}
			else if($b1.type > 1 || $b2.type > 1)
			{
				printError("error: line " + $op.line + ": Strings cannot be an operand of logical operators");
			}
			else if($b1.type == 1 && $b2.type == 1)	{				// float - float
				$type = 1;
				macro_pop_float("\$f30");
				macro_pop_float("\$f28");
				floatLogical($op.text);
			}
			else if($b1.type == 1 && $b2.type == 0) {				// float - int
				$type = 1;
				macro_pop("\$t9");
				macro_pop_float("\$f28");
				writer.println("\tmtc1\t\$t9, \$f30");
				writer.println("\tcvt.s.w\t\$f30, \$f30");
				floatLogical($op.text);
			}
			else if($b1.type == 0 && $b2.type == 1) {				// int - float
				$type = 1;
				macro_pop_float("\$f30");
				macro_pop("\$t8");
				writer.println("\tmtc1\t\$t8, \$f28");
				writer.println("\tcvt.s.w\t\$f28, \$f28");
				floatLogical($op.text);
			}
			else {													// int - int
				$type = 0;
				macro_pop("\$t9");
				macro_pop("\$t8");
				integerLogical($op.text);
			}
		}
		
	| v=value[null, 0, null] { $type = $v.type; }
	| ^(NOT b=bool_exp)
		{ 
			// TODO
			if($b.type > 1)
				printError("Not operator can be applied only to int and float");
			else {
				if($b.type == 1) {
					macro_pop_float("\$f30");
					writer.println("\tcvt.w.s\t\$f30, \$f30");
					writer.println("\tmfc1\t\$t9, \$f30");
					writer.println("\tsne\t\$t9, \$t9, 0");					
					writer.println("\txori\t\$t9, \$t9, 1");
					writer.println("\tmtc1\t\$t9, \$f30");
					writer.println("\tcvt.s.w\t\$f30, \$f30");
					macro_push_float("\$f30");
				}
				else {
					macro_pop("\$t9");
					writer.println("\tsne\t\$t9, \$t9, 0");
					writer.println("\txori\t\$t9, \$t9, 1");
					macro_push("\$t9");
				}
				$type = $b.type;
			}
		}
	;

if_stmt
	@init {
			String elseLabel = "LC" + Integer.toString(labelCounter++);
			String fiLabel = "LC" + Integer.toString(labelCounter++);
	}
	:
	^(IF b=bool_exp
		{
			if($b.type == 0) {
				macro_pop("\$t9");
				writer.println("\tbeqz\t\$t9, " + elseLabel);
			}
			else {
				macro_pop_float("\$f30");
				writer.println("\tli.s\t\$f28, 0.0");
				writer.println("\tc.eq.s\t\$f30, \$f28");
				writer.println("\tbc1t\t" + elseLabel);
			}
		}
	s1=stmt
		{
			writer.println("\tj\t" + fiLabel);
			writer.println(elseLabel + ":");
		}
	s2=stmt?)
		{
			writer.println(fiLabel + ":");
		}
	;

for_stmt
	@init {
		String loopLabel = "LC" + Integer.toString(labelCounter++);
		String endLabel = "LC" + Integer.toString(labelCounter++);
	}
	:
	^(FOR ^(INIT assign_stmt[null, 0, null]?)
	{
		writer.println(loopLabel + ":");
	}
	^(COND b=bool_exp?)
	{
		if($b.type == 0) {
			macro_pop("\$t9");
			writer.println("\tbeqz\t\$t9, " + endLabel);			
		}
		else {
			macro_pop_float("\$f30");
			writer.println("\tli.s\t\$f28, 0.0");
			writer.println("\tc.eq.s\t\$f30, \$f28");
			writer.println("\tbc1t\t" + endLabel);
		}
	}
	stmt
	^(INC assign_stmt[null, 0, null]?)
	{
		writer.println("\tj\t" + loopLabel);
		writer.println(endLabel + ":");
	}
	);
	
while_stmt
	@init {
		String loopLabel = "LC" + Integer.toString(labelCounter++);
		String endLabel = "LC" + Integer.toString(labelCounter++);
	}
	:
	^(WHILE
	{
		writer.println(loopLabel + ":");
	} 
	b=bool_exp 
	{
		if($b.type == 0) {
			macro_pop("\$t9");
			writer.println("\tbeqz\t\$t9, " + endLabel);			
		}
		else {
			macro_pop_float("\$f30");
			writer.println("\tli.s\t\$f28, 0.0");
			writer.println("\tc.eq.s\t\$f30, \$f28");
			writer.println("\tbc1t\t" + endLabel);		
		}
	}
	stmt
	{
		writer.println("\tj\t" + loopLabel);
		writer.println(endLabel + ":");
	}
	);
	
forar_stmt
	options {
  		memoize = true;
	}
	@init {
		Symbol sym = null;
		int disp = 0;
		String loopLabel = "LC" + Integer.toString(labelCounter++);
		String endLabel = "LC" + Integer.toString(labelCounter++);
	}:
	^(FORAR id=ID i2=ID
	{
		sym = $func::table.getSymbol($id.text);
		
		if(sym == null)
			printError("error: line " + $id.line + ": Variable \'" + $id.text + "\' undeclared");
		else {
			if(sym.getType() < 3) {
				printError("error: line " + $id.line + ": forar statement is defined on only arrays");
			}
		}
		if(sym.isArg()) {
			disp = ($func::table.getArgNum()-sym.getNumber()+1)*4;		
		}
		else {
			disp = (sym.getNumber()-$func::table.getArgNum()+1)*(-4);
		}
		writer.print("\tla\t\$s0, ");
		writer.print(Integer.toString(disp));
		writer.println("(\$fp)");
		if(sym.isArg()) {
			writer.println("\tlw\t\$s0, (\$s0)");
		}
		writer.println("\tmove\t\$a3, \$s0");
		writer.println("\tli\t\$a2, " + Integer.toString(sym.getSize()));
		writer.println(loopLabel + ":");
		writer.println("\tbeqz\t\$a2, " + endLabel);
	}
	((assign_stmt[null, 0, null]) => assign_stmt[null, 0, null] | value[$i2.text, sym.getType()-3, "\$a3"]))
	{
		writer.println("\taddi\t\$a3, -4");
		writer.println("\taddi\t\$a2, -1");
		writer.println("\tj\t" + loopLabel);
		writer.println(endLabel + ":");
	}
	;

assign_stmt[String var, int varType, String addr]
	@init {
		Symbol sym = null;
		int disp = 0;
	}
	:
	^(ASSIGN (id=ID  v=value[null, 0, null]
				{
					sym = $func::table.getSymbol($id.text);
					int ltype;
					
					if(sym == null)
						printError("error: line " + $id.line + ": Variable \'" + $id.text + "\' undeclared");
					else
					{
						ltype = sym.getType();
						
						if(!(ltype == $v.type || (ltype < 2 && $v.type < 2) || (ltype > 2 && $v.type > 2 && ltype < 5 && $v.type < 5)))
							printError("error: line " + $id.line + ": Invalid conversion from \'" + printType($v.type) + "\' to \'" + printType(ltype) + "\'");
						else {
							if(sym.isArg()) {
								disp = ($func::table.getArgNum()-sym.getNumber()+1)*4;		
							}
							else {
								disp = (sym.getNumber()-$func::table.getArgNum()+1)*(-4);
							}	
							switch(ltype) {
								case 0:
									if($v.type == 1) {
										macro_pop_float("\$f30");
										writer.println("\tcvt.w.s\t\$f30, \$f30");
										writer.println("\tmfc1\t\$t9, \$f30");
									}
									else {
										macro_pop("\$t9");
									}
									writer.println("\tsw\t\$t9, " + Integer.toString(disp) + "(\$fp)");
									break;
								case 1:
									macro_pop_float("\$f30");
									if($v.type == 0) {
										writer.println("\tcvt.s.w\t\$f30, \$f30");
									}
									writer.println("\ts.s\t\$f30, " + Integer.toString(disp) + "(\$fp)");
									break;
								case 2:
									macro_pop("\$t9");
									writer.println("\tsw\t\$t9, " + Integer.toString(disp) + "(\$fp)");
									break;
								default:	
									int upperBound = sym.getSize() < $v.size ? sym.getSize() : $v.size;
									
									if(sym.getSize() != $v.size) {
										System.err.println("warning: line " + $id.line + ": In array assigment sizes of arrays are different ");
									}
									macro_pop("\$t9");
									String loopLabel = "LC" + Integer.toString(labelCounter++);
									String endLabel = "LC" + Integer.toString(labelCounter++);  
									writer.print("\tla\t\$t8, ");
									writer.print(Integer.toString(disp));
									writer.println("(\$fp)");
									if(sym.isArg()) {
										writer.println("\tlw\t\$t8, (\$t8)");
									}
									writer.println("\tli\t\$t7, " + Integer.toString(upperBound));
									writer.println(loopLabel + ":");
									writer.println("\tbeqz\t\$t7, " + endLabel);
									writer.println("\tl.s\t\$f28, (\$t9)");
									if(ltype == 4 && $v.type == 3) {				// float = int
										writer.println("\tcvt.s.w\t\$f28, \$f28");
									}
									else if(ltype == 3 && $v.type == 4) {			// int = float
										writer.println("\tcvt.w.s\t\$f28, \$f28");
									}
									writer.println("\ts.s\t\$f28, (\$t8)");
									writer.println("\taddi\t\$t8, \$t8, -4");
									writer.println("\taddi\t\$t9, \$t9, -4");
									writer.println("\taddi\t\$t7, \$t7, -1");
									writer.println("\tj\t" + loopLabel);
									writer.println(endLabel + ":");				
									break;
							}
						}
					}						
				}
			| ^(INDEX id=ID i=value[null, 0, null]) v=value[null, 0, null]
				{
					sym = $func::table.getSymbol($id.text);
					int ltype, rtype;
					if(sym == null)
						printError("error: line " + $id.line + ": Variable \'" + $id.text + "\' undeclared");
					else
					{
						ltype = sym.getType()-3;
						if($i.type != 0)
							printError("error: line " + $id.line + ": Array index must be an \'int\' instead of \'" + printType($v.type) + "\'");

						if(!(ltype == $v.type || (ltype < 2 && $v.type < 2)))
							printError("error: line " + $id.line + ": Invalid conversion from \'" + printType($v.type) + "\' to \'" + printType(ltype) + "\'");
						else {
							if(sym.isArg()) {
								disp = ($func::table.getArgNum()-sym.getNumber()+1)*4;		
							}
							else {
								disp = (sym.getNumber()-$func::table.getArgNum()+1)*(-4);
							}
							writer.print("\tla\t\$s0, ");
							writer.print(Integer.toString(disp));
							writer.println("(\$fp)");
							if(sym.isArg()) {
								writer.println("\tlw\t\$s0, (\$s0)");
							}
							macro_pop("\$t9");
							macro_pop("\$t8");
							writer.println("\tsub\t\$t8, \$t8, 1");
							writer.println("\tmul\t\$s1, \$t8, 4");
							writer.println("\tsub\t\$s0, \$s0, \$s1");
							switch(ltype) {
								case 0:
									if($v.type == 1) {
										writer.println("\tmtc1\t\$t9, \$f30");
										writer.println("\tcvt.w.s\t\$f30, \$f30");
										writer.println("\tmfc1\t\$t9, \$f30");
									}
									writer.println("\tsw\t\$t9, (\$s0)");
									break;
								case 1:
									if($v.type == 0) {
										writer.println("\tmtc1\t\$t9, \$f30");
										writer.println("\tcvt.s.w\t\$f30, \$f30");
									}
									writer.println("\ts.s\t\$f30, (\$s0)");
									break;
								case 2:
									writer.println("\tsw\t\$t9, (\$s0)");
									break;
							}
						}
					}						
				}
				)
	)
			;

return_stmt:
	^(r=RETURN v=value[null, 0, null])
		{
			int retType = $func::table.getReturnType();
			String funcName = $func::table.getID();
			
			if(!(retType == $v.type || (retType < 2 && $v.type < 2)))
				printError("error: line " + $r.line + ": In function \'" + funcName + "\' invalid conversion from \'" + printType($v.type) + "\' to \'" + printType(retType) + "\' for return value");
				
			$func::hasReturn = true;
		
			if(retType == 1) {	
				macro_pop_float("\$f30");
				writer.println("\tmov.s\t\$f0, \$f30");
			}
			else {	
				macro_pop("\$t9");
				writer.println("\tmove\t\$v0, \$t9");
			}
			restore_callee_save();			
			macro_leave();
			macro_ret();
		}
	;
	
stmt
	options {
  		k = 2;
	}
	:
	^(SINGLE_STMT (value[null, 0, null] | if_stmt | for_stmt | while_stmt | forar_stmt | assign_stmt[null, 0, null] | return_stmt)) | ^(BLOCK stmt*);