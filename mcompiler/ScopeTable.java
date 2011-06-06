package mcompiler;

import java.util.ArrayList;
import java.util.HashMap;

public class ScopeTable {
	
	public final static int INT = 0;
	public final static int FLOAT = 1;
	public final static int STRING = 2;
	public final static int ARRAY = 3;
	private ArrayList<Integer> argList;
	private ArrayList<String> argNames;
	private int returnType;
	private String ID;
	public HashMap<String, Symbol> table;				// ********************************************
	private int symbolCounter;
	private int localSize;

	public ScopeTable() {
		argList = new ArrayList<Integer>();
		argNames = new ArrayList<String>();
		table = new HashMap<String, Symbol>();
		symbolCounter = 0;
		localSize = 0;
	}

	public ScopeTable(int returnType, String iD) {
		ID = iD;
		this.returnType = returnType;
		argList = new ArrayList<Integer>();
		argNames = new ArrayList<String>();
		table = new HashMap<String, Symbol>();
		symbolCounter = 0;
		localSize = 0;
	}

	public int getLocalSize() {
		return localSize;
	}

	public int getReturnType() {
		return returnType;
	}

	public String getID() {
		return ID;
	}
	
	public boolean addSymbol(Symbol s) {
		if(!table.containsKey(s.getID()))
		{
			s.setNumber(symbolCounter);
			table.put(s.getID(), s);
			if(!s.isArg()) {
				if(s.getSize() > 0)
				{
					localSize += s.getSize();
					symbolCounter += s.getSize();
				}
				else {
					localSize++;
					symbolCounter++;
				}
			}
			else
				symbolCounter++;
			
			return true;
		}
		else
			return false; //throw (new Exception());
	}
	
	public Symbol getSymbol(String id) {
		return table.get(id);
	}

	public int getArgType(int index) {
		return argList.get(index).intValue();
	}
	
	public String getArgName(int index) {
		return argNames.get(index);
	}

	public void addArgName(String t) {
		argNames.add(t);
	}
	
	public void addArgType(int t) {
		argList.add(new Integer(t));
	}
	
	public int getArgNum() {
		return argList.size();
	}
	
	public int getSymbolNum() {
		return table.size();
	}
	
	public void setReturnType(int returnType) {
		this.returnType = returnType;
	}

	public void setID(String iD) {
		ID = iD;
	}
	
	
	
}
