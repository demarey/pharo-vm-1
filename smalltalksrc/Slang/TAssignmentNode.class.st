Class {
	#name : 'TAssignmentNode',
	#superclass : 'TParseNode',
	#instVars : [
		'variable',
		'expression'
	],
	#category : 'Slang-AST',
	#package : 'Slang',
	#tag : 'AST'
}

{ #category : 'instance creation' }
TAssignmentNode class >> variable: aVariable expression: anExpression [

	^ self new
		setVariable: aVariable
		expression: anExpression;
		yourself
]

{ #category : 'instance creation' }
TAssignmentNode class >> variableNamed: aVariableName expression: anExpression [

	^ self new
		  setVariable: (TVariableNode named: aVariableName) expression: anExpression;
		  yourself
]

{ #category : 'visiting' }
TAssignmentNode >> accept: aVisitor [ 
	
	^ aVisitor visitAssignmentNode: self
]

{ #category : 'C code generation' }
TAssignmentNode >> asCASTExpressionIn: aCodeGen [

	(expression isStatementList and: [ expression statements size > 1 ]) 
		ifTrue: [ ^ self asCASTStatementListExpansionAsExpression: aCodeGen ].
	^ (self asCASTIn: aCodeGen)
		  needsParentheses: true;
		  yourself
]

{ #category : 'tranforming' }
TAssignmentNode >> asCASTIn: aBuilder [

	| type |
	expression isSwitch ifTrue: [ 
		^ expression asCASTIn: aBuilder addToEndOfCases: self ].
	expression isLiteralArrayDeclaration ifTrue: [ 
		| literalArrayNode |
		type := expression arguments last value.
		self assert: type last = $*.

		"Transform the literal array declaration to a C block containing:
		  - a static literal array declaration
	 	  - an assigment from this literal array to the assigned variable "
		literalArrayNode := expression arguments first value collect: [ :e | 
			                    CConstantNode value: e ].
		^ CCompoundStatementNode
			  declarations: { (CDeclarationNode
					   specifiers: { 
							   'static'.
							   type allButLast }
					   declarator: (CInitDeclaratorNode
							    declarator:
							    (CArrayDeclaratorNode identifier: 'aLiteralArray')
							    initializer:
							    (CGLRInitializerNode initializers: literalArrayNode))) }
			  statements: { (CAssignmentNode
					   lvalue: (CIdentifierNode name: variable name)
					   rvalue: (CIdentifierNode name: 'aLiteralArray')) } ].

	(expression isStatementList and: [ expression statements size > 1 ]) 
		ifTrue: [ 
			^ expression copy
				  assignLastExpressionTo: variable;
				  asCASTIn: aBuilder ].
	self isVariableUpdatingAssignment ifTrue: [ 
		^ CAssignmentNode
			  lvalue: (variable asCASTIn: aBuilder)
			  operator: expression selector , '='
			  rvalue: (expression arguments first asCASTExpressionIn: aBuilder) ].
	(expression isSend and: [ expression isValueExpansion ]) ifTrue: [ 
		^ self asCASTValueExpansionIn: aBuilder ].

	^ CAssignmentNode
		  lvalue: (variable asCASTIn: aBuilder)
		  rvalue: (expression asCASTExpressionIn: aBuilder)
]

{ #category : 'C code generation' }
TAssignmentNode >> asCASTStatementListExpansionAsExpression: aCodeGen [

	(variable isSameAs: expression lastNonCommentStatement) ifTrue: [
		^ expression asCASTExpressionIn: aCodeGen ].
	^ expression copy
		  assignLastExpressionTo: variable;
		  asCASTExpressionIn: aCodeGen
]

{ #category : 'C code generation' }
TAssignmentNode >> asCASTValueExpansionIn: aCodeGen [

	| stmtList lastStmt copy |
	"Transform assignments of the form:
	
	var := [ a . block . lastexpression ] value.
	
	into:
	
	[ a . block . var := lastExpression ] value.
	
	Takes into account variants of #value and #value:.
	"
	self assert: (expression isSend and: [ expression isValueExpansion ]).

	stmtList := expression receiver.
	lastStmt := stmtList lastNonCommentStatement.

	"Optimization. If the expression looks like:
	
	var := [ ... var ] value.
	
	Emit directly the block without the last statement, as the assignment has no impact in the translation.
	"
	lastStmt = variable ifTrue: [ ^ expression asCASTIn: aCodeGen ].
	copy := stmtList copy.
	copy statements
		at: (stmtList statements indexOf: lastStmt)
		put:
		(TAssignmentNode new setVariable: variable expression: lastStmt).
	^ (TSendNode new
		   setSelector: expression selector
		   receiver: copy
		   arguments: expression arguments) asCASTIn: aCodeGen
]

{ #category : 'transformations' }
TAssignmentNode >> bindVariableUsesIn: aDictionary [
	"Do NOT bind the variable on the left-hand-side of an assignment statement."
	"was bindVariablesIn:"
	self expression: (expression bindVariableUsesIn: aDictionary).

]

{ #category : 'transformations' }
TAssignmentNode >> bindVariableUsesIn: aDictionary andConstantFoldIf: constantFold in: codeGen [
	"Answer either the receiver, if it contains no references to the given variables, or a new node with the given variables rebound."
	"Do NOT bind the variable on the left-hand-side of an assignment statement."
	| boundExpression |
	boundExpression := expression bindVariableUsesIn: aDictionary andConstantFoldIf: constantFold in: codeGen.
	^boundExpression == expression
		ifTrue: [self]
		ifFalse: [self shallowCopy
					setVariable: variable expression: boundExpression;
					yourself]
]

{ #category : 'transformations' }
TAssignmentNode >> bindVariablesIn: aDictionary [

	self variable: (variable bindVariablesIn: aDictionary).
	self expression: (expression bindVariablesIn: aDictionary).
]

{ #category : 'transformations' }
TAssignmentNode >> bindVariablesIn: aDictionary unless: cautionaryBlock [

	(cautionaryBlock value: self) ifTrue: [^self].
	self variable: (variable bindVariablesIn: aDictionary unless: cautionaryBlock).
	self expression: (expression bindVariablesIn: aDictionary unless: cautionaryBlock).
]

{ #category : 'accessing' }
TAssignmentNode >> children [
	
	^ { variable . expression }
]

{ #category : 'displaying' }
TAssignmentNode >> displayString [

	^ ' := '
]

{ #category : 'accessing' }
TAssignmentNode >> expression [

	^expression
]

{ #category : 'accessing' }
TAssignmentNode >> expression: anExpression [

	expression := anExpression.
	expression parent: self.
]

{ #category : 'testing' }
TAssignmentNode >> isAssignment [

	^true
]

{ #category : 'testing' }
TAssignmentNode >> isSameAs: aTParseNode [
	^aTParseNode isAssignment
	 and: [(variable isSameAs: aTParseNode variable)
	 and: [expression isSameAs: aTParseNode expression]]
]

{ #category : 'testing' }
TAssignmentNode >> isVariableUpdatingAssignment [
	"Return true if this assignment statement is of one of the forms:
		var = var + ...
		var = var - ...
	Such assignments statements can exploit the C updating assignment operators. For example, 'x += 4' can be generated instead of 'x = x + 4'. This produces better code under some C compilers, most notably the CodeWarrior 68K compiler."

	| sel |
	(expression isSend and: [expression receiver isVariable]) ifFalse: [^ false].
	sel := expression selector.
	^ (expression receiver name = variable name) and: [(sel = #+) or: [sel = #-]]
]

{ #category : 'enumerating' }
TAssignmentNode >> nodesDo: aBlock [
	"Apply aBlock to all nodes in the receiver.
	 N.B. This is assumed to be bottom-up, leaves first."
	variable nodesDo: aBlock.
	expression nodesDo: aBlock.
	aBlock value: self
]

{ #category : 'enumerating' }
TAssignmentNode >> nodesDo: aBlock parent: parent [
	"Apply aBlock to all nodes in the receiver with each node's parent.
	 N.B. This is assumed to be bottom-up, leaves first."
	variable nodesDo: aBlock parent: self.
	expression nodesDo: aBlock parent: self.
	aBlock value: self value: parent
]

{ #category : 'enumerating' }
TAssignmentNode >> nodesDo: aBlock parent: parent unless: cautionaryBlock [

	(cautionaryBlock value: self value: parent) ifTrue: [^self].
	variable nodesDo: aBlock parent: self unless: cautionaryBlock.
	expression nodesDo: aBlock parent: self unless: cautionaryBlock.
	aBlock value: self value: parent
]

{ #category : 'enumerating' }
TAssignmentNode >> nodesDo: aBlock unless: cautionaryBlock [

	(cautionaryBlock value: self) ifTrue: [^self].
	variable nodesDo: aBlock unless: cautionaryBlock.
	expression nodesDo: aBlock unless: cautionaryBlock.
	aBlock value: self.
]

{ #category : 'copying' }
TAssignmentNode >> postCopy [

	self variable: variable copy.
	self expression: expression copy
]

{ #category : 'C code generation' }
TAssignmentNode >> prependCASTIn: aBuilder expression: nodeExp [

	^ CAssignmentNode
		  lvalue: (variable asCASTExpressionIn: aBuilder)
		  operator: (self isVariableUpdatingAssignment
				   ifTrue: [ expression selector "+ or -" ]
				   ifFalse: [ '' ]) , '='
		  rvalue: (nodeExp asCASTExpressionIn: aBuilder)
]

{ #category : 'printing' }
TAssignmentNode >> printOn: aStream level: level [

	variable printOn: aStream level: level.
	aStream nextPutAll: ' := '.
	expression printOn: aStream level: level + 2.
]

{ #category : 'transformations' }
TAssignmentNode >> removeAssertions [

	expression removeAssertions
]

{ #category : 'transformations' }
TAssignmentNode >> replaceChild: aNode with: aReplacementNode [

	variable == aNode ifTrue: [ 
		self variable: aReplacementNode ].
	expression == aNode ifTrue: [ 
		self expression: aReplacementNode ]
]

{ #category : 'transformations' }
TAssignmentNode >> replaceNodesIn: aDictionary [

	^aDictionary at: self ifAbsent: [
		self variable: (variable replaceNodesIn: aDictionary).
		self expression: (expression replaceNodesIn: aDictionary).
		self]
]

{ #category : 'accessing' }
TAssignmentNode >> setVariable: varNode expression: expressionNode [
	self assert: (expressionNode isGoTo or: [expressionNode isLabel]) not.
	self variable: varNode.
	self expression: expressionNode.
]

{ #category : 'testing' }
TAssignmentNode >> structTargetKindIn: aCodeGen [
	"Answer if the recever evaluates to a struct or struct pointer
	 and hence can be dereferenced using . or ->.  Answer any of
	 #struct #pointer or nil"
	^variable structTargetKindIn: aCodeGen
]

{ #category : 'type inference' }
TAssignmentNode >> typeOrNilFrom: aCodeGenerator in: aTMethod [
	"This is the default type in case of doubt"
	^(variable typeOrNilFrom: aCodeGenerator in: aTMethod) ifNil:
		[expression typeOrNilFrom: aCodeGenerator in: aTMethod]
]

{ #category : 'accessing' }
TAssignmentNode >> variable [

	^variable
]

{ #category : 'accessing' }
TAssignmentNode >> variable: anObject [

	variable := anObject.
	variable parent: self.
]

{ #category : 'accessing' }
TAssignmentNode >> variableNameOrNil [
	^variable variableNameOrNil
]
