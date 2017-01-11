%{
	#include <stdio.h>
	#include <string.h>
	#include <stdlib.h>

	#define ID_NUMBER 10000 
	#define ASM_NUMBER 10000 
	#define REGISTER_NUMBER 5
	#define JUMP_NUMBER 1000000
	#define INIT_ERROR( arg ) printf("<line %d> ERROR: Nie zainicjalizowano zmiennej: '%s'\n", yylineno, arg );
	#define FAULT_USE_ERROR( arg ) printf("<line %d> ERROR: Niewłaściwe użycie zmiennej: '%s'\n", yylineno, arg );
	#define DECL_ERROR(arg) printf("<line %d> ERROR: nie zadeklarowano zmiennej '%s'\n", yylineno, arg );

	void printArrayTable();

	void yyerror(const char *s);
	void addId( char * name, int type, long long size, int temp );
	void addArrayId( char * name, int type, char * num );
	void addCode( char * name, int nrOfArg, int firstArg, int secArg );
	void saveRegister( int _register, long long num );
	void freeRegisters( );
	void addJump( int instrNumber );
	void editArgument( int codeNumber, int argNumber, int value );
	void removeId();
	void checkInit( int index );

	int checkVar( char * name );
	int getIdIndex( char * id );
	long long stringToNum( char * num );
	int findRegister( );
	int findOccupiedRegister( );
	int getJump();
	int yylex();

	typedef struct{
		char * name;
		int mem;
		int idType; // 1 - Number, 2 - array
		long long size;
		int initialized;
		int temp;
	} identifier;

	typedef struct{
		identifier * tab[ ID_NUMBER ];
		int index;
	} identifiersTable;

	typedef struct{
		char* instr;
		int nrOfArg;
		int args[ 2 ];
	} instruction;

	typedef struct{ 
		instruction* tab[ ASM_NUMBER ];
		int index; 
	} intructionsTable;

	typedef struct{
		int tab[ JUMP_NUMBER ];
		int top;
	} jumpStack;


	int yylineno;
	int memoryIndex;
	int fault;
	int registers[ 5 ];
	int instrCounter;

	identifiersTable idTab;
	intructionsTable asmTab;
	jumpStack js;

%}

%union{
	struct{
		char * string;
		long long num;
		int type; // 1 - number ( literal ), 2 - variable
		int _register;
	}  data;
}

%type <data> value
%type <data> identifier
%type <data> expression
%type <data> condition

%token <data> NUM
%token <data> ID

%token WHILE
%token DO
%token ENDWHILE

%token FOR
%token FROM
%token TO
%token DOWNTO
%token ENDFOR

%token VAR
%token BEG
%token END

%token WRITE
%token READ

%token IF
%token THEN
%token ELSE
%token ENDIF

%token SKIP

%token PLUS
%token MINUS
%token DIV	
%token MULT
%token MOD

%token EQ
%token UNEQ
%token MOREEQ
%token LESSEQ
%token MORE 
%token LESS

%token ASG

%token OPN
%token CLS

%token SEM


%%

program : VAR vdeclarations BEG commands END
	{
		addCode("HALT", 0, 0 ,0 );
	}

vdeclarations: 
	vdeclarations ID
	{
		if( checkVar( $2.string ) ){
			addId( $2.string, 1, 1, 1 );
		}
	}
	| vdeclarations ID OPN NUM CLS
	{
		if( checkVar( $2.string ) ){
			addArrayId( $2.string, 2, $4.string );
		}
	}
	|

commands : commands command
	| command

command : 
	identifier ASG expression SEM
	{
		int index = getIdIndex( $1.string );

		if( index != - 1 ){
			if( idTab.tab[ index ]->temp == 1 ){
			
				addCode("COPY", 1, $1._register, 0 );
				addCode("STORE", 1, $3._register, 0 );
				
				registers[ $3._register ] = 0;
				registers[ $1._register ] = 0; 

				idTab.tab[ index ]->initialized = 1;
			}
			else{
				printf("<line %d> ERROR: Próba zmiany zmiennej sterującej wewnątrz pętli: '%s'\n", yylineno, $1.string );
			}
		}
		else{
			freeRegisters();
		}

	}
	| IF condition 
	{
		int reg = $2._register;

		addCode("JZERO", 2, reg, -1 );
		int backJump = instrCounter - 1;
		addJump( backJump );
		registers[ reg ] = 0;

	}
	THEN commands ELSE
	{
		int backJump = getJump();
		editArgument( backJump, 2, instrCounter+1 );
		
		addCode( "JUMP", 1, -1 , 0 );
		backJump = instrCounter - 1 ;
		addJump( backJump );
	} 
	commands ENDIF
	{
		int backJump = getJump( );
		editArgument( backJump, 1, instrCounter );
	}
	| WHILE 
	{
		addJump(instrCounter);
	}
	condition
	{
		int reg = $3._register;
		registers[ reg ] = 0;
		addCode( "JZERO", 2, reg, -2 );
		addJump( instrCounter - 1 );
	} 
	DO commands 
	{
		int backJump = getJump();
		editArgument( backJump, 2, instrCounter+1 );
		backJump = getJump();
		addCode( "JUMP", 1, backJump, 0 );
	}
	ENDWHILE
	| FOR ID FROM value
	{
		int index1 = $4.type == 2 ? getIdIndex( $4.string ) : 1;
		addId( $2.string, 1, 1, 0 );

		if( index1 != -1 ){
			int index = getIdIndex( $2.string );

			idTab.tab[ index ]->initialized = 1;

			int reg = $4._register;

			if( $4.type == 2 ){
				addCode( "COPY", 1, reg, 0 );
				addCode( "LOAD", 1, reg, 0 );
			}

			saveRegister( 0, idTab.tab[ index ]->mem );

			addJump( instrCounter );
			addCode( "STORE", 1, reg, 0 );
		}
	} 
	TO value
	{
		int index2 = $7.type == 2 ? getIdIndex( $7.string ) : 1;

		if( index2 != -1 ){
			int reg1 = $4._register;
			int reg2 = $7._register;

			if( $7.type == 1 ){
				addCode( "ZERO", 1, 0, 0 );
				addCode( "STORE", 1, reg2, 0 );
			}
			else{
				addCode( "COPY", 1, reg2, 0 );
 			}
			
			addCode( "SUB", 1, reg1, 0 );
			addCode( "JZERO", 2, reg1, instrCounter+2 );
			addCode( "JUMP", 1, -1, 0 );

			addJump( instrCounter-1 );

			registers[ reg1 ] = 0;
			registers[ reg2 ] = 0;
		}
	}
	DO commands
	{	
		int index = getIdIndex( $2.string );
		int reg = $4._register;

		saveRegister( 0, idTab.tab[ index ]->mem );
		addCode( "LOAD", 1, reg, 0 );
		addCode( "INC", 1, reg, 0 );

		int backJump = getJump();
		editArgument( backJump, 1, instrCounter+1 );
		backJump = getJump();
		addCode( "JUMP", 1, backJump, 0 );	
	}
	ENDFOR{
		removeId();
	}
	| FOR ID FROM value 
	{
		int index1 = $4.type == 2 ? getIdIndex( $4.string ) : 1;
		addId( $2.string, 1, 1, 0 );

		if( index1 != -1 ){
			int index = getIdIndex( $2.string );

			idTab.tab[ index ]->initialized = 1;

			int reg = $4._register;

			if( $4.type == 2 ){
				addCode( "COPY", 1, reg, 0 );
				addCode( "LOAD", 1, reg, 0 );
			}

			saveRegister( 0, idTab.tab[ index ]->mem );
			addCode( "STORE", 1, reg, 0 );
			addCode( "ZERO", 1, 0, 0 );
			addCode( "STORE", 1, reg, 0 );

			addJump( instrCounter );
		}
	} 
	DOWNTO value
	{
		int index2 = $7.type == 2 ? getIdIndex( $7.string ) : 1;

		if( index2 != -1 ){
			int index = getIdIndex( $2.string );

			int reg1 = $4._register;
			int reg2 = $7._register;

			if( $7.type == 2 ){
				addCode( "COPY", 1, reg2, 0 );
				addCode( "LOAD", 1, reg2, 0 );
			}

			addCode( "ZERO", 1, 0, 0 );
			addCode( "SUB", 1, reg2, 0 );
			addCode( "JZERO", 2, reg2, instrCounter+2 );
			addCode( "JUMP", 1, -1, 0 );
			addJump( instrCounter - 1 );

			registers[ reg1 ] = 0;
			registers[ reg2 ] = 0;

		}
	}
	DO commands 
	{
		int index = getIdIndex( $2.string );
		int reg = $4._register;

		saveRegister( 0, idTab.tab[ index ]->mem );
		addCode( "LOAD", 1, reg, 0 );
		addCode( "JZERO", 2, reg, instrCounter + 6 );
		addCode( "DEC", 1, reg, 0 );
		addCode( "STORE", 1, reg, 0 );
		addCode( "ZERO", 1, 0, 0 );
		addCode( "STORE", 1, reg, 0 );

		int backJump = getJump( );
		editArgument( backJump, 1, instrCounter + 1 );
		backJump = getJump();
		addCode( "JUMP", 1, backJump, 0 );

	}
	ENDFOR
	{
		removeId();
	}
	| READ identifier SEM
	{
		int reg = findRegister();
		addCode("GET", 1, reg, 0 );

		int index = getIdIndex( $2.string );
		if( index != -1 ){

			int regId = $2._register;

			addCode("COPY", 1, regId, 0 );
			addCode("STORE", 1, reg, 0 );

			if( idTab.tab[ index ]->idType == 1 )
				idTab.tab[ index ]->initialized = 1;

			registers[ regId ] = 0;

		}
	}
	| WRITE value SEM
	{
		if( $2.type == 1 ){
			
			addCode( "PUT", 1, $2._register, 0 );
			registers[ $2._register ] = 0;

		}
		else if( $2.type == 2){
			
			int index = getIdIndex( $2.string );

			if( index == -1 ){

			}
			else if( idTab.tab[ index ]->idType == 1 ){
				if( idTab.tab[ index ]->initialized == 1 ){
					
					addCode("COPY", 1, $2._register, 0 );
					addCode("LOAD", 1, $2._register, 0 );
					addCode("PUT", 1, $2._register, 0 );
					registers[ $2._register ] = 0;

				}
				else{
					INIT_ERROR( $2.string );
					fault = 1;
				}
			}
			else{
				addCode("COPY", 1, $2._register, 0 );
				addCode("LOAD", 1, $2._register, 0 );
				addCode("PUT", 1, $2._register, 0 );
				registers[ $2._register ] = 0;
			}
		
		}
	}
	| SKIP SEM

expression : 
	value
	{
		if( $1.type == 2 ){
			
			int index = getIdIndex( $1.string );
			int reg = $1._register;
			
			if( idTab.tab[ index ]->idType == 1 && idTab.tab[ index ]->initialized == 0 ){
				fault = 1;
				printf("<line %d> ERROR: Nie zainicjalizowano zmiennej: '%s'\n", yylineno, $1.string );
			}
			addCode("COPY", 1, reg, 0 );
			addCode("LOAD", 1, reg, 0 );
		
		}
		$$ = $1;
	}
	| value	PLUS value
	{
		int index1 = $1.type == 2 ? getIdIndex( $1.string ) : 1;
		int index2 = $3.type == 2 ? getIdIndex( $3.string ) : 1;

		if( index1 != -1 && index2 != -1 ){

			if( $1.type == 2 )
				checkInit(index1);
			if( $3.type == 2 )
				checkInit(index2);

			if( $1.type == 2 ){
				addCode("COPY", 1, $1._register, 0 );
				addCode("LOAD", 1, $1._register, 0 );
			}
			if( $3.type == 1 ){
				addCode("ZERO", 1, 0 , 0 );
				addCode("STORE", 1, $3._register, 0 );
			}
			else{
				addCode("COPY", 1, $3._register, 0 );
			}
			addCode("ADD", 1, $1._register, 0 );
			registers[ $3._register ] = 0;
			$$.type = 1;
			$$._register = $1._register;
		}
	}
	| value MINUS value
	{
		int index1 = $1.type == 2 ? getIdIndex( $1.string ) : 1;
		int index2 = $3.type == 2 ? getIdIndex( $3.string ) : 1;

		if( index1 != -1 && index2 != -1 ){
			if( $1.type == 2 )
				checkInit(index1);
			if( $3.type == 2 )
				checkInit(index2);

			if( $1.type == 2 ){
				addCode("COPY", 1, $1._register, 0 );
				addCode("LOAD", 1, $1._register, 0 );			
			}
			if( $3.type == 1 ){
				addCode("ZERO", 1, 0 , 0 );
				addCode("STORE", 1, $3._register, 0 );
			}
			else{
				addCode("COPY", 1, $3._register, 0 );
			}
			addCode("SUB", 1, $1._register, 0 );
			registers[ $3._register ] = 0;
			$$.type = 1;
			$$._register = $1._register;
		}
	}
	| value MULT value
	{
		int index1 = $1.type == 2 ? getIdIndex( $1.string ) : 1;
		int index2 = $3.type == 2 ? getIdIndex( $3.string ) : 1;

		if( index1 != -1 && index2 != -1 ){
	
			if( $1.type == 2 )
				checkInit(index1);
			if( $3.type == 2 )
				checkInit(index2);

			int regB = $3._register;
			int regResult = $1._register;
			int regHelp = findRegister(); 

			addCode("ZERO", 1, regHelp, 0 );
			addCode("ZERO", 1, 0, 0 );

			if( $3.type == 2 ){
				addCode("COPY", 1, regB, 0 );
				addCode("LOAD", 1, regB, 0 );
			}
			if( $1.type == 2 ){
				addCode("COPY", 1, regResult, 0 );
				addCode("LOAD", 1, regResult, 0 );
			}

			addCode( "ZERO", 1, 0, 0 );
			addCode( "JZERO", 2, regB, instrCounter+8 ); // @frost
			int backJump = instrCounter-1;
				addCode( "JODD", 2, regB, instrCounter+2 );
				addCode( "JUMP", 1, instrCounter+3, 0 );
				addCode( "STORE", 1, regResult, 0 );
				addCode( "ADD", 1, regHelp, 0 );
				addCode( "SHL", 1, regResult, 0 );
				addCode( "SHR", 1, regB, 0 );
			addCode( "JUMP", 1, backJump, 0 );

			$$._register = regHelp ;
			registers[ regB ] = 0;
			registers[ regResult ] = 0;

		}	
	}
	| value DIV value
	{
		int index1 = $1.type == 2 ? getIdIndex( $1.string ) : 1;
		int index2 = $3.type == 2 ? getIdIndex( $3.string ) : 1;

		if( index1 != -1 && index2 != -1 ){

			if( $1.type == 2 )
				checkInit(index1);
			if( $3.type == 2 )
				checkInit(index2);

			int reg1 = $1._register;
			int reg2 = $3._register; 
			int reg3 = findRegister();
			int reg4 = findOccupiedRegister();

			if( reg4 != - 1 ){
				addCode( "ZERO", 1, 0, 0 );
				addCode( "INC", 1, 0, 0 );
				addCode( "INC", 1, 0, 0 );
				addCode( "INC", 1, 0, 0 );
				addCode( "STORE", 1, reg4, 0 );
			}

			if( $1.type == 2 ){
				addCode( "COPY", 1, reg1, 0 );
				addCode( "LOAD", 1, reg1, 0 );
			}			
			if( $3.type == 2 ){
				addCode( "COPY", 1, reg2, 0 );
				addCode( "LOAD", 1, reg2, 0 );
			}


			addCode( "ZERO", 1, reg4, 0 );
			addCode( "INC", 1, reg4, 0 );

			addCode( "ZERO", 1, 0, 0 );
			addCode( "STORE", 1, reg1, 0 );

			addCode( "JUMP", 1, instrCounter+7, 0 ); 
			
			addCode( "JZERO", 2, reg3, instrCounter+2 ); 
				int backJump = instrCounter - 1;

				addCode( "JUMP", 1, instrCounter + 13 , 0 );
				
				addCode( "SHL", 1, reg2, 0 );
				addCode( "SHL", 1, reg4, 0 );

				addCode( "ZERO", 1, 0, 0 );
				addCode( "LOAD", 1, reg1, 0 );
				
				addCode( "INC", 1, 0, 0 );
				addCode( "STORE", 1, reg2, 0 );

				addCode( "SUB", 1, reg1, 0 );

				addCode( "LOAD", 1, reg3, 0 );
				addCode( "INC", 1, 0, 0 );
				addCode( "STORE", 1, reg1, 0 );
				addCode( "SUB", 1, reg3, 0 );

			addCode( "JUMP", 1, backJump, 0 ); 

			addCode( "ZERO", 1, 0, 0 );
			addCode( "LOAD", 1, reg1, 0 );
			addCode( "INC", 1, 0, 0 );
			addCode( "INC", 1, 0, 0 );
			addCode( "ZERO", 1, reg3, 0 );
			addCode( "STORE", 1, reg3, 0 );

			addCode( "JZERO", 2, reg4, instrCounter+22 );
				backJump = instrCounter - 1;

				addCode( "ZERO", 1, 0, 0 );
				addCode( "STORE", 1, reg2, 0 );
				addCode( "LOAD", 1, reg3, 0 );
				addCode( "INC", 1, 0, 0 );
				addCode( "STORE", 1, reg1, 0 );
				addCode( "SUB", 1, reg3, 0 );

				addCode( "JZERO", 2, reg3, instrCounter+2 );
				
				addCode( "JUMP", 1, instrCounter+11, 0 );

					addCode( "DEC", 1, 0, 0 );
					addCode( "SUB", 1, reg1, 0 );
					
					addCode( "INC", 1, 0, 0 );
					addCode( "INC", 1, 0, 0 );
					addCode( "LOAD", 1, reg3, 0 );

					addCode( "DEC", 1, 0, 0 );
					addCode( "STORE", 1, reg4, 0 );
					addCode( "ADD", 1, reg3, 0 );
				
					addCode( "INC", 1, 0, 0 );
					addCode( "STORE", 1, reg3, 0 );

				addCode( "SHR", 1, reg2, 0 );
				addCode( "SHR", 1, reg4, 0 );

			addCode( "JUMP", 1, backJump, 0 );

			addCode( "ZERO", 1, 0, 0 );
			addCode( "INC", 1, 0, 0 ); 
			addCode( "INC", 1, 0, 0 );
			addCode( "LOAD", 1, reg3, 0 );

			addCode( "INC", 1, 0, 0 );
			addCode( "LOAD", 1, reg4, 0 );

			$$._register = reg3;
			registers[ reg1 ] = 0;
			registers[ reg2 ] = 0; 
		}
	}
	| value MOD value
	{
		int index1 = $1.type == 2 ? getIdIndex( $1.string ) : 1;
		int index2 = $3.type == 2 ? getIdIndex( $3.string ) : 1;

		if( index1 != -1 && index2 != -1 ){

			if( $1.type == 2 )
				checkInit(index1);
			if( $3.type == 2 )
				checkInit(index2);

			int reg1 = $1._register;
			int reg2 = $3._register; 
			int reg3 = findRegister();
			int reg4 = findOccupiedRegister();

			if( reg4 != - 1 ){
				addCode( "ZERO", 1, 0, 0 );
				addCode( "INC", 1, 0, 0 );
				addCode( "INC", 1, 0, 0 );
				addCode( "INC", 1, 0, 0 );
				addCode( "STORE", 1, reg4, 0 );
			}

			if( $1.type == 2 ){
				addCode( "COPY", 1, reg1, 0 );
				addCode( "LOAD", 1, reg1, 0 );
			}			
			if( $3.type == 2 ){
				addCode( "COPY", 1, reg2, 0 );
				addCode( "LOAD", 1, reg2, 0 );
			}


			addCode( "ZERO", 1, reg4, 0 );
			addCode( "INC", 1, reg4, 0 );

			addCode( "ZERO", 1, 0, 0 );
			addCode( "STORE", 1, reg1, 0 );

			addCode( "JUMP", 1, instrCounter+7, 0 ); 
			
			addCode( "JZERO", 2, reg3, instrCounter+2 ); 
				int backJump = instrCounter - 1;

				addCode( "JUMP", 1, instrCounter + 13 , 0 );
				
				addCode( "SHL", 1, reg2, 0 );
				addCode( "SHL", 1, reg4, 0 );

				addCode( "ZERO", 1, 0, 0 );
				addCode( "LOAD", 1, reg1, 0 );
				
				addCode( "INC", 1, 0, 0 );
				addCode( "STORE", 1, reg2, 0 );

				addCode( "SUB", 1, reg1, 0 );

				addCode( "LOAD", 1, reg3, 0 );
				addCode( "INC", 1, 0, 0 );
				addCode( "STORE", 1, reg1, 0 );
				addCode( "SUB", 1, reg3, 0 );

			addCode( "JUMP", 1, backJump, 0 ); 

			addCode( "ZERO", 1, 0, 0 );
			addCode( "LOAD", 1, reg1, 0 );

			addCode( "JZERO", 2, reg4, instrCounter+14 );
				backJump = instrCounter - 1;

				addCode( "ZERO", 1, 0, 0 );
				addCode( "STORE", 1, reg2, 0 );
				addCode( "LOAD", 1, reg3, 0 );
				addCode( "INC", 1, 0, 0 );
				addCode( "STORE", 1, reg1, 0 );
				addCode( "SUB", 1, reg3, 0 );

				addCode( "JZERO", 2, reg3, instrCounter+2 );
				
					addCode( "JUMP", 1, instrCounter+3, 0 );

					addCode( "DEC", 1, 0, 0 );
					addCode( "SUB", 1, reg1, 0 );

				addCode( "SHR", 1, reg2, 0 );
				addCode( "SHR", 1, reg4, 0 );

			addCode( "JUMP", 1, backJump, 0 );

			addCode( "ZERO", 1, 0, 0 );
			addCode( "INC", 1, 0, 0 );
			addCode( "INC", 1, 0, 0 );
			addCode( "INC", 1, 0, 0 );
			addCode( "LOAD", 1, reg4, 0 );

			$$._register = reg1;
			registers[ reg3 ] = 0;
			registers[ reg2 ] = 0; 
		}
	}

condition : 
	value EQ value
	{
		int index1 = $1.type == 2 ? getIdIndex( $1.string ) : 1;
		int index2 = $3.type == 2 ? getIdIndex( $3.string ) : 1;

		if( index1 != -1 && index2 != -1 ){

			if( $1.type == 2 )
				checkInit(index1);
			if( $3.type == 2 )
				checkInit(index2);


			int reg1 = $1._register;
			int reg2 = $3._register;
			int reg3 = findRegister();

			if( $1.type == 2 ){
				addCode( "COPY", 1, reg1, 0 );
				addCode( "LOAD", 1, reg1, 0 );
			}
			if( $3.type == 2 ){
				addCode( "COPY", 1, reg2, 0 );
				addCode( "LOAD", 1, reg2, 0 );
			}

			addCode( "ZERO", 1, 0, 0 );
			addCode( "STORE", 1, reg1, 0 );

			addCode( "INC", 1, 0, 0 );
			addCode( "STORE", 1, reg2, 0 );

			addCode( "SUB", 1, reg1, 0 );

			addCode( "DEC", 1, 0, 0 );

			addCode( "SUB", 1, reg2, 0 );

			addCode( "JZERO", 2, reg1, instrCounter+2 );
			addCode( "JUMP", 1, instrCounter+2, 0 );
			addCode( "JZERO", 2, reg2, instrCounter+3 );
			addCode( "ZERO", 1, reg2, 0 );
			addCode( "JUMP", 1, instrCounter+2, 0 );
			addCode( "INC", 1, reg2, 0 );

			$$._register = reg2;
			registers[ reg1 ] = 0;


		}
	}
	| value UNEQ value
	{		
		int index1 = $1.type == 2 ? getIdIndex( $1.string ) : 1;
		int index2 = $3.type == 2 ? getIdIndex( $3.string ) : 1;

		if( index1 != -1 && index2 != -1 ){

			if( $1.type == 2 )
				checkInit(index1);
			if( $3.type == 2 )
				checkInit(index2);

			int reg1 = $1._register;
			int reg2 = $3._register;

			if( $1.type == 2 ){
				addCode( "COPY", 1, reg1, 0 );
				addCode( "LOAD", 1, reg1, 0 );
			}
			if( $3.type == 2){
				addCode( "COPY", 1, reg2, 0 );
				addCode( "LOAD", 1, reg2, 0 );
			}

			addCode( "ZERO", 1, 0, 0 );
			addCode( "STORE", 1, reg1, 0 );

			addCode( "INC", 1, 0, 0 );
			addCode( "STORE", 1, reg2, 0 );
			
			addCode( "SUB", 1, reg1, 0 );
			addCode( "DEC", 1, 0, 0 );
			addCode( "SUB", 1, reg2, 0 );

			addCode( "JZERO", 2, reg1, instrCounter+2 );
			addCode( "JUMP", 1, instrCounter+3, 0 );
			addCode( "JZERO", 2, reg2, instrCounter+4 );
			addCode( "JUMP", 1, instrCounter+3, 0 );
			addCode( "ZERO", 1, reg2, 0 );
			addCode( "INC", 1, reg2, 0 );

			$$._register = reg2;
			registers[ reg1 ] = 0;

		}
	}
	| value LESS value
	{
		int index1 = $1.type == 2 ? getIdIndex( $1.string ) : 1;
		int index2 = $3.type == 2 ? getIdIndex( $3.string ) : 1;

		if( index1 != -1 && index2 != -1 ){

			if( $1.type == 2 )
				checkInit(index1);
			if( $3.type == 2 )
				checkInit(index2);

			int reg1 = $1._register;
			int reg2 = $3._register;

			if( $3.type == 2 ){
				addCode( "COPY", 1, reg2, 0 );
				addCode( "LOAD", 1, reg2, 0 );
			} 
			if( $1.type == 1 ){
				addCode( "ZERO", 1, 0, 0 );
				addCode( "STORE", 1, reg1, 0 );
			}
			else{
				addCode( "COPY", 1, reg1, 0 );
			}

			addCode( "SUB", 1, reg2, 0 );

			registers[ reg1 ] = 0;
			$$._register = reg2;

		}
	}
	| value MORE value
	{	
		int index1 = $1.type == 2 ? getIdIndex( $1.string ) : 1;
		int index2 = $3.type == 2 ? getIdIndex( $3.string ) : 1;

		if( index1 != -1 && index2 != -1 ){

			if( $1.type == 2 )
				checkInit(index1);
			if( $3.type == 2 )
				checkInit(index2);

			int reg1 = $1._register;
			int reg2 = $3._register;

			if( $1.type == 2 ){
				addCode( "COPY", 1, reg1, 0 );
				addCode( "LOAD", 1, reg1, 0 );
			}
			if( $3.type == 1 ){
				addCode( "ZERO", 1, 0, 0 );
				addCode( "STORE", 1, reg2, 0 );
			}
			else{ 
				addCode( "COPY", 1, reg2, 0 );
			}

			addCode( "SUB", 1, reg1, 0 );

			$$._register = reg1;
			registers[ reg2 ] = 0;
		}
	}
	| value LESSEQ value
	{
		int index1 = $1.type == 2 ? getIdIndex( $1.string ) : 1;
		int index2 = $3.type == 2 ? getIdIndex( $3.string ) : 1;

		if( index1 != -1 && index2 != -1 ){

			if( $1.type == 2 )
				checkInit(index1);
			if( $3.type == 2 )
				checkInit(index2);

			int reg1 = $1._register;
			int reg2 = $3._register;

			if( $1.type == 2 ){
				addCode( "COPY", 1, 0, 0 );
				addCode( "LOAD", 1, reg1, 0 );
			}
			if( $3.type == 1 ){
				addCode( "ZERO", 1, 0, 0 );
				addCode( "STORE", 1, reg2, 0 );
			}
			else{
				addCode( "COPY", 1, reg2, 0 );
			}

			addCode( "SUB", 1, reg1, 0 );

			addCode( "JZERO", 2, reg1, instrCounter + 3 );
			addCode( "ZERO", 1, reg1, 0 );
			addCode( "JUMP", 1, instrCounter + 2, 0 );
			addCode( "INC", 1, reg1, 0 );

			$$._register = reg1;
			registers[ reg2 ] = 0;
		}
	}
	| value MOREEQ value
	{
		int index1 = $1.type == 2 ? getIdIndex( $1.string ) : 1;
		int index2 = $3.type == 2 ? getIdIndex( $3.string ) : 1;

		if( index1 != -1 && index2 != -1 ){

			if( $1.type == 2 )
				checkInit(index1);
			if( $3.type == 2 )
				checkInit(index2);

			int reg1 = $1._register;
			int reg2 = $3._register;

			if( $3.type == 2 ){
				addCode( "COPY", 1, reg2, 0 );
				addCode( "LOAD", 1, reg2, 0 );
			}
			if( $1.type == 1 ){
				addCode( "ZERO", 1, 0, 0 );
				addCode( "STORE", 1, reg1, 0 );
			}
			else{
				addCode( "COPY", 1, reg1, 0 );
			}

			addCode( "SUB", 1, reg2, 0 );

			addCode( "JZERO", 2, reg2, instrCounter+3 );
			addCode( "ZERO", 1, reg2, 0 );
			addCode( "JUMP", 1, instrCounter+2 , 0 );
			addCode( "INC", 1, reg2, 0 );

			$$._register = reg2;
			registers[ reg1 ] = 0;

		}
	}

value : 
	NUM
	{
		$1.type = 1;
		$1._register = findRegister();
		$$ = $1;
		long long temp = stringToNum( $1.string );
		saveRegister( $1._register, temp );
	}
	| identifier
	{
		$$ = $1;
	}

identifier : 
	ID
	{
		$1.type = 2;
		
		int index = getIdIndex( $1.string );

		if( index == -1 ){
			DECL_ERROR( $1.string );
			fault = 1;
		}
		else{
			if( idTab.tab[ index ]->idType == 1 ){
				int reg = findRegister();
				int mem = idTab.tab[ index ]->mem;
				saveRegister( reg, mem );

				$1._register = reg;
				registers[ reg ] = 1;

				$$ = $1;
			}
			else{
				FAULT_USE_ERROR( $1.string );
				fault = 1;
			}
		}

	}
	| ID OPN NUM CLS{
		$1.type = 2;
		$1.num = stringToNum( $3.string );
		int index = getIdIndex( $1.string );
		
		if( index != -1 ){
			if( idTab.tab[ index ]->idType == 2 ){
				if( $1.num < idTab.tab[ index ]->size ){
					int reg = findRegister();
					
					saveRegister( reg, $1.num );
					addCode("ZERO", 1, 0, 1 );
					addCode("STORE", 1, reg, 1 );
					saveRegister( reg, idTab.tab[ index ]->mem );

					addCode("ADD", 1, reg, 0 );

					$1._register = reg;
					$$ = $1;

				}
				else{
					printf("<line %d> ERROR: przekroczenie zakresu tablicy '%s'\n", yylineno, idTab.tab[ index ]->name );
					fault = 1;
				}
			}
			else{
				FAULT_USE_ERROR( $1.string );
			}
		}
		else{
			printf("<line %d> ERROR: nie zdefiniowano tablicy '%s'\n", yylineno, $1.string );
		}

	}
	| ID OPN ID CLS{
		// saving memory index to register
		$1.type = 2;
		int index = getIdIndex( $3.string );
		int index2 = getIdIndex( $1.string );

		if( index == -1 || index2 == -1 ){

			if( index == -1 )
				DECL_ERROR( $3.string );	
			if( index2 == -1 )
				DECL_ERROR( $1.string );
				
			fault = 1;
		}
		else{
			if( idTab.tab[ index ]->idType == 1 && idTab.tab[ index2 ]->idType == 2 ){
				if( idTab.tab[ index ]->initialized == 1 ){
					
					int reg = findRegister();
					int mem = idTab.tab[ index ]->mem;
					
					saveRegister( reg, mem );
					
					addCode("COPY", 1, reg, 0 );

					int reg2 = findRegister();
					mem = idTab.tab[ index2 ]->mem ;

					saveRegister( reg, mem );
					addCode("ADD", 1, reg, 0 );

					$1._register = reg;
					registers[ reg ] = 1;

					$$ = $1;

				}
				else{
					INIT_ERROR( $3.string );
					fault = 1;
				}
			}
			else{
				if( idTab.tab[ index ]->idType != 1 )
					FAULT_USE_ERROR( $3.string );
				if( idTab.tab[ index2 ]->idType != 2 )
					FAULT_USE_ERROR( $1.string );
				fault = 1;
			}
		}
	}
%%




void init(){
 
    idTab.index = 0;
    asmTab.index = 0;
	memoryIndex = 5;
	instrCounter = 0;
	fault = 0;

	js.top = 0 ;

	for( int i = 0 ; i < REGISTER_NUMBER ; ++i ){
		registers[ i ] = 0;
	}

}





void addCode( char * name,int nrOfArg, int firstArg, int secArg ){
	
	instruction * newCode = ( instruction * )malloc( sizeof( instruction ) );
	newCode->instr = ( char * )malloc( strlen( name ) );

	strcpy( newCode->instr, name );
	newCode->nrOfArg = nrOfArg;
	newCode->args[ 0 ] = firstArg;
	newCode->args[ 1 ] = secArg;

	asmTab.tab[ asmTab.index ] = newCode;
	asmTab.index++;

	instrCounter++;

}





void print( char * string ){
	
	int num = atoi( string );
	int counter = 0;
	int tab[ 30 ];

	while( num > 0 ){
		tab[ counter++ ] = num % 2;
		num = num / 2;
	}

	addCode( "ZERO", 1, 1, 0 );
	for( int i = 0 ; i < counter ; ++i ){
		if( tab[ 1 ] == 1 ){
			// TU SKOŃCZYŁEM
		}
		else{

		}

		if( i == counter - 1 ){

		}
	}

}





int findRegister( ){
	for( int i = 4 ; i >= 1 ; --i ){
		if( registers[ i ] == 0 )
			return i ;
	}
	return -1;
}




int findOccupiedRegister( ){
	for( int i = 4 ; i >= 1 ; --i ){
		if( registers[ i ] == 1 )
			return i ;
	}
	return -1;
}





void checkInit( int index ){
	if( idTab.tab[ index ]->idType == 1 ){
		if( idTab.tab[ index ]->initialized == 0 ){
			INIT_ERROR( idTab.tab[ index ]->name );
			fault = 1;
		}
	}
}





void saveRegister( int _register, long long num ){
	
	registers[ _register ] = 1;
	int counter = 0;
	int tab[ 30 ];

	while( num > 0 ){
		tab[ counter++ ] = num % 2;
		num = num / 2;
	}

	addCode( "ZERO", 1, _register, 0 );
	for( int i = counter-1 ; i >= 0 ; --i ){
		if( tab[ i ] == 1 ){
			addCode( "INC", 1, _register, 0 );
		}

		if( i != 0 ){
			addCode( "SHL", 1, _register, 0 );
		}
	}

}




long long stringToNum( char * num ){
	return atoll( num );
}





void freeRegisters( ){}






int checkVar( char * name ){
	
	int index = getIdIndex( name);
	if( index > -1 ){
		printf("<line: %d> ERROR: Nazwa '%s' została już użyta.\n", yylineno, name );
		return 0;
	}
	return 1;

}





void addJump( int instrNumber ){
	js.tab[ js.top ] = instrNumber;
	js.top++;
}





int getJump(){

	js.top--;
	
	int result = js.tab[ js.top ];

	return result;

}





void removeId(){
	idTab.index--;
	free( idTab.tab[ idTab.index ]->name );
	free( idTab.tab[ idTab.index] );
}





void editArgument( int codeNumber, int argNumber, int value ){
	asmTab.tab[ codeNumber ]->args[ argNumber - 1 ] = value;
}





void addId( char * name, int type, long long size, int temp ){
	
	identifier * id = ( identifier * )malloc( sizeof( identifier ) );
	
	id->name = ( char * ) malloc( strlen( name ) );
	strcpy( id->name, name );
	id->idType = type;
	id->mem = memoryIndex;
	id->size = size;
	id->initialized = 0;
	id->temp = temp;


	if( type == 1 ){
		memoryIndex++;
	}
	
	idTab.tab[ idTab.index ] = id;
	idTab.index++;

}





void addArrayId( char * name, int type, char * num ){
	
	long long number = stringToNum( num );
	addId( name, type, number, 1 );
	memoryIndex += number;

}





int getIdIndex( char * id ){
	
	for( int i = 0 ; i < idTab.index ; ++i ){
		if( strcmp( id, idTab.tab[ i ]->name ) == 0 ){
			return i;
		}
	}	
	return -1;

}




void printInstruction( int i, FILE * f){
	fprintf( f, "%s", asmTab.tab[ i ]->instr );
	for( int temp = 0 ; temp < asmTab.tab[ i ]->nrOfArg; ++temp ){
		fprintf(f, " %d", asmTab.tab[ i ]->args[ temp ] );
	}
	fprintf(f,"\n");
}




void parse( int argc, char * argv[] ){

	if( 1 ){ // DO ZMIANNY @frost
		
		init();
		yyparse();
		if( fault == 0 ){
		    FILE * f = fopen( argv[1], "w" );

		    if( f != NULL ){
				for( int i = 0 ; i < asmTab.index ; ++i ){
					//fprintf(f, "%d: ", i );
					printInstruction( i, f );
				}
			}
			else{
				printf("Nie udało się otworzyć pliku\n");
			}
		}

	}
	else{
		printf("~~~\n");
		printf("Wywołanie programu z nieodpowiednią ilością argumentów.\n");
		printf("~~~\n");
	}

}




void printArrayTable(){

	for( int i = 0 ; i < idTab.index ; ++i ){
		printf("\t%s\n",idTab.tab[ i ]->name);
		printf("\t%d\n",idTab.tab[ i ]->idType);
		printf("\t%d\n",idTab.tab[ i ]->mem);
		printf("\n");
	}

}

 



void yyerror(const char *s) { 
	printf("<line %d> ERROR: Błąd składni.\n", yylineno); 
	fault = 1;
}





int main( int argc, char * argv[] ){

	parse( argc, argv );
	return 0;

}






















































