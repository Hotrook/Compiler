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
	void addId( char * name, long long type, long long size, long long glob );
	void addArrayId( char * name, long long type, char * num );
	void addCode( char * name, long long nrOfArg, long long firstArg, long long secArg );
	void saveRegister( long long _register, long long num );
	void freeRegisters( );
	void addJump( long long instrNumber );
	void editArgument( long long codeNumber, long long argNumber, long long value );
	void removeId();
	void checkInit( long long index );

	long long checkVar( char * name );
	long long getIdIndex( char * id );
	long long stringToNum( char * num );
	long long findRegister( );
	long long findOccupiedRegister( );
	long long getJump();
	long long yylex();

	typedef struct{
		char * name;
		long long mem;
		long long idType; // 1 - Number, 2 - array
		long long size;
		long long initialized;
		long long glob;
	} identifier;

	typedef struct{
		identifier * tab[ ID_NUMBER ];
		long long index;
	} identifiersTable;

	typedef struct{
		char* instr;
		long long nrOfArg;
		long long args[ 2 ];
	} instruction;

	typedef struct{ 
		instruction* tab[ ASM_NUMBER ];
		long long index; 
	} intructionsTable;

	typedef struct{
		long long tab[ JUMP_NUMBER ];
		long long top;
	} jumpStack;


	int yylineno;
	long long memoryIndex;
	long long fault;
	long long registers[ 5 ];
	long long instrCounter;

	identifiersTable idTab;
	intructionsTable asmTab;
	jumpStack js;

%}

%union{
	struct{
		char * string;
		long long num;
		long long type; // 1 - number ( literal ), 2 - variable
		long long _register;
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
		long long index = getIdIndex( $1.string );

		if( index != - 1 ){
			if( idTab.tab[ index ]->glob == 1 ){
			
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
		long long reg = $2._register;

		addCode("JZERO", 2, reg, -1 );
		long long backJump = instrCounter - 1;
		addJump( backJump );
		registers[ reg ] = 0;

	}
	THEN commands ELSE
	{
		long long backJump = getJump();
		editArgument( backJump, 2, instrCounter+1 );
		
		addCode( "JUMP", 1, -1 , 0 );
		backJump = instrCounter - 1 ;
		addJump( backJump );
	} 
	commands ENDIF
	{
		long long backJump = getJump( );
		editArgument( backJump, 1, instrCounter );
	}
	| WHILE 
	{
		addJump(instrCounter);
	}
	condition
	{
		long long reg = $3._register;
		registers[ reg ] = 0;
		addCode( "JZERO", 2, reg, -2 );
		addJump( instrCounter - 1 );
	} 
	DO commands 
	{
		long long backJump = getJump();
		editArgument( backJump, 2, instrCounter+1 );
		backJump = getJump();
		addCode( "JUMP", 1, backJump, 0 );
	}
	ENDWHILE
	| FOR ID FROM value TO value
	{
		long long index1 = $4.type == 2 ? getIdIndex( $4.string ) : 1;
		long long index2 = $6.type == 2 ? getIdIndex( $6.string ) : 1;

		addId( $2.string, 1, 1, 0 );
		long long index = getIdIndex( $2.string );
		idTab.tab[ index ]->initialized = 1;

		if( index1 != -1 && index2 != -1 ){

			if( $4.type == 2 )
				checkInit(index1);
			if( $6.type == 2 )
				checkInit(index2);
				
			long long reg1 = $4._register;
			long long reg2 = $6._register;
			long long reg3 = findRegister();

			if( $4.type == 1 ){
				addCode( "ZERO", 1, 0, 0 );
				addCode( "STORE", 1, reg1, 0 );
			}
			else{
				addCode( "COPY", 1, reg1, 0 );
			}
			addCode( "LOAD", 1, reg3, 0 );

			if( $6.type == 1 ){
				addCode( "ZERO", 1, 0, 0 );
				addCode( "STORE", 1, reg2, 0 );
			}
			else{
				addCode( "COPY", 1, reg2, 0 );
			}

			addCode( "SUB", 1, reg3, 0 );

			addCode( "JZERO", 2, reg3, instrCounter+2 );
			addCode( "JUMP" , 1, -1, 0 );
				addJump( instrCounter - 1 );

			if( $6.type == 2 ){
				addCode( "LOAD", 1, reg2, 0 );
			}
			if( $4.type == 1 ){
				addCode( "ZERO", 1, 0, 0 );
				addCode( "STORE", 1, reg1, 0 );
			}
			else{
				addCode( "COPY", 1, reg1, 0 );
			}

			addCode( "SUB", 1, reg2, 0 );
			addCode( "INC", 1, reg2, 0 );

			addCode( "LOAD", 1, reg1, 0 );
			saveRegister( 0 , idTab.tab[ index ]->mem );
			addCode( "STORE", 1, reg1, 0 );
			addCode( "INC", 1, 0, 0 );

			addCode( "JZERO", 2, reg2, -1 );
			addJump( instrCounter-1 );
			addCode( "STORE", 1, reg2, 0 );
			registers[ reg1 ] = 0;
			registers[ reg2 ] = 0;
			registers[ reg3 ] = 0;
		}
	}
	DO commands
	{	
		long long index = getIdIndex( $2.string );
		long long reg1 = $4._register;
		long long reg2 = $6._register;

		saveRegister( 0, idTab.tab[ index ]->mem );
		addCode( "LOAD", 1, reg1, 0 );
		addCode( "INC", 1, reg1, 0 );
		addCode( "STORE", 1, reg1, 0 );
		addCode( "INC", 1, 0, 0 );
		addCode( "LOAD", 1, reg2, 0 );
		addCode( "DEC", 1, reg2, 0 );

		long long backJump = getJump();
		editArgument( backJump, 2, instrCounter+1 );
		addCode( "JUMP", 1, backJump, 0 );	
		backJump = getJump();
		editArgument( backJump, 1, instrCounter );
	}
	ENDFOR{
		removeId();
	}
	| FOR ID FROM value DOWNTO value
	{
		long long index1 = $4.type == 2 ? getIdIndex( $4.string ) : 1;
		long long index2 = $6.type == 2 ? getIdIndex( $6.string ) : 1;

		addId( $2.string, 1, 1, 0 );

		if( index1 != -1 && index2 != -1 ){
			if( $4.type == 2 )
				checkInit(index1);
			if( $6.type == 2 )
				checkInit(index2);

			long long index = getIdIndex( $2.string );
			idTab.tab[ index ]->initialized = 1;

			long long reg1 = $4._register;
			long long reg2 = $6._register;
			long long reg3 = findRegister();

			if( $6.type == 1 ){
				addCode( "ZERO", 1, 0, 0 );
				addCode( "STORE", 1, reg2, 0 );
			}
			else{
				addCode( "COPY", 1, reg2, 0 );
			}
			addCode( "LOAD", 1, reg3, 0 );

			if( $4.type == 1 ){
				addCode( "ZERO", 1, 0, 0 );
				addCode( "STORE", 1, reg1, 0 );
			}
			else{
				addCode( "COPY", 1, reg1, 0 );
			}

			addCode( "SUB", 1, reg3, 0 );

			addCode( "JZERO", 2, reg3, instrCounter+2 );
			addCode( "JUMP", 1, -1, 0 );
				addJump( instrCounter - 1 );

			if( $4.type == 1 ){
				addCode( "ZERO", 1, 0, 0 );
				addCode( "STORE", 1, reg1, 0 );
			}
			else{
				addCode( "COPY", 1, reg1, 0 );
				addCode( "LOAD", 1, reg1, 0 );
			}

			addCode( "LOAD", 1, reg3, 0 );
			
			if( $6.type == 1 ){
				addCode( "ZERO", 1, 0, 0 );
				addCode( "STORE", 1, reg2, 0 );
			}
			else{
				addCode( "COPY", 1, reg2, 0 );
			}


			addCode( "SUB", 1, reg1, 0 );
			addCode( "INC", 1, reg1, 0 );
			saveRegister( 0, idTab.tab[ index ]->mem );
			addCode( "STORE", 1, reg3, 0 );
			addCode( "INC", 1, 0, 0 );

			addCode( "JZERO", 2, reg1, -1 );
				addJump( instrCounter - 1 );
			addCode( "STORE", 1, reg1, 0 );


			registers[ reg1 ] = 0;
			registers[ reg2 ] = 0;
			registers[ reg3 ] = 0; 

		}
		else{
			if( index1 == -1 )
				INIT_ERROR( $4.string )
			if( index2 == - 1 )
				INIT_ERROR( $6.string )
			fault = 0 ;
		}
	}
	DO commands 
	{
		long long index = getIdIndex( $2.string );
		long long reg1 = $4._register;

		saveRegister( 0, idTab.tab[ index ]->mem );
		addCode( "LOAD", 1, reg1, 0 );
		addCode( "DEC", 1, reg1, 0 );
		addCode( "STORE", 1, reg1, 0 );
		addCode( "INC", 1, 0, 0 );
		addCode( "LOAD", 1, reg1, 0 );
		addCode( "DEC", 1, reg1, 0 );

		long long backJump = getJump( );
		editArgument( backJump, 2, instrCounter + 1 );
		addCode( "JUMP", 1, backJump, 0 );
		backJump = getJump();
		editArgument( backJump, 1, instrCounter );
	}
	ENDFOR
	{
		removeId();
	}
	| READ identifier SEM
	{
		long long reg = findRegister();
		addCode("GET", 1, reg, 0 );

		long long index = getIdIndex( $2.string );
		if( index != -1 ){

			long long regId = $2._register;

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
			
			long long index = getIdIndex( $2.string );

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
			
			long long index = getIdIndex( $1.string );
			long long reg = $1._register;
			
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
		long long index1 = $1.type == 2 ? getIdIndex( $1.string ) : 1;
		long long index2 = $3.type == 2 ? getIdIndex( $3.string ) : 1;

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
		long long index1 = $1.type == 2 ? getIdIndex( $1.string ) : 1;
		long long index2 = $3.type == 2 ? getIdIndex( $3.string ) : 1;

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
		long long index1 = $1.type == 2 ? getIdIndex( $1.string ) : 1;
		long long index2 = $3.type == 2 ? getIdIndex( $3.string ) : 1;

		if( index1 != -1 && index2 != -1 ){
	
			if( $1.type == 2 )
				checkInit(index1);
			if( $3.type == 2 )
				checkInit(index2);

			long long regB = $3._register;
			long long regResult = $1._register;
			long long regHelp = findRegister(); 

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
			addCode( "JZERO", 2, regB, instrCounter+8 ); 
			long long backJump = instrCounter-1;
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
		long long index1 = $1.type == 2 ? getIdIndex( $1.string ) : 1;
		long long index2 = $3.type == 2 ? getIdIndex( $3.string ) : 1;

		if( index1 != -1 && index2 != -1 ){

			if( $1.type == 2 )
				checkInit(index1);
			if( $3.type == 2 )
				checkInit(index2);

			long long reg1 = $1._register;
			long long reg2 = $3._register; 
			long long reg4 = findRegister();

			if( $1.type == 2 ){
				addCode( "COPY", 1, reg1, 0 );
				addCode( "LOAD", 1, reg1, 0 );
			}			
			if( $3.type == 2 ){
				addCode( "COPY", 1, reg2, 0 );
				addCode( "LOAD", 1, reg2, 0 );
			}

			addCode( "JZERO", 2, reg2, instrCounter+2 );
				addJump( instrCounter - 1 );
			if( $3.type == 1 && stringToNum($3.string ) == 2){
				long long num = stringToNum( $3.string );
				addCode( "SHR", 1, reg1, 0 );

				$$._register = reg1;
				registers[ reg2 ] = 0;
				registers[ reg4 ] = 0; 
			}
			else{
			addCode( "ZERO", 1, 0, 0 );
			addCode( "INC", 1, 0, 0 );
			addCode( "INC", 1, 0, 0 );

			addCode( "ZERO", 1, reg4, 0 );
			addCode( "STORE", 1, reg4, 0 );
			addCode( "INC", 1, reg4, 0 );

			addCode( "ZERO", 1, 0, 0 );
			addCode( "STORE", 1, reg1, 0 );

			addCode( "INC", 1, 0, 0 );
			addCode( "STORE", 1, reg2, 0 );
			addCode( "DEC", 1, 0, 0 );
			addCode( "SUB", 1, reg2, 0 );
			addCode( "JZERO", 2, reg2, instrCounter + 2 );
			addCode( "JUMP", 1, instrCounter+50, 0 );

			addCode( "INC", 1, 0, 0 );
			addCode( "LOAD", 1, reg2, 0 );
			addCode( "JUMP", 1, instrCounter+2, 0 );

			
			addCode( "JZERO", 2, reg1, instrCounter+9 ); 
				long long backJump = instrCounter - 1;
				addCode( "SHL", 1, reg2, 0 );
				addCode( "SHL", 1, reg4, 0 );

				addCode( "ZERO", 1, 0, 0 );
				addCode( "LOAD", 1, reg1, 0 );
				
				addCode( "INC", 1, 0, 0 );
				addCode( "STORE", 1, reg2, 0 );

				addCode( "SUB", 1, reg1, 0 );

				addCode( "JUMP", 1, backJump, 0 ); 

			addCode( "ZERO", 1, 0, 0 );
			addCode( "SUB", 1, reg2, 0 );
			addCode( "JZERO", 2, reg2, instrCounter+6 );

			addCode( "INC", 1, 0, 0 );
			addCode( "LOAD", 1, reg2, 0 );
			
			addCode( "SHR", 1, reg2, 0 );
			addCode( "SHR", 1, reg4, 0 );

			addCode( "JUMP", 1, instrCounter+3, 0 );

			addCode( "INC", 1, 0, 0 );
			addCode( "LOAD", 1, reg2, 0 );

			addCode( "ZERO", 1, 0, 0 );
			addCode( "LOAD", 1, reg1, 0 );

			addCode( "JZERO", 2, reg4, instrCounter+25 );
				backJump = instrCounter - 1;

				addCode( "ZERO", 1, 0, 0 );
				addCode( "STORE", 1, reg2, 0 );
				addCode( "INC", 1, 0, 0 );
				addCode( "STORE", 1, reg1, 0 );
				addCode( "SUB", 1, reg2, 0 );

				addCode( "JZERO", 2, reg2, instrCounter+4 );
					addCode( "ZERO", 1, 0, 0 );
					addCode( "LOAD", 1, reg2, 0 );
				addCode( "JUMP", 1, instrCounter+13, 0 );

					addCode( "DEC", 1, 0, 0 );
					addCode( "SUB", 1, reg1, 0 );
					
					addCode( "INC", 1, 0, 0 );
					addCode( "INC", 1, 0, 0 );
					addCode( "LOAD", 1, reg2, 0 );

					addCode( "INC", 1, 0, 0 );
					addCode( "STORE", 1, reg4, 0 );
					addCode( "ADD", 1, reg2, 0 );
				
					addCode( "DEC", 1, 0, 0 );
					addCode( "STORE", 1, reg2, 0 );

					addCode( "ZERO", 1, 0, 0 );
					addCode( "LOAD", 1, reg2, 0 );

				addCode( "SHR", 1, reg2, 0 );
				addCode( "SHR", 1, reg4, 0 );

			addCode( "JUMP", 1, backJump, 0 );

			addCode( "ZERO", 1, 0, 0 );
			addCode( "INC", 1, 0, 0 ); 
			addCode( "INC", 1, 0, 0 );
			addCode( "LOAD", 1, reg2, 0 );


			$$._register = reg2;
			registers[ reg1 ] = 0;
			registers[ reg4 ] = 0; 
			}
			long long backJump = getJump();
			editArgument( backJump, 2, instrCounter );

		}
	}
	| value MOD value
	{
		long long index1 = $1.type == 2 ? getIdIndex( $1.string ) : 1;
		long long index2 = $3.type == 2 ? getIdIndex( $3.string ) : 1;

		if( index1 != -1 && index2 != -1 ){

			if( $1.type == 2 )
				checkInit(index1);
			if( $3.type == 2 )
				checkInit(index2);

			long long reg1 = $1._register;
			long long reg2 = $3._register; 
			long long reg3 = findRegister();

			if( $1.type == 2 ){
				addCode( "COPY", 1, reg1, 0 );
				addCode( "LOAD", 1, reg1, 0 );
			}			
			if( $3.type == 2 ){
				addCode( "COPY", 1, reg2, 0 );
				addCode( "LOAD", 1, reg2, 0 );
			}

			addCode( "JZERO", 2, reg2, -1 );
				addJump( instrCounter - 1 );
			addCode( "ZERO", 1, reg3, 0 );
			addCode( "INC", 1, reg3, 0 );

			addCode( "ZERO", 1, 0, 0 );
			addCode( "STORE", 1, reg1, 0 );

			addCode( "INC", 1, 0, 0 );
			addCode( "STORE", 1, reg2, 0 );
			addCode( "ZERO", 1, 0, 0 );
			addCode( "SUB", 1, reg2, 0 );
			
			addCode( "JZERO", 2, reg2, instrCounter + 2 );
			addCode( "JUMP", 1, instrCounter+36, 0 ); 
			addCode( "INC", 1, 0, 0 ); 
			addCode( "LOAD", 1, reg2, 0 );
			addCode( "JUMP", 1, instrCounter+2, 0 );

			addCode( "JZERO", 2, reg1, instrCounter+9 ); 
				long long backJump = instrCounter - 1;

				addCode( "SHL", 1, reg2, 0 );
				addCode( "SHL", 1, reg3, 0 );

				addCode( "ZERO", 1, 0, 0 );
				addCode( "LOAD", 1, reg1, 0 );
				
				addCode( "INC", 1, 0, 0 );
				addCode( "STORE", 1, reg2, 0 );

				addCode( "SUB", 1, reg1, 0 );

			addCode( "JUMP", 1, backJump, 0 ); 

			addCode( "ZERO", 1, 0, 0 );
			addCode( "SUB", 1, reg2, 0 );
			addCode( "JZERO", 2, reg2, instrCounter + 23 );

			addCode( "INC", 1, 0, 0 );
			addCode( "LOAD", 1, reg2, 0 );
			addCode( "SHR", 1, reg2, 0 );
			addCode( "SHR", 1, reg3, 0 );

			addCode( "ZERO", 1, 0, 0 );
			addCode( "LOAD", 1, reg1, 0 );

			addCode( "JZERO", 2, reg3, instrCounter+16 );
				backJump = instrCounter - 1;

				addCode( "ZERO", 1, 0, 0 );
				addCode( "STORE", 1, reg2, 0 );
				addCode( "INC", 1, 0, 0 );
				addCode( "STORE", 1, reg1, 0 );
				addCode( "SUB", 1, reg2, 0 );

				addCode( "JZERO", 2, reg2, instrCounter+4 );
				
					addCode( "DEC", 1, 0, 0 );
					addCode( "LOAD", 1, reg2, 0 );
					addCode( "JUMP", 1, instrCounter+4, 0 );

					addCode( "DEC", 1, 0, 0 );
					addCode( "LOAD", 1, reg2, 0 );
					addCode( "SUB", 1, reg1, 0 );

				addCode( "SHR", 1, reg2, 0 );
				addCode( "SHR", 1, reg3, 0 );

			addCode( "JUMP", 1, backJump, 0 );
			addCode( "JUMP", 1, instrCounter + 2, 0 );
			
			backJump = getJump();
			editArgument( backJump, 2, instrCounter );
			
			addCode( "ZERO", 1, reg1, 0 );

			$$._register = reg1;
			registers[ reg3 ] = 0;
			registers[ reg2 ] = 0; 
		}
	}

condition : 
	value EQ value
	{
		long long index1 = $1.type == 2 ? getIdIndex( $1.string ) : 1;
		long long index2 = $3.type == 2 ? getIdIndex( $3.string ) : 1;

		if( index1 != -1 && index2 != -1 ){

			if( $1.type == 2 )
				checkInit(index1);
			if( $3.type == 2 )
				checkInit(index2);


			long long reg1 = $1._register;
			long long reg2 = $3._register;
			long long reg3 = findRegister();

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
		long long index1 = $1.type == 2 ? getIdIndex( $1.string ) : 1;
		long long index2 = $3.type == 2 ? getIdIndex( $3.string ) : 1;

		if( index1 != -1 && index2 != -1 ){

			if( $1.type == 2 )
				checkInit(index1);
			if( $3.type == 2 )
				checkInit(index2);

			long long reg1 = $1._register;
			long long reg2 = $3._register;

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
		long long index1 = $1.type == 2 ? getIdIndex( $1.string ) : 1;
		long long index2 = $3.type == 2 ? getIdIndex( $3.string ) : 1;

		if( index1 != -1 && index2 != -1 ){

			if( $1.type == 2 )
				checkInit(index1);
			if( $3.type == 2 )
				checkInit(index2);

			long long reg1 = $1._register;
			long long reg2 = $3._register;

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
		long long index1 = $1.type == 2 ? getIdIndex( $1.string ) : 1;
		long long index2 = $3.type == 2 ? getIdIndex( $3.string ) : 1;

		if( index1 != -1 && index2 != -1 ){

			if( $1.type == 2 )
				checkInit(index1);
			if( $3.type == 2 )
				checkInit(index2);

			long long reg1 = $1._register;
			long long reg2 = $3._register;

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
		long long index1 = $1.type == 2 ? getIdIndex( $1.string ) : 1;
		long long index2 = $3.type == 2 ? getIdIndex( $3.string ) : 1;

		if( index1 != -1 && index2 != -1 ){

			if( $1.type == 2 )
				checkInit(index1);
			if( $3.type == 2 )
				checkInit(index2);

			long long reg1 = $1._register;
			long long reg2 = $3._register;

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
		long long index1 = $1.type == 2 ? getIdIndex( $1.string ) : 1;
		long long index2 = $3.type == 2 ? getIdIndex( $3.string ) : 1;

		if( index1 != -1 && index2 != -1 ){

			if( $1.type == 2 )
				checkInit(index1);
			if( $3.type == 2 )
				checkInit(index2);

			long long reg1 = $1._register;
			long long reg2 = $3._register;

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
		
		long long index = getIdIndex( $1.string );

		if( index == -1 ){
			DECL_ERROR( $1.string );
			fault = 1;
		}
		else{
			if( idTab.tab[ index ]->idType == 1 ){
				long long reg = findRegister();
				long long mem = idTab.tab[ index ]->mem;
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
		long long index = getIdIndex( $1.string );
		
		if( index != -1 ){
			if( idTab.tab[ index ]->idType == 2 ){
				if( $1.num < idTab.tab[ index ]->size ){
					long long reg = findRegister();
					
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
		long long index = getIdIndex( $3.string );
		long long index2 = getIdIndex( $1.string );

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
					
					long long reg = findRegister();
					long long mem = idTab.tab[ index ]->mem;
					
					saveRegister( reg, mem );
					
					addCode("COPY", 1, reg, 0 );

					long long reg2 = findRegister();
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

	for( long long i = 0 ; i < REGISTER_NUMBER ; ++i ){
		registers[ i ] = 0;
	}

}





void addCode( char * name,long long nrOfArg, long long firstArg, long long secArg ){
	
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
	
	long long num = atoi( string );
	long long counter = 0;
	long long tab[ 30 ];

	while( num > 0 ){
		tab[ counter++ ] = num % 2;
		num = num / 2;
	}

	addCode( "ZERO", 1, 1, 0 );
	for( long long i = 0 ; i < counter ; ++i ){
		if( tab[ 1 ] == 1 ){
			// TU SKOŃCZYŁEM
		}
		else{

		}

		if( i == counter - 1 ){

		}
	}

}





long long findRegister( ){
	for( long long i = 4 ; i >= 1 ; --i ){
		if( registers[ i ] == 0 )
			return i ;
	}
	return -1;
}




long long findOccupiedRegister( ){
	for( long long i = 4 ; i >= 1 ; --i ){
		if( registers[ i ] == 1 )
			return i ;
	}
	return -1;
}





void checkInit( long long index ){
	if( idTab.tab[ index ]->idType == 1 ){
		if( idTab.tab[ index ]->initialized == 0 ){
			INIT_ERROR( idTab.tab[ index ]->name );
			fault = 1;
		}
	}
}





void saveRegister( long long _register, long long num ){
	
	registers[ _register ] = 1;
	long long counter = 0;
	long long tab[ 30 ];

	while( num > 0 ){
		tab[ counter++ ] = num % 2;
		num = num / 2;
	}

	addCode( "ZERO", 1, _register, 0 );
	for( long long i = counter-1 ; i >= 0 ; --i ){
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






long long checkVar( char * name ){
	
	long long index = getIdIndex( name);
	if( index > -1 ){
		printf("<line: %d> ERROR: Nazwa '%s' została już użyta.\n", yylineno, name );
		return 0;
	}
	return 1;

}





void addJump( long long instrNumber ){
	js.tab[ js.top ] = instrNumber;
	js.top++;
}





long long getJump(){

	js.top--;
	
	long long result = js.tab[ js.top ];

	return result;

}





void removeId(){
	idTab.index--;
	memoryIndex -= 2;
	free( idTab.tab[ idTab.index ]->name );
	free( idTab.tab[ idTab.index] );
}





void editArgument( long long codeNumber, long long argNumber, long long value ){
	asmTab.tab[ codeNumber ]->args[ argNumber - 1 ] = value;
}





void addId( char * name, long long type, long long size, long long glob ){
	
	identifier * id = ( identifier * )malloc( sizeof( identifier ) );
	
	id->name = ( char * ) malloc( strlen( name ) );
	strcpy( id->name, name );
	id->idType = type;
	id->mem = memoryIndex;
	id->size = size;
	id->initialized = 0;
	id->glob = glob;


	if( type == 1 ){
		if( glob == 0 )
			memoryIndex += 2;
		else
			memoryIndex++;
	}
	
	idTab.tab[ idTab.index ] = id;
	idTab.index++;

}





void addArrayId( char * name, long long type, char * num ){
	
	long long number = stringToNum( num );
	addId( name, type, number, 1 );
	memoryIndex += number;

}





long long getIdIndex( char * id ){
	
	for( long long i = 0 ; i < idTab.index ; ++i ){
		if( strcmp( id, idTab.tab[ i ]->name ) == 0 ){
			return i;
		}
	}	
	return -1;

}




void printInstruction( long long i, FILE * f){
	fprintf( f, "%s", asmTab.tab[ i ]->instr );
	for( long long temp = 0 ; temp < asmTab.tab[ i ]->nrOfArg; ++temp ){
		fprintf(f, " %lld", asmTab.tab[ i ]->args[ temp ] );
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
				for( long long i = 0 ; i < asmTab.index ; ++i ){
					//fprintf(f, "%lld: ", i );
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

	for( long long i = 0 ; i < idTab.index ; ++i ){
		printf("\t%s\n",idTab.tab[ i ]->name);
		printf("\t%lld\n",idTab.tab[ i ]->idType);
		printf("\t%lld\n",idTab.tab[ i ]->mem);
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






















































