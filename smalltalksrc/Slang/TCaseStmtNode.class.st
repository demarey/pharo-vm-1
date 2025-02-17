"
I implement the main dispatch case statements for bytecode and primitive dispatch.  See TMethod classPool associationAt: #CaseStatements
"
Class {
	#name : 'TCaseStmtNode',
	#superclass : 'TParseNode',
	#instVars : [
		'expression',
		'firsts',
		'lasts',
		'cases'
	],
	#category : 'Slang-AST',
	#package : 'Slang',
	#tag : 'AST'
}

{ #category : 'instance-creation' }
TCaseStmtNode class >> newWithExpression: anExpression selectors: aCollectionOfSelectors arguments: arguments [
	
	^ self new
		setExpression: anExpression
		selectors: aCollectionOfSelectors
		arguments: arguments;
		yourself
]

{ #category : 'visiting' }
TCaseStmtNode >> accept: aVisitor [
	
	^ aVisitor visitCaseStatementNode: self
]

{ #category : 'tranforming' }
TCaseStmtNode >> asCASTIn: aBuilder [
	
	| statements expansions duplicates switchStatement result |
	statements := CCompoundStatementNode new.
	
	expansions := aBuilder suppressAsmLabelsWhile: [
		cases collect: [:case| self filterCommentsFrom:
			(String streamContents: [:s| (case asCASTIn: aBuilder) prettyPrintOn: s ] ) ] ].
	
	duplicates := Set new.
	1 to: cases size do: [:i| | case lastCase |
		"If case bodies are the same, keep only one."
		(duplicates includes: i) ifFalse: [
			"Cases are nested.
			We iterate from the last case to the first case so the nesting order remains the same as the defined one"
			(duplicates addAll: ((cases size to: i by: -1) select: [:j| (expansions at: i) = (expansions at: j)])) do: [:k|
				(lasts at: k) to: (firsts at: k) by: -1 do: [ :caseIndex |
					case := CLabeledStatementNode case: (CConstantNode value: caseIndex) statement: case.
					"Remember the last case, will be the one attached to the statement"
					lastCase ifNil: [ lastCase := case ].
			]].
			lastCase statement: ((cases at: i) asCASTIn: aBuilder).
			statements add: case.
			statements add: CBreakStatementNode new]].
	
	switchStatement := CSwitchStatementNode
		if: (expression asCASTExpressionIn: aBuilder)
		statement: statements.
	
	(expression isVariable and: [expression name = 'currentBytecode']) ifFalse: [ ^ switchStatement ].
	
	result := CCompoundStatementNode new.
	result needsBrackets: false.
	result add: (CCallNode identifier: (CIdentifierNode name: 'bytecodeDispatchDebugHook')).
	result add: (aBuilder asmLabelNodeFor: 'bytecodeDispatch').
	result add: switchStatement.
	^ result
]

{ #category : 'tranforming' }
TCaseStmtNode >> asCASTIn: aBuilder addToEndOfCases: aNodeToPrepend [
	
	| statements |
	statements := CCompoundStatementNode new.
	
	cases withIndexDo: [:case :i| | ccase lastCase |
		"If case bodies are the same, keep only one."
		"Cases are nested.
		We iterate from the last case to the first case so the nesting order remains the same as the defined one"
		(lasts at: i) to: (firsts at: i) by: -1 do: [ :caseIndex |
			ccase := CLabeledStatementNode case: (CConstantNode value: caseIndex) statement: ccase.
			"Remember the last case, will be the one attached to the statement"
			lastCase ifNil: [ lastCase := ccase ].
		].
		lastCase statement: (case asCASTIn: aBuilder prependToEnd: aNodeToPrepend).
		statements add: ccase.
		(aNodeToPrepend notNil and: [aNodeToPrepend isReturn]) ifFalse: [
			statements add: CBreakStatementNode new ]
	].
	
	statements add: (CLabeledStatementNode defaultDoing: ((CCompoundStatementNode statements: {
		CCallNode
			identifier: (CIdentifierNode name: 'error')
			arguments: { CStringLiteralNode value: 'Case not found' }.
		CReturnStatementNode expression: (CConstantNode value: -1).
	}) needsBrackets: false; yourself)).
	
	^ CSwitchStatementNode
		if: (expression asCASTExpressionIn: aBuilder)
		statement: statements
]

{ #category : 'transformations' }
TCaseStmtNode >> bindVariableUsesIn: aDictionary [

	self expression: (expression bindVariableUsesIn: aDictionary).
	self cases: (cases collect: [ :c | c bindVariableUsesIn: aDictionary ]).
]

{ #category : 'transformations' }
TCaseStmtNode >> bindVariableUsesIn: aDictionary andConstantFoldIf: constantFold in: codeGen [
	"Answer either the receiver, if it contains no references to the given variables, or a new node with the given variables rebound."
	| newExpression newCases |
	newExpression := expression bindVariableUsesIn: aDictionary andConstantFoldIf: constantFold in: codeGen.
	newCases := cases collect: [:c| c bindVariableUsesIn: aDictionary andConstantFoldIf: constantFold in: codeGen].
	^(newExpression = expression
	   and: [newCases = cases])
		ifTrue: [self]
		ifFalse: [self shallowCopy
					setExpression: newExpression cases: newCases;
					yourself]
]

{ #category : 'transformations' }
TCaseStmtNode >> bindVariablesIn: aDictionary [

	self expression: (expression bindVariablesIn: aDictionary).
	self cases: (cases collect: [ :c | c bindVariablesIn: aDictionary ]).
]

{ #category : 'transformations' }
TCaseStmtNode >> bindVariablesIn: aDictionary unless: cautionaryBlock [

	(cautionaryBlock value: self) ifTrue: [^self].
	self expression: (expression bindVariablesIn: aDictionary unless: cautionaryBlock).
	self cases: (cases collect: [ :c | c bindVariablesIn: aDictionary unless: cautionaryBlock ]).
]

{ #category : 'comparing' }
TCaseStmtNode >> cases [

	^ cases
]

{ #category : 'comparing' }
TCaseStmtNode >> cases: aListOfCases [

	cases := aListOfCases.
	cases do: [ :e | e parent: self ]
]

{ #category : 'accessing' }
TCaseStmtNode >> children [
	
	^ { expression }, cases
]

{ #category : 'transformations' }
TCaseStmtNode >> customizeCase: caseParseTree forVar: varName from: firstIndex to: lastIndex in: codeGen method: aTMethod expandedCases: seen [
	"Return a collection of copies of the given parse tree, each of which has the value of the case index substituted for the given variable."

	| newCases dict newCase |
	newCases := OrderedCollection new.
	firstIndex to: lastIndex do:
		[ :caseIndex |
		dict := Dictionary new.
		dict at: varName put: (TConstantNode value: caseIndex).
		newCase := caseParseTree copy bindVariableUsesIn: dict andConstantFoldIf: true in: codeGen.
		self processSharedCodeBlocks: newCase forCase: caseIndex in: codeGen method: aTMethod expandedCases: seen.
		newCases addLast: newCase].
	^newCases
]

{ #category : 'transformations' }
TCaseStmtNode >> customizeShortCasesForDispatchVar: varName in: codeGen method: aTMethod [
	"Make customized versions of short bytecode methods, substituting a constant having the case index value for the given variable.
	 This produces better code for short bytecodes such as instance variable pushes that encode the index of the instance variable in the bytecode."

	| newFirsts newLasts newCases seen |
	newFirsts := OrderedCollection new.
	newLasts := OrderedCollection new.
	newCases := OrderedCollection new.
	seen := Set new.	"So that sharedCodeNamed:inCase:'s can be used in multiple bytecode set
						 configurations we need to expand the code only once."
	1 to: cases size do:
		[ :i | | l f case expanded |
		l := lasts at: i.
		f := firsts at: i.
		case := cases at: i.
		expanded := false.
		((l - f) > 1  "case code covers multiple cases"
		 and: [case shouldExpand]) ifTrue:
				[newFirsts addAll: (f to: l) asArray.
				 newLasts addAll: (f to: l) asArray.
				 newCases addAll: (self customizeCase: case forVar: varName from: f to: l in: codeGen method: aTMethod expandedCases: seen).
				 expanded := true].
		expanded ifFalse:
			[self processSharedCodeBlocks: case forCase: f in: codeGen method: aTMethod expandedCases: seen.
			 newFirsts addLast: f.
			 newLasts addLast: l.
			 newCases addLast: case]].
	firsts := newFirsts asArray.
	lasts := newLasts asArray.
	self cases: newCases asArray
]

{ #category : 'accessing' }
TCaseStmtNode >> expression [

	^ expression
]

{ #category : 'accessing' }
TCaseStmtNode >> expression: anExpression [

	expression := anExpression.
	anExpression parent: self
]

{ #category : 'private' }
TCaseStmtNode >> filterCommentsFrom: aString [
	"elide any /* comment */ occurrences from aString."
	| i |
	i := aString indexOfSubCollection: '/*'startingAt: 1 ifAbsent: [^aString].
	^(aString copyFrom: 1 to: i - 1),
	  (self filterCommentsFrom:
		(aString
			copyFrom: (aString indexOfSubCollection: '*/' startingAt: i + 2) + 2
			to: aString size))
]

{ #category : 'testing' }
TCaseStmtNode >> isCaseStmt [

	^true
]

{ #category : 'comparing' }
TCaseStmtNode >> isSameAs: anotherNode [

	anotherNode isCaseStmt ifFalse: [ ^ false ].
	(expression isSameAs: anotherNode expression)
		ifFalse: [ ^ false ].
	
	cases size ~= anotherNode cases size ifTrue: [ ^ false ].
	cases with: anotherNode cases collect: [ :case1 :case2 |
		(case1 isSameAs: case2)
	].

	"Apparently it went ok after all this"
	^ true
]

{ #category : 'enumerating' }
TCaseStmtNode >> nodesDo: aBlock [
	"Apply aBlock to all nodes in the receiver.
	 N.B. This is assumed to be bottom-up, leaves first."
	expression nodesDo: aBlock.
	cases do: [ :c | c nodesDo: aBlock ].
	aBlock value: self
]

{ #category : 'enumerating' }
TCaseStmtNode >> nodesDo: aBlock parent: parent [
	"Apply aBlock to all nodes in the receiver with each node's parent.
	 N.B. This is assumed to be bottom-up, leaves first."
	expression nodesDo: aBlock parent: self.
	cases do: [:c| c nodesDo: aBlock parent: self].
	aBlock value: self value: parent
]

{ #category : 'enumerating' }
TCaseStmtNode >> nodesDo: aBlock parent: parent unless: cautionaryBlock [

	(cautionaryBlock value: self value: parent) ifTrue: [^self].
	expression nodesDo: aBlock parent: self unless: cautionaryBlock.
	cases do: [ :c | c nodesDo: aBlock parent: self unless: cautionaryBlock].
	aBlock value: self value: parent
]

{ #category : 'enumerating' }
TCaseStmtNode >> nodesDo: aBlock unless: cautionaryBlock [

	(cautionaryBlock value: self) ifTrue: [^self].
	expression nodesDo: aBlock unless: cautionaryBlock.
	cases do: [ :c | c nodesDo: aBlock  unless: cautionaryBlock].
	aBlock value: self
]

{ #category : 'copying' }
TCaseStmtNode >> postCopy [

	self expression: expression copy.
	firsts := firsts copy.
	lasts := lasts copy.
	self cases: (cases collect: [ :case | case copy ])
]

{ #category : 'printing' }
TCaseStmtNode >> printOn: aStream level: level [

	aStream crtab: level.
	aStream nextPutAll: 'select '.
	expression printOn: aStream level: level.
	aStream nextPutAll: ' in'.
	1 to: cases size do: [ :i |
		(firsts at: i) to: (lasts at: i) do: [ :caseIndex |
			aStream crtab: level.
			aStream nextPutAll: 'case ', caseIndex printString, ':'.
		].
		aStream crtab: level + 1.
		(cases at: i) printOn: aStream level: level + 1.
	].
	aStream crtab: level.
	aStream nextPutAll: 'end select'.
]

{ #category : 'transformations' }
TCaseStmtNode >> processSharedCodeBlocks: caseTree forCase: caseIndex in: codeGen method: aTMethod expandedCases: seen [

	"Process any shared code blocks in the case parse tree for the given case, either inlining them or making them a 'goto sharedLabel'."

	| caseMethod map meth sharedNode exitLabel |
	exitLabel := nil.
	"caseTree is expected to be a TStmtListNode whose first element is a comment
	 and whose second element is a TInlineNode for a method."
	caseMethod := caseTree statements second method.
	[ 
	sharedNode := nil.
	map := IdentityDictionary new.
	caseTree nodesDo: [ :node | 
		(sharedNode isNil and: [ 
			 node isSend and: [ 
				 (meth := codeGen methodNamed: node selector) notNil and: [ 
					 meth sharedCase notNil ] ] ]) ifTrue: [ 
			(meth sharedCase = (meth sharedCase isSymbol
				  ifTrue: [ caseMethod selector ]
				  ifFalse: [ caseIndex ]) and: [ 
				 (seen includes: meth sharedLabel) not ])
				ifTrue: [ "If the bytecode (the caseMethod) ends with a message that has a lastCase (and lastLabel) then
					  that will be converted into a goto and control will continue to that code,  If the bytecode does
					  /not/ end with a message that has a lastCase (and lastLabel) then control should not continue to
					  that shared case.  expandViaFallThrough captures this, true for the former, false for the latter."
					| expandViaFallThrough |
					expandViaFallThrough := false.
					caseMethod statements last isSend ifTrue: [ 
						(codeGen methodNamed: caseMethod statements last selector) 
							ifNotNil: [ :m | expandViaFallThrough := m sharedCase notNil ] ].
					seen add: meth sharedLabel.
					map at: node put: (expandViaFallThrough
							 ifTrue: [ 
								 sharedNode := meth.
								 TLabeledCommentNode new setComment:
									 'goto ' , meth sharedLabel ]
							 ifFalse: [ "Still need recursive expansjon to continue but don't want
										  to duplicate the node, so substitue an empty method."
								 sharedNode := TLabeledCommentNode new setComment: 'null '.
								 meth copy
									 renameLabelsForInliningInto: aTMethod;
									 addLabelsTo: aTMethod;
									 asInlineNode ]) ]
				ifFalse: [ map at: node put: (TGoToNode label: meth sharedLabel) ] ] ].
	caseTree replaceNodesIn: map.
	"recursively expand"
	sharedNode notNil ] whileTrue: [ 
		sharedNode isTMethod ifTrue: [ 
			meth := sharedNode copy.
			meth hasReturn ifTrue: [ 
				exitLabel ifNil: [ 
					exitLabel := aTMethod unusedLabelForInliningInto: aTMethod.
					aTMethod labels add: exitLabel ].
				meth exitVar: nil label: exitLabel ].
			meth
				renameLabelsForInliningInto: aTMethod;
				addLabelsTo: aTMethod.
			caseTree statements:
				(caseTree statements copyWith: meth asInlineNode) ] ].
	exitLabel ifNotNil: [ 
		caseTree statements: (caseTree statements copyWith:
				 (TLabeledCommentNode new setLabel: exitLabel comment: 'end case')) ]
]

{ #category : 'transformations' }
TCaseStmtNode >> removeAssertions [
	expression removeAssertions.
	cases do: [ :case | case removeAssertions ].
]

{ #category : 'transformations' }
TCaseStmtNode >> replaceNodesIn: aDictionary [

	^aDictionary at: self ifAbsent: [
		self expression: (expression replaceNodesIn: aDictionary).
		self cases: (cases collect: [ :c | c replaceNodesIn: aDictionary ]).
		self]
]

{ #category : 'private' }
TCaseStmtNode >> setExpression: newExpression cases: newCases [
	self expression: newExpression.
	self cases: newCases
]

{ #category : 'accessing' }
TCaseStmtNode >> setExpression: aNode selectors: selectorList arguments: anArray [
	"Initialize the node from the given set of selectors."
	"Note: Each case is a statement list with containing one statement, a send to self of a selector from the given selector list. Having statement list nodes makes inlining easier later."

	| selfNode stmt lastSel firstInRun sel case |
	self expression: aNode.
	selfNode := TVariableNode new setName: 'self'.
	firsts := OrderedCollection new: 400.
	lasts := OrderedCollection new: 400.
	self cases: (OrderedCollection new: 400).
	lastSel := selectorList first.
	firstInRun := 0.
	1 to: selectorList size do: [ :i |
		sel := selectorList at: i.
		sel ~= lastSel ifTrue: [
			firsts add: firstInRun.
			lasts add: i - 2.
			stmt := TSendNode new setSelector: lastSel receiver: selfNode arguments: anArray.
			
			case := cases add: (TStatementListNode new setArguments: #() statements: (Array with: stmt)).
			case parent: self.
			
			lastSel := sel.
			firstInRun := i - 1.
		].
	].
	firsts add: firstInRun.
	lasts add: selectorList size - 1.
	
	stmt := TSendNode new setSelector: lastSel receiver: selfNode arguments: anArray.
	case := cases add: (TStatementListNode new setArguments: #() statements: (Array with: stmt)).
	case parent: self.
]
