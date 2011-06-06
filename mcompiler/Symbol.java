package mcompiler;


public class Symbol {

	private String ID;
	private int type;
	private int size;
	private int number;
	private boolean arg;
	
	public Symbol(String iD, int type, int size) {
		ID = iD;
		this.type = type;
		this.size = size;
		number = -1;
		arg = false;
	}
	
	public Symbol(String iD, int type, int size, boolean arg) {
		ID = iD;
		this.type = type;
		this.size = size;
		this.arg = arg;
		number = -1;
	}
	
	public boolean isArg() {
		return arg;
	}
	
	public void setNumber(int n) {
		number = n;
	}
	
	public int getNumber() {
		return number;
	}
	
	public int isArray() {
		return type < 3 ? 0 : 3;
	}

	public int getType() {
		return type;
	}

	public int getSize() {
		return size;
	}

	public void setSize(int s) {
		size = s;
	}

	public String getID() {
		return ID;
	}
	
	
}
