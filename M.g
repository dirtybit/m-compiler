grammar M;

options {
  language = Java;
  output = AST;
  k = 1;
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
}

@members {
	private HashMap functionTable = new HashMap<String, ScopeTable>();
	private boolean hasError = false;
	
	public HashMap getFunctionTable() {
		return functionTable;
	}
	
	public boolean hasError() {
		return hasError;
	}
	
	private void printError(String errMsg) {
		hasError = true;
		System.err.println(errMsg);
	}
	
	public int typeConvert(String t) {
		if(t.equals("int"))
			return 0;
		else if(t.equals("float"))
			return 1;
		else if(t.equals("string"))
			return 2;
		else if(t.equals("array"))
			return 3;
		else
			return -1;
	}
		
	public String getErrorHeader(RecognitionException e) {
		if ( getSourceName()!=null )
			return getSourceName()+" line "+e.line+":"+e.charPositionInLine;

			return "error: line "+e.line+":";
	}
}

@lexer::header {
	package mcompiler;
}

// Parser Rules
prog
	@after {
		if(!functionTable.containsKey("main"))
		{
			printError("error: Valid M code must have \'main\' function");
		}	
	}
	:
	func+
	-> ^(PROG func+)
	;

	

array_type returns [int val]:
	ARRAY st=SIMPLE_TYPE {$val = 3 + typeConvert($st.text);};

type returns [int t]:
	st=SIMPLE_TYPE {$t = typeConvert($st.text); }| at=array_type {$t = $at.val;};

func
	scope {
		ScopeTable table;
	}
	@init { 
		$func::table = new ScopeTable(); 
	}
	@after {
		$func::table.setReturnType(typeConvert($rtype.text));
		$func::table.setID($fname.text);
		functionTable.put($fname.text, $func::table);
	}
	:		// type ve var-decl sembol table a
	FUN rtype=type fname=ID LPARENTH arg* RPARENTH LBRACE var_decl* RBRACE stmt FUNREV
	-> ^(FUN type ID arg* var_decl* stmt)
	;

arg:
	ARG_KEY^ type id=ID 
	{
		$func::table.addArgType($type.t);
		$func::table.addArgName($id.text);
		if(!$func::table.addSymbol(new Symbol($id.text, $type.t, 0, true)))
			printError("error: line " + $id.line + ": Predefined variable: " + $id.text);
	}
	;
	
var_decl:
	VAR_KEY^ (normal_var | array_var);
	
normal_var:
	st=SIMPLE_TYPE (id=ID SEMICOLON! 
					{
						if(!$func::table.addSymbol(new Symbol($id.text, typeConvert($st.text), 0)))
							printError("error: line " + $id.line + ": Predefined variable: " + $id.text);
					}
				| LBRACE! ids+=ID+ RBRACE!
					{
						for(int i=0; i < $ids.size(); i++)
							if(!$func::table.addSymbol(new Symbol(((Token)$ids.get(i)).getText(), typeConvert($st.text), 0)))
								printError("error: line " + ((Token)$ids.get(i)).getLine() + ": Predefined variable: " + ((Token)$ids.get(i)).getText());
					}
				)
	;
	
array_var:
	at=array_type id=ID LBRACKET! i=INT RBRACKET! SEMICOLON!
	{
		if(!$func::table.addSymbol(new Symbol($id.text, $at.val, Integer.parseInt($i.text))))
			printError("error: line " + $id.line + ": Predefined variable: " + $id.text);
	}
	;

func_call:
	id=ID LPARENTH (value (COMMA value)*)? RPARENTH -> ^(FUNC_CALL ID value*)
	| INPUT LPARENTH ID (RPARENTH -> ^(FUNC_CALL INPUT ID) | LBRACKET value RBRACKET RPARENTH -> ^(FUNC_CALL INPUT ^(INDEX ID value)))
	| OUTPUT LPARENTH value RPARENTH -> ^(FUNC_CALL OUTPUT value)
	;
		
value:
	mult_expr ((MINUS^ | PLUS^) mult_expr)*;
	
mult_expr:
	single_expr ((MULT^ | DIV^) single_expr)*;
	
single_expr								
	options {
  		k = 2;
	}
	:
	ID | ID LBRACKET value RBRACKET -> ^(INDEX ID value) | INT | FLOAT | func_call
	| LPARENTH! value RPARENTH! | MINUS single_expr -> ^(NEGATE single_expr) | STRING
	;
	
log_op:
	LT | LTE | GT | GTE | EQ | NEQ;
	
bool_exp:
	and_expr (OR^ and_expr)*;
	
and_expr:
	comp_expr (AND^ comp_expr)*;
	
comp_expr:
	bool (log_op^ bool)?;
	
bool
	options {
  		memoize = true;
	} :
	NOT^ bool | ((value) => value | LPARENTH! bool_exp RPARENTH!);	

if_stmt:
	IF LPARENTH bool_exp RPARENTH stmt 
	(IFREV -> ^(IF bool_exp  stmt) | ELSE stmt IFREV -> ^(IF bool_exp  stmt stmt))
	;
	
for_stmt:
	FOR LPARENTH a1=assignment? SEMICOLON bool_exp? SEMICOLON a2=assignment? RPARENTH stmt FORREV
	-> ^(FOR ^(INIT $a1?) ^(COND bool_exp?) stmt ^(INC $a2?))
	;
	
while_stmt:
	WHILE LPARENTH bool_exp RPARENTH stmt WHILEREV
	-> ^(WHILE bool_exp  stmt)
	;
	
forar_stmt
	options {
  		memoize = true;
	} :
	FORAR^ ID id=ID ((assignment) => assignment | value) FORARREV!
	{
		if($func::table.getSymbol($id.text) != null)
			printError("error: line " + $id.line + ": Binding variable \'" + $id.text + "\' is defined before");
	}
	;

return_stmt:
	RETURN^ value SEMICOLON!;
	
stmt:
	(assign_stmt) => assign_stmt -> ^(SINGLE_STMT assign_stmt) 
	| if_stmt -> ^(SINGLE_STMT if_stmt) 
	| for_stmt -> ^(SINGLE_STMT for_stmt) 
	| while_stmt -> ^(SINGLE_STMT while_stmt)
	| forar_stmt -> ^(SINGLE_STMT forar_stmt)
	| value SEMICOLON -> ^(SINGLE_STMT value)
	| return_stmt -> ^(SINGLE_STMT return_stmt)
	| LBRACE stmt* RBRACE -> ^(BLOCK stmt*);

assign_stmt:
	assignment SEMICOLON!;

assignment:
	ID (ASSIGN value -> ^(ASSIGN ID value) | LBRACKET value RBRACKET ASSIGN value  -> ^(ASSIGN ^(INDEX ID value) value));
	

// Lexer Rules
NEWLINE: ('\r'? '\n')+ { $channel = HIDDEN; };
WHITESPACE: (' ' | '\t')+ { $channel = HIDDEN; };
COMMENT: '%' ~('\r' | '\n')* NEWLINE { $channel = HIDDEN; };
fragment LETTER: 'A' .. 'Z' | 'a' .. 'z';
fragment DIGIT: '0' .. '9';
fragment UNDERSCORE: '_';
SIMPLE_TYPE: 'float' | 'int' | 'string';
STRING : '\'' (' ' .. '$' | '&' | '(' .. '[' | ']' .. '~' | '\\%' | '\\t' | '\\n')* '\''; 
INPUT: 'input';
OUTPUT: 'output';
ARG_KEY: 'arg';
VAR_KEY: 'var';
COMMA: ',';
SEMICOLON: ';';
PERIOD: '.';
LPARENTH: '(';
RPARENTH: ')';
LBRACKET: '[';
RBRACKET: ']';
LBRACE: '{';
RBRACE: '}';
AND: 'and';
OR: 'or';
NOT: 'not';
LT: '<';
LTE: '<=';
GT: '>';
GTE: '>=';
EQ:	'==';
NEQ: '!=';
ASSIGN: ':=';
RETURN: 'return';
MINUS: '-';
PLUS: '+';
MULT: '*';
DIV: '/';
FUN: 'fun';
FUNREV: 'nuf';
ARRAY: 'array';
IF: 'if';
ELSE: 'else';
IFREV: 'fi';
FOR: 'for';
FORREV: 'rof';
WHILE: 'while';
WHILEREV: 'elihw';
FORAR: 'forar';
FORARREV: 'rarof';
fragment EXP: 'E' | 'e';
INT: DIGIT+;
FLOAT: INT PERIOD INT (EXP (MINUS | PLUS)? INT)?; 
ID:	LETTER (LETTER | DIGIT | UNDERSCORE)*;
